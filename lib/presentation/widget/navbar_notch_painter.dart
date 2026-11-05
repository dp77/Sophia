import 'package:girlfriend/presentation/widget/sophia_style.dart';
import 'package:girlfriend/core/haptics.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/colors.dart';

class PremiumFloatingNavBar extends StatelessWidget {
  final Widget child;
  final GestureTapCallback onTap;
  const PremiumFloatingNavBar({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double containerWidth = MediaQuery.sizeOf(context).width * 0.9;
    final double containerHeight = 70;

    final double buttonRadius = 34;
    final double notchGap = 4;
    final double shoulderRadius = 20;
    final double buttonCenterY = 0;

    final double topPadding = buttonRadius + 20;

    return SizedBox(
      width: containerWidth,
      height: containerHeight + topPadding,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: topPadding,
            child: ClipPath(
              clipper: NavBarClipper(
                buttonRadius: buttonRadius,
                gap: notchGap,
                shoulderRadius: shoulderRadius,
                buttonCenterY: buttonCenterY,
              ),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 7.0, sigmaY: 7.0),
                child: CustomPaint(
                  size: Size(containerWidth, containerHeight),
                  painter: NavBarPainter(
                    buttonRadius: buttonRadius,
                    gap: notchGap,
                    shoulderRadius: shoulderRadius,
                    buttonCenterY: buttonCenterY,
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    width: containerWidth,
                    height: containerHeight,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: topPadding + buttonCenterY - buttonRadius,
            child: GestureDetector(
              onTap: Haptics.wrap(onTap),
              child: Container(
                width: buttonRadius * 2,
                height: buttonRadius * 2,
                color: Colors.transparent,
                child: Stack(
                  children: [
                    Image.asset(
                      'assets/images/circle.png',
                      fit: BoxFit.contain,
                      width: buttonRadius * 2,
                      height: buttonRadius * 2,
                    ),
                    Container(
                      width: buttonRadius * 2,
                      height: buttonRadius * 2,
                      padding: EdgeInsets.only(top: 4, left: 2),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/svg/nav_chat_fill.svg',
                          height: 30,
                          width: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Path getNotchedPath(
  Size size,
  double buttonRadius,
  double gap,
  double shoulderRadius,
  double buttonCenterY,
) {
  final width = size.width;
  final height = size.height;
  final cx = width / 2;
  final endRadius = height / 2;

  final double notchRadius = buttonRadius + gap;

  final dy = shoulderRadius - buttonCenterY;
  final distanceSq = pow(notchRadius + shoulderRadius, 2);
  final dySq = pow(dy, 2);
  final dx = sqrt(max(0, distanceSq - dySq));

  final shoulderCenterXLeft = cx - dx;
  final shoulderCenterXRight = cx + dx;

  final distance = notchRadius + shoulderRadius;
  final unitX = dx / distance;
  final unitY = -dy / distance;

  final tangentXLeft = shoulderCenterXLeft + shoulderRadius * unitX;
  final tangentYLeft = shoulderRadius + shoulderRadius * unitY;

  final tangentXRight = cx + (cx - tangentXLeft);
  final tangentYRight = tangentYLeft;

  final path = Path();

  path.moveTo(endRadius, 0);
  path.lineTo(shoulderCenterXLeft, 0);
  path.arcToPoint(
    Offset(tangentXLeft, tangentYLeft),
    radius: Radius.circular(shoulderRadius),
    clockwise: true,
  );
  path.arcToPoint(
    Offset(tangentXRight, tangentYRight),
    radius: Radius.circular(notchRadius),
    clockwise: false,
  );
  path.arcToPoint(
    Offset(shoulderCenterXRight, 0),
    radius: Radius.circular(shoulderRadius),
    clockwise: true,
  );
  path.lineTo(width - endRadius, 0);
  path.arcToPoint(
    Offset(width - endRadius, height),
    radius: Radius.circular(endRadius),
    clockwise: true,
  );
  path.lineTo(endRadius, height);
  path.arcToPoint(
    Offset(endRadius, 0),
    radius: Radius.circular(endRadius),
    clockwise: true,
  );

  path.close();
  return path;
}

class NavBarClipper extends CustomClipper<Path> {
  final double buttonRadius;
  final double gap;
  final double shoulderRadius;
  final double buttonCenterY;

  NavBarClipper({
    required this.buttonRadius,
    required this.gap,
    required this.shoulderRadius,
    required this.buttonCenterY,
  });

  @override
  Path getClip(Size size) {
    return getNotchedPath(
      size,
      buttonRadius,
      gap,
      shoulderRadius,
      buttonCenterY,
    );
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}

class NavBarPainter extends CustomPainter {
  final double buttonRadius;
  final double gap;
  final double shoulderRadius;
  final double buttonCenterY;

  NavBarPainter({
    required this.buttonRadius,
    required this.gap,
    required this.shoulderRadius,
    required this.buttonCenterY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Get the exact same path
    final path = getNotchedPath(
      size,
      buttonRadius,
      gap,
      shoulderRadius,
      buttonCenterY,
    );

    // 2. YOUR CUSTOM FILL CODE HERE
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [darkBlue.withValues(alpha: 0.6), darkPurple.withValues(alpha: 0.6)],
      );
    canvas.drawPath(path, fillPaint);

    // 3. TOP-TO-BOTTOM GRADIENT STROKE
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [extraLightViolet, lightViolet],
      );
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
