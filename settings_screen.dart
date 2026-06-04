
// Folder: lib/screens/
// File:   settings_screen.dart
//
// Settings: backend URL, cache stats, clear cache, and storage usage.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:startapp_sdk/startapp.dart';

import '../services/api_service.dart';
import '../services/cache_engine.dart';
import '../services/feed_provider.dart';
import '../services/hive_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlCtrl;
  bool _checkingBackend = false;
  String? _backendStatus;
  var startAppSdk = StartAppSdk();
  StartAppAd? interstitialAd;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: ApiService.baseUrl);

    // Load an ad
    startAppSdk.loadInterstitialAd().then((ad) {
      setState(() {
        interstitialAd = ad;
      });
      // Show the ad after the first frame
      WidgetsBinding.instance.addPostFrameCallback((_) => showInterstitialAd());
    }).catchError((e) {
      debugPrint("Failed to load interstitial ad: $e");
    });
  }

  void showInterstitialAd() {
    if (interstitialAd != null) {
      interstitialAd!.show().then((shown) {
        if (shown) {
          // Ad was shown, load the next one
          startAppSdk.loadInterstitialAd().then((ad) {
            setState(() {
              interstitialAd = ad;
            });
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkBackend() async {
    setState(() {
      _checkingBackend = true;
      _backendStatus = null;
    });
    ApiService.setBaseUrl(_urlCtrl.text.trim());
    final ok = await ApiService.instance.isBackendReachable();
    setState(() {
      _checkingBackend = false;
      _backendStatus = ok ? '✓ Connected' : '✗ Unreachable';
    });
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        title: const Text('Clear cache?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'All downloaded videos will be deleted. This frees up storage but requires re-downloading.',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear',
                style: TextStyle(color: Color(0xFFE24B4A)))),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await CacheEngine.instance.clearAll();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared'),
            backgroundColor: Color(0xFF1D9E75),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hive = HiveService.instance;
    final stats = hive.debugStats();
    final feed = context.watch<FeedProvider>();

    final cacheMb = feed.cacheMb;
    final cacheGb = feed.cacheGb;
    final fraction = feed.cacheFraction;

    return Scaffold(
      backgroundColor: const Color(0xFF0d0d0d),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Backend URL ──────────────────────────────────────────────
          _Section(
            title: 'Backend Server',
            children: [
              const Text(
                'Python FastAPI server URL. Use 10.0.2.2:8000 for emulator or your local IP for physical device.',
                style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 12),
              _DarkField(
                controller: _urlCtrl,
                hint: 'http://10.0.2.2:8000',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _checkingBackend ? null : _checkBackend,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF185FA5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _checkingBackend
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Test Connection',
                              style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  if (_backendStatus != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      _backendStatus!,
                      style: TextStyle(
                        color: _backendStatus!.startsWith('✓')
                            ? const Color(0xFF1D9E75)
                            : const Color(0xFFE24B4A),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Cache stats ───────────────────────────────────────────────
          _Section(
            title: 'Storage',
            children: [
              // Usage bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${cacheMb.toStringAsFixed(0)} MB used',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${(2048 - cacheMb).clamp(0, 2048).toStringAsFixed(0)} MB free',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 8,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(
                    fraction > 0.85
                        ? const Color(0xFFBA7517)
                        : const Color(0xFF1D9E75),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(fraction * 100).toStringAsFixed(1)}% of 2 GB limit',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 16),

              // Stat grid
              Row(
                children: [
                  _StatChip(
                    label: 'Total videos',
                    value: '${stats['total_entries']}',
                  ),
                  const SizedBox(width: 10),
                  _StatChip(
                    label: 'Cached',
                    value: '${stats['cached_count']}',
                  ),
                  const SizedBox(width: 10),
                  _StatChip(
                    label: 'Downloaded',
                    value: '${cacheGb.toStringAsFixed(2)} GB',
                  ),
                ],
              ),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _clearCache,
                  icon: const Icon(Icons.delete_sweep_rounded,
                      color: Color(0xFFE24B4A), size: 18),
                  label: const Text('Clear all cached videos',
                      style: TextStyle(color: Color(0xFFE24B4A))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE24B4A), width: 0.8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Cache behaviour ───────────────────────────────────────────
          _Section(
            title: 'Cache Behaviour',
            children: [
              _InfoRow(
                icon: Icons.looks_3_outlined,
                label: 'Pre-cache lookahead',
                value: '3 videos ahead',
              ),
              _InfoRow(
                icon: Icons.storage_rounded,
                label: 'Max cache size',
                value: '2 GB (LRU eviction)',
              ),
              _InfoRow(
                icon: Icons.wifi_tethering_rounded,
                label: 'Offline playback',
                value: 'Auto (Hive + local file)',
              ),
              _InfoRow(
                icon: Icons.bolt_rounded,
                label: 'Extraction engine',
                value: 'Python + yt-dlp',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── About ──────────────────────────────────────────────────────
          _Section(
            title: 'About',
            children: [
              _InfoRow(
                icon: Icons.info_outline_rounded,
                label: 'Version',
                value: '1.0.0',
              ),
              _InfoRow(
                icon: Icons.video_library_outlined,
                label: 'Platforms',
                value: 'YouTube Shorts, TikTok',
              ),
              _InfoRow(
                icon: Icons.code_rounded,
                label: 'Backend',
                value: 'FastAPI + yt-dlp',
              ),
              _InfoRow(
                icon: Icons.storage_outlined,
                label: 'Local DB',
                value: 'Hive (Flutter)',
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1a1a1a),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  const _DarkField({
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style:
                    const TextStyle(color: Colors.white60, fontSize: 13)),
          ),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
