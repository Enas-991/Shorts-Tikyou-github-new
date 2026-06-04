// Folder: lib/widgets/
// File:   video_player_widget.dart
//
// Full-screen video player for one feed item.
// • Streams from remoteUrl when online, localFilePath when offline/cached
// • Shows buffering spinner + error state
// • Auto-plays when [isActive] is true, pauses otherwise

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/video_model.dart';
import '../services/connectivity_service.dart';

class VideoPlayerWidget extends StatefulWidget {
  final VideoModel video;
  final bool isActive;

  const VideoPlayerWidget({
    super.key,
    required this.video,
    required this.isActive,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  String _errorMsg = '';
  bool _showControls = false;
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _initPlayer();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget old) {
    super.didUpdateWidget(old);
    if (old.isActive != widget.isActive) {
      if (widget.isActive) {
        _controller?.play();
        widget.video.touch();
      } else {
        _controller?.pause();
      }
    }
    // If video model changed (e.g. remoteUrl refreshed), reinitialise
    if (old.video.id != widget.video.id) {
      _dispose();
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    setState(() {
      _initialized = false;
      _hasError = false;
    });

    final online = ConnectivityService.instance.isOnline;
    VideoPlayerController ctrl;

    try {
      if (widget.video.isCached) {
        ctrl = VideoPlayerController.file(File(widget.video.localFilePath));
      } else if (online && widget.video.remoteUrl.isNotEmpty) {
        ctrl = VideoPlayerController.networkUrl(
          Uri.parse(widget.video.remoteUrl),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );
      } else {
        setState(() {
          _hasError = true;
          _errorMsg = online
              ? 'No video URL available.'
              : 'Offline — video not cached yet.';
        });
        return;
      }

      _controller = ctrl;
      await ctrl.initialize();
      ctrl.setLooping(true);

      if (mounted) {
        setState(() => _initialized = true);
        if (widget.isActive) ctrl.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMsg = 'Playback error: ${e.toString().split('\n').first}';
        });
      }
    }
  }

  void _dispose() {
    _controller?.dispose();
    _controller = null;
    _initialized = false;
  }

  void _togglePlayPause() {
    if (_controller == null || !_initialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _showControls = true;
    });
    _fadeCtrl.forward(from: 0).then((_) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _fadeCtrl.reverse();
          setState(() => _showControls = false);
        }
      });
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Video or placeholder ──────────────────────────────────
            if (_initialized && _controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              )
            else if (_hasError)
              _ErrorView(message: _errorMsg, onRetry: () {
                _dispose();
                _initPlayer();
              })
            else
              const _BufferingView(),

            // ── Play/pause overlay ────────────────────────────────────
            if (_showControls && _initialized)
              FadeTransition(
                opacity: _fadeCtrl,
                child: Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _controller!.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),

            // ── Progress bar ──────────────────────────────────────────
            if (_initialized && _controller != null)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white30,
                    backgroundColor: Colors.white10,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),

            // ── Cache status badge ────────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              child: _CacheChip(video: widget.video),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _BufferingView extends StatelessWidget {
  const _BufferingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white60,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, color: Colors.white70),
              label: const Text('Retry', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CacheChip extends StatelessWidget {
  final VideoModel video;
  const _CacheChip({required this.video});

  @override
  Widget build(BuildContext context) {
    Color bg;
    String label;
    IconData icon;

    switch (video.cacheStatus) {
      case CacheStatus.cached:
        bg = const Color(0xFF1D9E75);
        label = 'cached';
        icon = Icons.offline_bolt_rounded;
        break;
      case CacheStatus.downloading:
        bg = const Color(0xFF185FA5);
        label = 'saving…';
        icon = Icons.downloading_rounded;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.88),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
