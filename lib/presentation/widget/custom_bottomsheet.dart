import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'sophia_style.dart';

/// Frosted bottom sheet with a title, message, text box and Send button.
/// Used for reporting reels (same API as before).
class CustomBottomSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final String hint;
  final TextEditingController controller;
  final GestureTapCallback onTap;
  const CustomBottomSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.controller,
    required this.onTap,
  });

  @override
  State<CustomBottomSheet> createState() => _CustomBottomSheetState();
}

class _CustomBottomSheetState extends State<CustomBottomSheet> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focus.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool get _isReport => widget.title.toLowerCase().contains('report');

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.trim().isNotEmpty;
    final accent = _isReport ? const Color(0xFFD99A98) : SophiaColors.champagne;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [const Color(0xFF261512).withValues(alpha: 0.96), SophiaColors.bgTop],
              ),
              border: Border(top: BorderSide(color: accent.withValues(alpha: 0.45))),
            ),
            padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + MediaQuery.paddingOf(context).bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: SophiaColors.lilac.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: 0.12),
                          border: Border.all(color: accent.withValues(alpha: 0.5)),
                        ),
                        child: Icon(
                          _isReport ? Icons.outlined_flag_rounded : Icons.edit_note_rounded,
                          color: accent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: SophiaColors.lavender,
                            fontSize: 25,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            fontFamily: sophiaSerif,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(color: SophiaColors.muted, fontSize: 13, height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: _focus.hasFocus ? 0.07 : 0.04),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: _focus.hasFocus ? accent.withValues(alpha: 0.7) : SophiaColors.lilac.withValues(alpha: 0.2),
                      ),
                    ),
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      cursorColor: accent,
                      minLines: 4,
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.45),
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        hintMaxLines: 3,
                        hintStyle: const TextStyle(color: SophiaColors.muted, fontSize: 14, height: 1.4),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  AmethystButton(
                    label: _isReport ? 'Send report' : 'Send',
                    height: 54,
                    onTap: widget.onTap,
                    leading: Icon(Icons.send_rounded, color: hasText ? SophiaColors.champagne : SophiaColors.muted, size: 17),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
