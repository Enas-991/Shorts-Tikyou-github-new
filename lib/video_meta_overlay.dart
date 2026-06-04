// Folder: lib/widgets/
// File:   video_meta_overlay.dart
//
// Bottom-left overlay shown on each video card:
// username, caption, platform badge, and connectivity indicator.

import 'package:flutter/material.dart';

import '../models/video_model.dart';
import '../services/connectivity_service.dart';

class VideoMetaOverlay extends StatelessWidget {
  final VideoModel video;

  const VideoMetaOverlay({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    final online = ConnectivityService.instance.isOnline;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Platform + connectivity row
        Row(
          children: [
            _PlatformBadge(platform: video.platform),
            const SizedBox(width: 8),
            _ConnBadge(online: online, isCached: video.isCached),
          ],
        ),
        const SizedBox(height: 8),

        // Username
        Text(
          '@${_fakeUsername(video)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(blurRadius: 4)],
          ),
        ),
        const SizedBox(height: 4),

        // Caption / title
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.72,
          child: Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.4,
              shadows: [Shadow(blurRadius: 3)],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Duration pill
        if (video.duration != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _formatDuration(video.duration!),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  String _fakeUsername(VideoModel v) {
    // In a real app this would come from the API or user profile.
    final seed = v.id.hashCode;
    final names = [
      'techshorts', 'codewaves', 'devdrops', 'aivibes',
      'flutterdev', 'pythonpills', 'uicraft', 'stackbits',
    ];
    return names[seed.abs() % names.length];
  }

  String _formatDuration(double seconds) {
    final d = Duration(seconds: seconds.round());
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Platform badge ─────────────────────────────────────────────────────────

class _PlatformBadge extends StatelessWidget {
  final VideoPlatform platform;
  const _PlatformBadge({required this.platform});

  @override
  Widget build(BuildContext context) {
    final isYT = platform == VideoPlatform.youtube;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isYT ? const Color(0xFFFF0000) : Colors.black,
        borderRadius: BorderRadius.circular(6),
        border: isYT
            ? null
            : Border.all(color: const Color(0xFF69C9D0), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isYT ? Icons.smart_display_rounded : Icons.music_note_rounded,
            color: isYT ? Colors.white : const Color(0xFF69C9D0),
            size: 11,
          ),
          const SizedBox(width: 4),
          Text(
            isYT ? 'YouTube' : 'TikTok',
            style: TextStyle(
              color: isYT ? Colors.white : const Color(0xFF69C9D0),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Connectivity badge ─────────────────────────────────────────────────────

class _ConnBadge extends StatelessWidget {
  final bool online;
  final bool isCached;

  const _ConnBadge({required this.online, required this.isCached});

  @override
  Widget build(BuildContext context) {
    String label;
    Color bg;

    if (!online && isCached) {
      label = '● offline';
      bg = const Color(0xFFBA7517).withOpacity(0.88);
    } else if (isCached) {
      label = '● cached';
      bg = const Color(0xFF1D9E75).withOpacity(0.88);
    } else if (online) {
      label = '● live';
      bg = Colors.white.withOpacity(0.18);
    } else {
      label = '✕ no source';
      bg = Colors.red.withOpacity(0.6);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
