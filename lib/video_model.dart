// Folder: lib/models/
// File:   video_model.dart
//
// Hive-persisted metadata for every video the app tracks.
// Run `flutter pub run build_runner build` to regenerate video_model.g.dart

import 'package:hive/hive.dart';

part 'video_model.g.dart';

/// Platform source of the video.
@HiveType(typeId: 1)
enum VideoPlatform {
  @HiveField(0)
  youtube,

  @HiveField(1)
  tiktok,
}

/// Lifecycle state of the local cache for this video.
@HiveType(typeId: 2)
enum CacheStatus {
  /// Not yet downloaded.
  @HiveField(0)
  none,

  /// Currently downloading in background.
  @HiveField(1)
  downloading,

  /// Fully downloaded; localFilePath is valid.
  @HiveField(2)
  cached,

  /// Remote URL has expired; needs re-extraction.
  @HiveField(3)
  expired,
}

@HiveType(typeId: 0)
class VideoModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  /// User-defined or auto-assigned category tag (e.g. "trending", "saved").
  @HiveField(2)
  String category;

  /// Direct MP4 URL returned by the Python backend.
  @HiveField(3)
  String remoteUrl;

  /// Absolute path to the locally cached MP4 file (empty if not cached).
  @HiveField(4)
  String localFilePath;

  @HiveField(5)
  VideoPlatform platform;

  @HiveField(6)
  String? thumbnailUrl;

  @HiveField(7)
  double? duration;

  /// Approximate file size in bytes (used by the LRU eviction engine).
  @HiveField(8)
  int fileSizeBytes;

  /// Epoch ms when the entry was last accessed / played.
  @HiveField(9)
  int lastAccessedMs;

  @HiveField(10)
  CacheStatus cacheStatus;

  /// Original share URL (TikTok / YouTube Shorts link).
  @HiveField(11)
  String originalUrl;

  @HiveField(12)
  int? width;

  @HiveField(13)
  int? height;

  /// Epoch ms when the video was added to the feed.
  @HiveField(14)
  int createdAtMs;

  VideoModel({
    required this.id,
    required this.title,
    required this.category,
    required this.remoteUrl,
    required this.localFilePath,
    required this.platform,
    this.thumbnailUrl,
    this.duration,
    this.fileSizeBytes = 0,
    int? lastAccessedMs,
    this.cacheStatus = CacheStatus.none,
    required this.originalUrl,
    this.width,
    this.height,
    int? createdAtMs,
  })  : lastAccessedMs = lastAccessedMs ?? DateTime.now().millisecondsSinceEpoch,
        createdAtMs = createdAtMs ?? DateTime.now().millisecondsSinceEpoch;

  bool get isCached => cacheStatus == CacheStatus.cached && localFilePath.isNotEmpty;

  bool get isDownloading => cacheStatus == CacheStatus.downloading;

  String get platformLabel => platform == VideoPlatform.youtube ? 'YouTube' : 'TikTok';

  /// Returns the best playback URI: local file if cached, else remote URL.
  String get playbackUri => isCached ? localFilePath : remoteUrl;

  /// Mark this video as recently accessed (called on play).
  void touch() {
    lastAccessedMs = DateTime.now().millisecondsSinceEpoch;
    save();
  }

  VideoModel copyWith({
    String? id,
    String? title,
    String? category,
    String? remoteUrl,
    String? localFilePath,
    VideoPlatform? platform,
    String? thumbnailUrl,
    double? duration,
    int? fileSizeBytes,
    int? lastAccessedMs,
    CacheStatus? cacheStatus,
    String? originalUrl,
    int? width,
    int? height,
    int? createdAtMs,
  }) {
    return VideoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      localFilePath: localFilePath ?? this.localFilePath,
      platform: platform ?? this.platform,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      lastAccessedMs: lastAccessedMs ?? this.lastAccessedMs,
      cacheStatus: cacheStatus ?? this.cacheStatus,
      originalUrl: originalUrl ?? this.originalUrl,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  @override
  String toString() =>
      'VideoModel(id: $id, title: $title, platform: $platform, '
      'status: $cacheStatus, size: ${fileSizeBytes}B)';
}
