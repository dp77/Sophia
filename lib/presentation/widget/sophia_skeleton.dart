import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:grokbot_widget/grokbot_widget.dart';

import 'sophia_dialog.dart';
import 'sophia_style.dart';

// Loading skeletons in the Sophia look: plum glass shapes shaped like the real
// content, with one soft lilac light sweeping across all of them together.

/// Sweeps a lilac highlight across every [SkeletonBox] inside [child].
class SophiaShimmer extends StatelessWidget {
  final Widget child;
  const SophiaShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return LoopAnimation(
      duration: const Duration(milliseconds: 1700),
      child: child,
      builder: (_, t, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SophiaColors.lilac.withValues(alpha: 0),
            SophiaColors.lilac.withValues(alpha: 0.16),
            SophiaColors.lilac.withValues(alpha: 0),
          ],
          stops: const [0.35, 0.5, 0.65],
          transform: _SlideGradient(Curves.easeInOut.transform(t)),
        ).createShader(bounds),
        child: child,
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double t;
  const _SlideGradient(this.t);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final dx = bounds.width * (2.4 * t - 1.2);
    final dy = bounds.height * (2.4 * t - 1.2);
    return Matrix4.translationValues(dx, dy, 0);
  }
}

/// One plum-glass placeholder shape.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  final bool circle;
  final double strength;
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = 12,
    this.circle = false,
    this.strength = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
        color: Colors.white.withValues(alpha: 0.055 * strength),
        border: Border.all(color: SophiaColors.lilac.withValues(alpha: 0.10 * strength)),
      ),
    );
  }
}

/// Home: the 2-column companion grid.
class HomeGridSkeleton extends StatelessWidget {
  const HomeGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SophiaShimmer(
      child: MasonryGridView.count(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        itemCount: 6,
        itemBuilder: (_, i) => AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(
            children: [
              const Positioned.fill(child: SkeletonBox(radius: 24)),
              Positioned(
                left: 10,
                right: 10,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      widthFactor: i.isEven ? 0.62 : 0.5,
                      child: const SkeletonBox(height: 12, radius: 6, strength: 1.8),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        SkeletonBox(width: 38, height: 16, radius: 8, strength: 1.5),
                        SizedBox(width: 4),
                        SkeletonBox(width: 30, height: 16, radius: 8, strength: 1.5),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chats tab: rows of avatar + name + last message.
class ChatListSkeleton extends StatelessWidget {
  const ChatListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SophiaShimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 120),
        itemCount: 7,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 84,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: SophiaColors.lilac.withValues(alpha: 0.10)),
            ),
            child: Row(
              children: [
                const SkeletonBox(width: 56, height: 56, circle: true, strength: 1.4),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SkeletonBox(width: i.isEven ? 110 : 84, height: 14, radius: 7, strength: 1.4),
                          const Spacer(),
                          const SkeletonBox(width: 28, height: 10, radius: 5),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FractionallySizedBox(
                        widthFactor: const [0.85, 0.6, 0.75, 0.5][i % 4],
                        child: const SkeletonBox(height: 10, radius: 5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chat screen: a few bubbles on either side while the conversation loads.
class ChatMessagesSkeleton extends StatelessWidget {
  const ChatMessagesSkeleton({super.key});

  // (isMe, width factor, height)
  static const _bubbles = [
    (false, 0.58, 44.0),
    (true, 0.42, 38.0),
    (false, 0.70, 62.0),
    (false, 0.36, 38.0),
    (true, 0.55, 44.0),
    (false, 0.62, 44.0),
    (true, 0.34, 38.0),
  ];

  @override
  Widget build(BuildContext context) {
    return SophiaShimmer(
      child: LayoutBuilder(
        builder: (context, box) => Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Center(child: SkeletonBox(width: 74, height: 22, radius: 11)),
            const SizedBox(height: 8),
            for (final (isMe, factor, height) in _bubbles)
              Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: box.maxWidth * factor,
                  height: height,
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: isMe
                        ? SophiaColors.amethystMid.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 6),
                      bottomRight: Radius.circular(isMe ? 6 : 20),
                    ),
                    border: Border.all(color: SophiaColors.lilac.withValues(alpha: 0.10)),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Shown when content couldn't be loaded: drowsy mascot, a line of copy and a retry button.
class SophiaRetryCard extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  const SophiaRetryCard({
    super.key,
    this.title = "Couldn't load this",
    this.message = 'Check your connection and try again.',
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SophiaMascotHero(state: GrokBotState.drowsy),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SophiaColors.lavender,
                fontSize: 21,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                fontFamily: sophiaSerif,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: SophiaColors.muted, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 180,
              child: AmethystButton(
                label: 'Try again',
                height: 46,
                leading: const Icon(Icons.refresh_rounded, color: SophiaColors.champagne, size: 18),
                onTap: onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
