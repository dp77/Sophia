import 'package:girlfriend/core/haptics.dart';
import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:grokbot_widget/grokbot_widget.dart';

import '../../data/navigation_service.dart';
import 'sophia_style.dart';

/// App-wide toast: a frosted plum pill that drops in from the top with the
/// GrokBot mascot reacting to the message. Needs no BuildContext.
///
///   SophiaToast.show(msg: 'Saved');                       // tone guessed
///   SophiaToast.show(msg: 'Oops', type: ToastType.error); // explicit
enum ToastType { info, success, error }

class SophiaToast {
  SophiaToast._();

  static OverlayEntry? _entry;

  static void show({required Object? msg, ToastType? type, Duration? duration}) {
    final text = msg?.toString().trim() ?? '';
    if (text.isEmpty) return;
    final overlay = NavigationService.overlay;
    if (overlay == null) {
      debugPrint('[SophiaToast] No overlay: $text');
      return;
    }

    final kind = type ?? _guess(text);
    if (kind == ToastType.error) Haptics.error();
    if (kind == ToastType.success) Haptics.success();

    // Only one toast at a time: the new one replaces the old.
    _entry?.remove();
    _entry = OverlayEntry(
      builder: (_) => _ToastView(
        text: text,
        type: kind,
        duration: duration ?? Duration(milliseconds: text.length > 60 ? 3800 : 2600),
        onDone: _remove,
      ),
    );
    overlay.insert(_entry!);
  }

  static void _remove() {
    _entry?.remove();
    _entry = null;
  }

  static ToastType _guess(String text) {
    final t = text.toLowerCase();
    const bad = ['fail', 'error', 'no internet', 'invalid', 'not found', 'wrong', 'limit', 'cancel', 'unable', 'could not'];
    const good = ['success', 'thank', 'created', 'cleared', 'signed out', 'reported', 'earned', 'activated', 'saved'];
    if (bad.any(t.contains)) return ToastType.error;
    if (good.any(t.contains)) return ToastType.success;
    return ToastType.info;
  }
}

const _rose = Color(0xFFD99A98);

class _ToastView extends StatefulWidget {
  final String text;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDone;
  const _ToastView({super.key, required this.text, required this.type, required this.duration, required this.onDone});

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 260),
  );
  Timer? _timer;
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) return;
    await _c.reverse();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  Color get _accent => switch (widget.type) {
    ToastType.error => _rose,
    ToastType.success => SophiaColors.champagne,
    ToastType.info => SophiaColors.lilac,
  };

  GrokBotState get _mood => switch (widget.type) {
    ToastType.error => GrokBotState.sad,
    ToastType.success => GrokBotState.happy,
    ToastType.info => GrokBotState.curious,
  };

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 10;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);

    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: curve,
        builder: (_, child) => Opacity(
          opacity: _c.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (reduceMotion ? 0 : (1 - curve.value) * -40) + _drag),
            child: child,
          ),
        ),
        child: GestureDetector(
          onTap: _dismiss,
          // Swipe up to dismiss.
          onVerticalDragUpdate: (d) => setState(() => _drag = (_drag + d.delta.dy).clamp(-80.0, 0.0)),
          onVerticalDragEnd: (_) => _drag < -24 ? _dismiss() : setState(() => _drag = 0),
          child: Material(
            type: MaterialType.transparency,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF261512).withValues(alpha: 0.92),
                          SophiaColors.bgTop.withValues(alpha: 0.92),
                        ],
                      ),
                      border: Border.all(color: _accent.withValues(alpha: 0.4)),
                      boxShadow: [
                        BoxShadow(color: _accent.withValues(alpha: 0.18), blurRadius: 28, spreadRadius: -6),
                        BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _accent.withValues(alpha: 0.12),
                            border: Border.all(color: _accent.withValues(alpha: 0.45)),
                          ),
                          alignment: Alignment.center,
                          child: GrokBot(
                            size: 24,
                            shape: GrokBotShape.blob,
                            state: _mood,
                            theme: GrokBotThemeData(bodyColor: _accent, eyeColor: SophiaColors.bgBottom),
                            semanticLabel: 'Sophia mascot',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                            widget.text,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: SophiaColors.lavender,
                              fontSize: 13.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
