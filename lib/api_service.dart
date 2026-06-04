// Folder: lib/services/
// File:   api_service.dart
//
// Communicates with the Python FastAPI backend to resolve direct MP4 URLs.
// Falls back gracefully when offline.

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/video_model.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  static ApiService? _instance;
  late final Dio _dio;

  /// Change this to your backend address.
  /// For emulator: http://10.0.2.2:8000
  /// For physical device: http://<YOUR_PC_LOCAL_IP>:8000
  /// For production: https://your-server.com
  static String baseUrl = 'http://10.0.2.2:8000';

  ApiService._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: false),
      );
    }
  }

  static ApiService get instance {
    _instance ??= ApiService._();
    return _instance!;
  }

  /// Update base URL at runtime (e.g. from settings screen).
  static void setBaseUrl(String url) {
    baseUrl = url;
    _instance = null; // Force re-creation with new URL
  }

  // ── Health ─────────────────────────────────────────────────────────────────

  Future<bool> isBackendReachable() async {
    try {
      final res = await _dio.get('/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Extraction ─────────────────────────────────────────────────────────────

  /// Calls POST /extract and returns a partially-populated [VideoModel].
  Future<VideoModel> extractVideo(String originalUrl) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/extract',
        data: {'url': originalUrl},
      );
      final data = response.data!;
      return _mapToVideoModel(data, originalUrl);
    } on DioException catch (e) {
      final detail = _parseDioError(e);
      throw ApiException(detail, statusCode: e.response?.statusCode);
    } on SocketException {
      throw const ApiException('No internet connection.');
    }
  }

  /// GET variant — useful for quick lookups.
  Future<VideoModel> extractVideoGet(String originalUrl) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/extract',
        queryParameters: {'url': originalUrl},
      );
      final data = response.data!;
      return _mapToVideoModel(data, originalUrl);
    } on DioException catch (e) {
      final detail = _parseDioError(e);
      throw ApiException(detail, statusCode: e.response?.statusCode);
    } on SocketException {
      throw const ApiException('No internet connection.');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  VideoModel _mapToVideoModel(Map<String, dynamic> data, String originalUrl) {
    final platform = (data['platform'] as String? ?? '').toLowerCase() == 'tiktok'
        ? VideoPlatform.tiktok
        : VideoPlatform.youtube;

    return VideoModel(
      id: data['id'] as String? ?? _generateId(originalUrl),
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? data['title'] as String
          : 'Untitled',
      category: 'feed',
      remoteUrl: data['direct_url'] as String,
      localFilePath: '',
      platform: platform,
      thumbnailUrl: data['thumbnail'] as String?,
      duration: (data['duration'] as num?)?.toDouble(),
      fileSizeBytes: (data['filesize'] as num?)?.toInt() ?? 0,
      cacheStatus: CacheStatus.none,
      originalUrl: originalUrl,
      width: (data['width'] as num?)?.toInt(),
      height: (data['height'] as num?)?.toInt(),
    );
  }

  String _generateId(String url) =>
      url.hashCode.abs().toString();

  String _parseDioError(DioException e) {
    final body = e.response?.data;
    if (body is Map && body.containsKey('detail')) {
      return body['detail'].toString();
    }
    if (body is String && body.isNotEmpty) return body;
    return e.message ?? 'Unknown network error.';
  }
}
