// Folder: lib/services/
// File:   feed_provider.dart
//
// Central ChangeNotifier that owns the video feed state.
// Consumed by FeedScreen via Provider.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/video_model.dart';
import 'api_service.dart';
import 'cache_engine.dart';
import 'connectivity_service.dart';
import 'hive_service.dart';

enum FeedState { idle, loading, loaded, error }

class FeedProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  FeedState _state = FeedState.idle;
  FeedState get state => _state;

  List<VideoModel> _feed = [];
  List<VideoModel> get feed => List.unmodifiable(_feed);

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  bool _isAddingVideo = false;
  bool get isAddingVideo => _isAddingVideo;

  // ── Dependencies ──────────────────────────────────────────────────────────
  final HiveService _hive = HiveService.instance;
  final ApiService _api = ApiService.instance;
  final CacheEngine _cache = CacheEngine.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _state = FeedState.loading;
    notifyListeners();

    // Load persisted feed from Hive
    final stored = _hive.getAllVideos();
    _feed = stored;

    _state = FeedState.loaded;
    notifyListeners();

    // Kick off background caching for the first few items if online
    if (_connectivity.isOnline && _feed.isNotEmpty) {
      unawaited(_cache.scheduleLookahead(feed: _feed, currentIndex: 0));
    }
  }

  // ── Feed management ────────────────────────────────────────────────────────

  /// Adds a new video from a TikTok/YouTube Shorts URL.
  Future<void> addVideoFromUrl(String url) async {
    if (!_connectivity.isOnline) {
      _setError('You are offline. Connect to add new videos.');
      return;
    }
    _isAddingVideo = true;
    notifyListeners();

    try {
      final existing = _hive.box.values
          .where((v) => v.originalUrl == url)
          .toList();

      if (existing.isNotEmpty) {
        // Move to front of feed
        _feed.removeWhere((v) => v.id == existing.first.id);
        _feed.insert(0, existing.first);
        _currentIndex = 0;
        _isAddingVideo = false;
        notifyListeners();
        return;
      }

      final video = await _api.extractVideo(url);
      await _hive.upsert(video);

      _feed.insert(0, video);
      _currentIndex = 0;

      _isAddingVideo = false;
      notifyListeners();

      // Start caching in background
      unawaited(_cache.scheduleLookahead(feed: _feed, currentIndex: 0));
    } on ApiException catch (e) {
      _isAddingVideo = false;
      _setError(e.message);
    } catch (e) {
      _isAddingVideo = false;
      _setError('Unexpected error: $e');
    }
  }

  /// Called whenever the user swipes to [index].
  Future<void> onPageChanged(int index) async {
    _currentIndex = index;
    notifyListeners();

    // Touch for LRU
    if (index < _feed.length) {
      await _hive.markAccessed(_feed[index].id);
    }

    // Trigger background pre-caching of the next videos
    if (_connectivity.isOnline) {
      unawaited(_cache.scheduleLookahead(feed: _feed, currentIndex: index));
    }
  }

  /// Force-download a specific video (e.g. user taps "Save").
  Future<void> saveVideo(String videoId) async {
    final video = _hive.getById(videoId);
    if (video == null || video.isCached) return;
    unawaited(_cache.downloadVideo(video));
  }

  /// Delete a video from feed + cache.
  Future<void> removeVideo(String videoId) async {
    final video = _hive.getById(videoId);
    if (video != null) await _cache.evict(video);
    await _hive.delete(videoId);
    _feed.removeWhere((v) => v.id == videoId);
    if (_currentIndex >= _feed.length) {
      _currentIndex = (_feed.length - 1).clamp(0, _feed.length);
    }
    notifyListeners();
  }

  // ── Cache stats ────────────────────────────────────────────────────────────

  double get cacheMb => _hive.totalCachedBytes() / (1024 * 1024);
  double get cacheGb => cacheMb / 1024;
  double get cacheFraction => (_hive.totalCachedBytes() / kMaxCacheBytes).clamp(0.0, 1.0);

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setError(String msg) {
    _errorMessage = msg;
    _state = FeedState.error;
    notifyListeners();
    // Auto-clear error after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (_errorMessage == msg) {
        _errorMessage = '';
        _state = FeedState.loaded;
        notifyListeners();
      }
    });
  }

  void clearError() {
    _errorMessage = '';
    _state = FeedState.loaded;
    notifyListeners();
  }

  @override
  void dispose() {
    _cache.dispose();
    super.dispose();
  }
}
