// Folder: lib/services/
// File:   hive_service.dart
//
// Singleton wrapper around the Hive box that stores VideoModel entries.
// Provides typed CRUD helpers used by the rest of the app.

import 'package:hive_flutter/hive_flutter.dart';
import '../models/video_model.dart';

class HiveService {
  static const String _boxName = 'videos';
  static HiveService? _instance;
  Box<VideoModel>? _box;

  HiveService._();

  static HiveService get instance {
    _instance ??= HiveService._();
    return _instance!;
  }

  Box<VideoModel> get box {
    if (_box == null || !_box!.isOpen) {
      throw StateError('HiveService not initialised. Call init() first.');
    }
    return _box!;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Must be called once from main() before runApp().
  static Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(VideoModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(VideoPlatformAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CacheStatusAdapter());
    }

    instance._box = await Hive.openBox<VideoModel>(_boxName);
  }

  static Future<void> close() async {
    await instance._box?.close();
  }

  // ── Reads ─────────────────────────────────────────────────────────────────

  List<VideoModel> getAllVideos() =>
      box.values.toList()
        ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

  List<VideoModel> getCachedVideos() =>
      box.values.where((v) => v.isCached).toList()
        ..sort((a, b) => b.lastAccessedMs.compareTo(a.lastAccessedMs));

  VideoModel? getById(String id) {
    try {
      return box.values.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  List<VideoModel> getByCategory(String category) =>
      box.values
          .where((v) => v.category.toLowerCase() == category.toLowerCase())
          .toList()
        ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

  /// Total bytes currently occupied by cached files.
  int totalCachedBytes() =>
      box.values.fold(0, (sum, v) => sum + (v.isCached ? v.fileSizeBytes : 0));

  // ── Writes ────────────────────────────────────────────────────────────────

  Future<void> upsert(VideoModel video) async {
    await box.put(video.id, video);
  }

  Future<void> upsertAll(List<VideoModel> videos) async {
    final map = {for (final v in videos) v.id: v};
    await box.putAll(map);
  }

  Future<void> delete(String id) async {
    await box.delete(id);
  }

  Future<void> updateCacheStatus(
    String id, {
    required CacheStatus status,
    String? localFilePath,
    int? fileSizeBytes,
  }) async {
    final video = getById(id);
    if (video == null) return;
    if (localFilePath != null) video.localFilePath = localFilePath;
    if (fileSizeBytes != null) video.fileSizeBytes = fileSizeBytes;
    video.cacheStatus = status;
    await video.save();
  }

  Future<void> markAccessed(String id) async {
    final video = getById(id);
    if (video == null) return;
    video.lastAccessedMs = DateTime.now().millisecondsSinceEpoch;
    await video.save();
  }

  // ── LRU helpers ───────────────────────────────────────────────────────────

  /// Returns cached videos sorted by lastAccessedMs ascending (oldest first).
  List<VideoModel> lruSortedCached() =>
      box.values
          .where((v) => v.isCached)
          .toList()
        ..sort((a, b) => a.lastAccessedMs.compareTo(b.lastAccessedMs));

  // ── Debug ─────────────────────────────────────────────────────────────────

  Map<String, dynamic> debugStats() {
    final all = box.values.toList();
    final cached = all.where((v) => v.isCached).toList();
    final totalMb = totalCachedBytes() / (1024 * 1024);
    return {
      'total_entries': all.length,
      'cached_count': cached.length,
      'total_cached_mb': totalMb.toStringAsFixed(2),
    };
  }
}
