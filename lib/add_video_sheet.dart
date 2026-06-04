// Folder: lib/widgets/
// File:   add_video_sheet.dart
//
// Bottom sheet that lets the user paste a TikTok or YouTube Shorts URL
// and add it to their feed.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/feed_provider.dart';

class AddVideoSheet extends StatefulWidget {
  const AddVideoSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddVideoSheet(),
    );
  }

  @override
  State<AddVideoSheet> createState() => _AddVideoSheetState();
}

class _AddVideoSheetState extends State<AddVideoSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _valid = false;

  static final _urlRe = RegExp(
    r'(https?://)?(www\.|vm\.|vt\.)?tiktok\.com/.+|'
    r'(https?://)?(www\.)?youtube\.com/shorts/[A-Za-z0-9_-]+|'
    r'(https?://)?youtu\.be/[A-Za-z0-9_-]+',
  );

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _valid = _urlRe.hasMatch(v.trim()));
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _ctrl.text = data!.text!;
      _onChanged(data.text!);
    }
  }

  Future<void> _submit() async {
    if (!_valid) return;
    final url = _ctrl.text.trim();
    Navigator.of(context).pop();
    // ignore: use_build_context_synchronously
    await context.read<FeedProvider>().addVideoFromUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const Text(
            'Add a video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Paste a TikTok or YouTube Shorts link',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // URL field
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _valid
                    ? const Color(0xFF1D9E75)
                    : Colors.white.withOpacity(0.12),
                width: _valid ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    onChanged: _onChanged,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'https://www.tiktok.com/@...',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.content_paste_rounded,
                      color: Colors.white38, size: 20),
                  onPressed: _paste,
                  tooltip: 'Paste',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Quick-access platform hints
          Row(
            children: [
              _PlatformHint(
                label: 'YouTube Shorts',
                color: Colors.red,
                icon: Icons.smart_display_rounded,
                onTap: () {
                  _ctrl.text = 'https://youtube.com/shorts/';
                  _ctrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: _ctrl.text.length),
                  );
                  _focus.requestFocus();
                },
              ),
              const SizedBox(width: 8),
              _PlatformHint(
                label: 'TikTok',
                color: const Color(0xFF69C9D0),
                icon: Icons.music_note_rounded,
                onTap: () {
                  _ctrl.text = 'https://www.tiktok.com/@';
                  _ctrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: _ctrl.text.length),
                  );
                  _focus.requestFocus();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Submit button
          Consumer<FeedProvider>(
            builder: (_, feed, __) {
              final loading = feed.isAddingVideo;
              return SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_valid && !loading) ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D9E75),
                    disabledBackgroundColor: Colors.white12,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Add to Feed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlatformHint extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _PlatformHint({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
