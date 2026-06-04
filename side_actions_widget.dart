// Folder: lib/widgets/
// File:   side_actions_widget.dart
//
// Right-side vertical action buttons (like, comment, save, share, delete)
// rendered on top of the video player in the feed.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:startapp_sdk/startapp.dart';

import '../models/video_model.dart';
import '../services/cache_engine.dart';
import '../services/connectivity_service.dart';

class SideActionsWidget extends StatefulWidget {
  final VideoModel video;
  final VoidCallback onDelete;

  const SideActionsWidget({
    super.key,
    required this.video,
    required this.onDelete,
  });

  @override
  State<SideActionsWidget> createState() => _SideActionsWidgetState();
}

class _SideActionsWidgetState extends State<SideActionsWidget> {
  bool _liked = false;
  bool _saving = false;

  var startAppSdk = StartAppSdk();
  StartAppAd? rewardedAd;

  @override
  void initState() {
    super.initState();
    loadRewardedAd();
  }

  void loadRewardedAd() {
    startAppSdk.loadRewardedAd(
      onAdReceived: (ad) {
        setState(() {
          rewardedAd = ad;
        });
      },
      onAdNotReceived: () {
        debugPrint("Failed to load rewarded ad");
      },
      onAdCompleted: () {
        _performShare();
      },
    );
  }

  void _showRewardedAd() {
    if (rewardedAd != null) {
      rewardedAd!.show().then((shown) {
        if (shown) {
          loadRewardedAd();
        }
      }).catchError((error) {
        debugPrint("Failed to show rewarded ad: $error");
        _performShare();
      });
    } else {
      _performShare();
    }
  }

  void _performShare() {
    Share.share(
      '${widget.video.title}\n\n${widget.video.originalUrl}',
      subject: 'Check out this video on DataCharge',
    );
  }

  void _toggleLike() {
    HapticFeedback.lightImpact();
    setState(() => _liked = !_liked);
  }

  Future<void> _saveVideo() async {
    if (widget.video.isCached || _saving) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    await CacheEngine.instance.downloadVideo(widget.video);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: _liked ? 'liked' : 'like',
          color: _liked ? const Color(0xFFFF4C61) : Colors.white,
          onTap: _toggleLike,
        ),
        const SizedBox(height: 20),
        _ActionButton(
          icon: Icons.comment_outlined,
          label: 'comment',
          onTap: () => _showCommentSnack(context),
        ),
        const SizedBox(height: 20),
        _SaveButton(
          video: widget.video,
          saving: _saving,
          onTap: _saveVideo,
        ),
        const SizedBox(height: 20),
        _ActionButton(
          icon: Icons.share_rounded,
          label: 'share',
          onTap: _showRewardedAd,
        ),
        const SizedBox(height: 20),
        _ActionButton(
          icon: Icons.delete_outline_rounded,
          label: 'remove',
          color: Colors.white60,
          onTap: widget.onDelete,
        ),
      ],
    );
  }

  void _showCommentSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comments coming soon'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF1a1a1a),
      ),
    );
  }
}

// ── Reusable action button ─────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.color = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Save button with progress ring ────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final VideoModel video;
  final bool saving;
  final VoidCallback onTap;

  const _SaveButton({
    required this.video,
    required this.saving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCached = video.isCached;
    final online = ConnectivityService.instance.isOnline;

    IconData icon;
    Color color;
    String label;

    if (isCached) {
      icon = Icons.offline_bolt_rounded;
      color = const Color(0xFF1D9E75);
      label = 'saved';
    } else if (saving) {
      icon = Icons.downloading_rounded;
      color = const Color(0xFF185FA5);
      label = 'saving';
    } else if (!online) {
      icon = Icons.cloud_off_rounded;
      color = Colors.white38;
      label = 'offline';
    } else {
      icon = Icons.download_rounded;
      color = Colors.white;
      label = 'save';
    }

    return GestureDetector(
      onTap: (isCached || saving || !online) ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              if (saving)
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF185FA5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
