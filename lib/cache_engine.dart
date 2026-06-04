// Folder: lib/services/
// File:   cache_engine.dart
//
// Smart Background Caching Engine
// ─────────────────────────────────────────────────────────────────────────────
// • Downloads the next 2–3 videos in background whenever online
// • Enforces a 2 GB LRU cap — evicts oldest-accessed cached files first
// • Exposes download progress via streams
// • All I/O is performed in Isolate-safe async operations

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/video_model.dart';
import 'hive_service.dart';

/// 2 GB in bytes
const int kMaxCacheBytes = 2 * 1024 * 1024 * 1024;

/// Number of videos to pre-cache ahead of the current index.
const int kLookaheadCount = 3;

class DownloadProgress {
  final String videoId;
  final double percent; // 0.0 – 1.0
  final int receivedBytes;
  final int totalBytes;

  const DownloadProgress({
    required this.videoId,
    required this.percent,
    required this.receivedBytes,
    required this.totalBytes,
  });
}

class CacheEngine {
  static CacheEngine? _instance;
  CacheEngine._();

  static CacheEngine get instance {
    _instance ??= CacheEngine._();
    return _instance!;
  }

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
    ),
  );

  /// Active cancel tokens keyed by videoId.
  final Map<String, CancelToken> _activeDownloads = {};

  /// Download progress stream controller (broadcast so many listeners can watch).
  final _progressController =
      StreamController<DownloadProgress>.broadcast();

  Stream<DownloadProgress> get progressStream => _progressController.stream;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Called whenever the user swipes to a new [currentIndex].
  /// Schedules background downloads for the next [kLookaheadCount] videos.
  Future<void> scheduleLookahead({
    required List<VideoModel> feed,
    required int currentIndex,
  }) async {
    final endIndex = (currentIndex + kLookaheadCount).clamp(0, feed.length - 1);
    for (int i = currentIndex + 1; i <= endIndex; i++) {
      final video = feed[i];
      if (!video.isCached && !video.isDownloading) {
        unawaited(_downloadVideo(video));
      }
    }
  }

  /// Force-downloads a specific video, regardless of position in feed.
  Future<void> downloadVideo(VideoModel video) => _downloadVideo(video);

  /// Cancels an in-progress download.
  void cancelDownload(String videoId) {
    _activeDownloads[videoId]?.cancel('User cancelled');
    _activeDownloads.remove(videoId);
  }

  /// Removes the local file + resets Hive entry.
  Future<void> evict(VideoModel video) async {
    if (video.localFilePath.isNotEmpty) {
      final file = File(video.localFilePath);
      if (await file.exists()) await file.delete();
    }
    await HiveService.instance.updateCacheStatus(
      video.id,
      status: CacheStatus.none,
      localFilePath: '',
      fileSizeBytes: 0,
    );
    debugPrint('[CacheEngine] Evicted ${video.id}');
  }

  /// Clears the entire cache directory and resets all Hive statuses.
  Future<void> clearAll() async {
    final dir = await _cacheDir();
    if (await dir.exists()) await dir.delete(recursive: true);
    for (final v in HiveService.instance.getCachedVideos()) {
      await HiveService.instance.updateCacheStatus(
        v.id,
        status: CacheStatus.none,
        localFilePath: '',
        fileSizeBytes: 0,
      );
    }
    debugPrint('[CacheEngine] Cache cleared.');
  }

  void dispose() {
    for (final t in _activeDownloads.values) {
      t.cancel('Dispose');
    }
    _activeDownloads.clear();
    _progressController.close();
  }

  // ── LRU Eviction ──────────────────────────────────────────────────────────

  /// Ensures total cached bytes stay within [kMaxCacheBytes].
  /// Removes oldest-accessed videos until there is enough space.
  Future<void> _enforceLimit({int requiredBytes = 0}) async {
    final hive = HiveService.instance;
    int total = hive.totalCachedBytes() + requiredBytes;

    if (total <= kMaxCacheBytes) return;

    final lru = hive.lruSortedCached(); // oldest first
    for (final video in lru) {
      if (total <= kMaxCacheBytes) break;
      total -= video.fileSizeBytes;
      await evict(video);
      debugPrint(
          '[CacheEngine] LRU evicted ${video.id} '
          '(freed ${(video.fileSizeBytes / 1e6).toStringAsFixed(1)} MB)');
    }
  }

  // ── Download logic ─────────────────────────────────────────────────────────

  Future<void> _downloadVideo(VideoModel video) async {
    if (_activeDownloads.containsKey(video.id)) return; // Already in flight
    if (video.remoteUrl.isEmpty) return;

    final hive = HiveService.instance;
    await hive.updateCacheStatus(video.id, status: CacheStatus.downloading);

    final cancelToken = CancelToken();
    _activeDownloads[video.id] = cancelToken;

    try {
      // Probe file size first (HEAD request) so LRU can pre-evict if needed
      int estimatedBytes = video.fileSizeBytes;
      if (estimatedBytes <= 0) {
        estimatedBytes = await _probeContentLength(video.remoteUrl) ?? 0;
      }

      // Ensure we have room BEFORE downloading
      await _enforceLimit(requiredBytes: estimatedBytes);

      final dir = await _cacheDir();
      await dir.create(recursive: true);
      final destPath = p.join(dir.path, '${video.id}.mp4');

      await _dio.download(
        video.remoteUrl,
        destPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (_progressController.isClosed) return;
          _progressController.add(
            DownloadProgress(
              videoId: video.id,
              percent: total > 0 ? received / total : 0,
              receivedBytes: received,
              totalBytes: total,
            ),
          );
        },
        options: Options(
          headers: {'Range': 'bytes=0-'}, // Resume-capable
          receiveDataWhenStatusError: false,
        ),
      );

      final file = File(destPath);
      final actualBytes = await file.length();

      await hive.updateCacheStatus(
        video.id,
        status: CacheStatus.cached,
        localFilePath: destPath,
        fileSizeBytes: actualBytes,
      );

      debugPrint(
          '[CacheEngine] Cached ${video.id} '
          '(${(actualBytes / 1e6).toStringAsFixed(1)} MB) → $destPath');

      // After download, run LRU again (the new file may push us over limit)
      await _enforceLimit();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        debugPrint('[CacheEngine] Download cancelled: ${video.id}');
      } else {
        debugPrint('[CacheEngine] Download failed ${video.id}: $e');
      }
      await hive.updateCacheStatus(video.id, status: CacheStatus.none);
    } catch (e) {
      debugPrint('[CacheEngine] Unexpected error ${video.id}: $e');
      await hive.updateCacheStatus(video.id, status: CacheStatus.none);
    } finally {
      _activeDownloads.remove(video.id);
    }
  }

  Future<int?> _probeContentLength(String url) async {
    try {
      final res = await _dio.head<dynamic>(url);
      final raw = res.headers.value('content-length');
      return raw != null ? int.tryParse(raw) : null;
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _cacheDir() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'datacharge_cache'));
  }
}
