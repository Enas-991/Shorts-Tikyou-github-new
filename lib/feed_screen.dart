// Folder: lib/screens/
// File:   feed_screen.dart
//
// Main screen: full-screen vertical PageView of videos.
// Auto-plays the current item, pauses others.
// Shows top bar, side actions, meta overlay, and bottom nav.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/video_model.dart';
import '../services/connectivity_service.dart';
import '../services/feed_provider.dart';
import '../widgets/add_video_sheet.dart';
import '../widgets/side_actions_widget.dart';
import '../widgets/video_meta_overlay.dart';
import '../widgets/video_player_widget.dart';
import 'settings_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedProvider>().init();
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Force full-screen immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Consumer<FeedProvider>(
        builder: (context, feed, _) {
          // ── Error toast ───────────────────────────────────────────
          if (feed.errorMessage.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showErrorSnack(context, feed.errorMessage);
            });
          }

          // ── Empty / loading state ──────────────────────────────
          if (feed.state == FeedState.loading) {
            return const _LoadingView();
          }

          if (feed.feed.isEmpty) {
            return _EmptyFeedView(
              onAdd: () => AddVideoSheet.show(context),
            );
          }

          // ── Main feed ─────────────────────────────────────────────
          return Stack(
            children: [
              PageView.builder(
                controller: _pageCtrl,
                scrollDirection: Axis.vertical,
                itemCount: feed.feed.length,
                onPageChanged: (idx) {
                  feed.onPageChanged(idx);
                },
                itemBuilder: (context, index) {
                  final video = feed.feed[index];
                  final isActive = index == feed.currentIndex;

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // ── Full-screen video ─────────────────────────
                      VideoPlayerWidget(
                        video: video,
                        isActive: isActive,
                      ),

                      // ── Gradient scrim for readability ────────────
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x55000000),
                                Colors.transparent,
                                Colors.transparent,
                                Color(0xBB000000),
                              ],
                              stops: [0, 0.15, 0.55, 1],
                            ),
                          ),
                        ),
                      ),

                      // ── Bottom-left meta ──────────────────────────
                      Positioned(
                        left: 14,
                        bottom: 92,
                        right: 70,
                        child: VideoMetaOverlay(video: video),
                      ),

                      // ── Right-side actions ────────────────────────
                      Positioned(
                        right: 10,
                        bottom: 100,
                        child: SideActionsWidget(
                          video: video,
                          onDelete: () => feed.removeVideo(video.id),
                        ),
                      ),

                      // ── Page indicator dots ───────────────────────
                      Positioned(
                        right: 6,
                        top: MediaQuery.of(context).padding.top + 80,
                        child: _PageDots(
                          total: feed.feed.length,
                          current: feed.currentIndex,
                        ),
                      ),
                    ],
                  );
                },
              ),

              // ── Top app bar ────────────────────────────────────────
              _TopBar(
                onAdd: () => AddVideoSheet.show(context),
                onSettings: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),

              // ── Bottom navigation bar ──────────────────────────────
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: _BottomNav(
                  onAdd: () => AddVideoSheet.show(context),
                ),
              ),

              // ── Connectivity banner ────────────────────────────────
              const _ConnBanner(),
            ],
          );
        },
      ),
    );
  }

  void _showErrorSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFF993C1D),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 90),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onSettings;

  const _TopBar({required this.onAdd, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            16, MediaQuery.of(context).padding.top + 8, 16, 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC000000), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            // Logo
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D9E75),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                const Text(
                  'DataCharge',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: Colors.white, size: 26),
              onPressed: onAdd,
              tooltip: 'Add video',
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.settings_outlined,
                  color: Colors.white, size: 24),
              onPressed: onSettings,
              tooltip: 'Settings',
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final VoidCallback onAdd;
  const _BottomNav({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 56 + bottom,
      padding: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(icon: Icons.home_rounded, label: 'home', active: true),
          _NavItem(icon: Icons.explore_outlined, label: 'explore'),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 40,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1D9E75),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
            ),
          ),
          _NavItem(icon: Icons.bookmark_border_rounded, label: 'saved'),
          _NavItem(icon: Icons.person_outline_rounded, label: 'profile'),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _NavItem({required this.icon, required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : Colors.white38;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  final int total;
  final int current;

  const _PageDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();
    final visible = total.clamp(0, 7);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(visible, (i) {
        final isActive = i == current.clamp(0, visible - 1);
        return Container(
          width: 3,
          height: isActive ? 16 : 5,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white30,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

class _ConnBanner extends StatelessWidget {
  const _ConnBanner();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ConnectivityService.instance,
      builder: (_, __) {
        final online = ConnectivityService.instance.isOnline;
        if (online) return const SizedBox.shrink();
        return Positioned(
          top: MediaQuery.of(context).padding.top + 52,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFBA7517).withOpacity(0.95),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Offline — playing cached videos only',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF1D9E75),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Loading feed…',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _EmptyFeedView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyFeedView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF1D9E75).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.video_library_outlined,
                color: Color(0xFF1D9E75),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your feed is empty',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a TikTok or YouTube Shorts link to start watching offline-ready videos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Add your first video',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D9E75),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
