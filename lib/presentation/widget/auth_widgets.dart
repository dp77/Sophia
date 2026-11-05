import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:girlfriend/core/haptics.dart';
import 'package:girlfriend/presentation/widget/sophia_style.dart';

/// Shared pieces of the Sign in and Create account screens.

const _fieldLabel = Color(0xFFC9BBD8);
const _bubbleText = Color(0xFFF3EAFE);
const _onlineGreen = Color(0xFF7EE2A8);

/// Her photo across the top, fading into the plum background, with the back
/// button and a chat bubble from Sophia on its lower edge.
class AuthHero extends StatelessWidget {
  final String image;
  final String message;
  final double height;

  const AuthHero({super.key, required this.image, required this.message, required this.height});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: height + top,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.55, 1],
              colors: [Colors.white, Colors.white, Colors.transparent],
            ).createShader(rect),
            child: Image.asset(image, fit: BoxFit.cover, alignment: const Alignment(0, -0.6)),
          ),
          // Darkens the top so the back button stays readable.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.35],
                colors: [Color(0x660D0614), Color(0x000D0614)],
              ),
            ),
          ),
          Positioned(left: 16, top: top + 12, child: const _BackButton()),
          Positioned(left: 20, right: 20, bottom: 6, child: _SophiaBubble(avatar: image, message: message)),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: InkWell(
        onTap: Haptics.wrap(() => Navigator.maybePop(context)),
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x8C1A0033),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: const Center(child: SvgIcon('ic_back', size: 20)),
        ),
      ),
    );
  }
}

class _SophiaBubble extends StatelessWidget {
  final String avatar;
  final String message;

  const _SophiaBubble({required this.avatar, required this.message});

  static const _radius = BorderRadius.only(
    topLeft: Radius.circular(18),
    topRight: Radius.circular(18),
    bottomRight: Radius.circular(18),
    bottomLeft: Radius.circular(6),
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 34,
          height: 34,
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(colors: [SophiaColors.champagne, SophiaColors.orchid, SophiaColors.champagne]),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: SophiaColors.bgTop, width: 2),
              image: DecorationImage(image: AssetImage(avatar), fit: BoxFit.cover, alignment: const Alignment(0, -0.7)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: ClipRRect(
              borderRadius: _radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xB8281440),
                    borderRadius: _radius,
                    border: Border.all(color: SophiaColors.lilac.withValues(alpha: 0.22)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'SOPHIA',
                            style: TextStyle(
                              color: SophiaColors.lilac,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                            ),
                          ),
                          const SizedBox(width: 6),
                          LoopAnimation(
                            duration: const Duration(milliseconds: 1000),
                            reverse: true,
                            builder: (_, t, child) => Opacity(opacity: 1 - 0.55 * t, child: child),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: _onlineGreen),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(message, style: const TextStyle(color: _bubbleText, fontSize: 14, height: 1.4)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Serif title with a muted line under it.
class AuthHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthHeading({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: sophiaSerif,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
            fontSize: 33,
            height: 1.1,
            color: SophiaColors.lavender,
          ),
        ),
        const SizedBox(height: 7),
        Text(subtitle, style: const TextStyle(color: SophiaColors.muted, fontSize: 14, height: 1.35)),
      ],
    );
  }
}

/// Labelled glass text field with a leading icon.
class AuthField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final FormFieldValidator<String>? validator;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.obscureText = false,
    this.validator,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
  });

  OutlineInputBorder _border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _fieldLabel, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          obscureText: obscureText,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          cursorColor: SophiaColors.champagne,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: SophiaColors.muted.withValues(alpha: 0.7), fontSize: 15),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 10),
              child: Icon(icon, size: 19, color: SophiaColors.lilac),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            errorStyle: const TextStyle(fontSize: 12),
            enabledBorder: _border(SophiaColors.lilac.withValues(alpha: 0.18)),
            focusedBorder: _border(const Color(0xFFCFB2FF), 1.3),
            errorBorder: _border(Colors.redAccent),
            focusedErrorBorder: _border(Colors.redAccent, 1.3),
          ),
        ),
      ],
    );
  }
}

/// Eye button that shows or hides a password.
class PasswordEye extends StatelessWidget {
  final bool obscured;
  final VoidCallback onTap;

  const PasswordEye({super.key, required this.obscured, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscured ? 'Show password' : 'Hide password',
      onPressed: Haptics.wrap(onTap),
      icon: Icon(
        obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: SophiaColors.muted,
        size: 20,
      ),
    );
  }
}

/// "—— or continue with ——"
class AuthDivider extends StatelessWidget {
  final String text;

  const AuthDivider({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    Widget line(List<Color> colors) => Expanded(
          child: Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: colors))),
        );
    final faint = SophiaColors.lilac.withValues(alpha: 0);
    final soft = SophiaColors.lilac.withValues(alpha: 0.3);
    return Row(
      children: [
        line([faint, soft]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text, style: const TextStyle(color: SophiaColors.muted, fontSize: 12)),
        ),
        line([soft, faint]),
      ],
    );
  }
}

/// Google button, plus Apple on iOS.
class AuthSocialRow extends StatelessWidget {
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;

  const AuthSocialRow({super.key, required this.onGoogle, required this.onApple});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SocialButton(
            icon: SvgPicture.asset('assets/svg/google.svg', width: 18, height: 18),
            label: 'Google',
            onTap: onGoogle,
          ),
        ),
        if (Platform.isIOS) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _SocialButton(
              icon: const Icon(Icons.apple, color: Colors.white, size: 22),
              label: 'Apple',
              onTap: onApple,
            ),
          ),
        ],
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback? onTap;

  const _SocialButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.6 : 1,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: SophiaColors.lilac.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "New to Sophia? Create account" at the bottom of the screen.
class AuthFooterLink extends StatelessWidget {
  final String text;
  final String action;
  final VoidCallback onTap;

  const AuthFooterLink({super.key, required this.text, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text, style: const TextStyle(color: SophiaColors.muted, fontSize: 14)),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: Haptics.wrap(onTap),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Text(
              action,
              style: const TextStyle(color: SophiaColors.champagne, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
