import 'package:flutter/material.dart';

// class AppColors {
//   static const Color backgroundColor = Color(0xFFFFFFFF); // White background, adjust as needed
//   static const Color primary = Color(0xFFFFFFFF); // Same color as loading indicator
//   static const Color newPrimary = Color(0xFFf9547c);
//   static const Color darkPrimary = Color(0xff551e2b);
//   static const Color splashBackground = Color(0xff000000); // Same color as loading indicator
//   static const Color textColor = Color(0xFFFFFFFF); // Same color as loading indicator
//   static const Color hintColor = Color(0xff8f8b8b);
//   static const Color blackTextColor = Color(0xff000000);
//   static const Color buttonBlackTextColor = Color(0xff000000);
//   static const Color iconColor = Color(0xffffffff);
//   static const Color blackIconColor = Color(0xff000000);
//   static Color dividerColor = Color(0xffffffff).withValues(alpha: 0.2);
//   static const Color blue = Color(0xff0E0D1D);
//   static const Color cardColor = Color(0xFF1A1A1A);
//   static const Color textGray = Color(0xFF8E8E93);
// }

final Color darkBlue = Color(0xff140B0A);
final Color darkPurple = Color(0xff1F1311);
final Color violet = Color(0xff8C2F3C);
final Color lightViolet = Color(0xffB4505C);
final Color extraLightViolet = Color(0xffE6CF97);
final Color lightPink = Color(0xffD99A98);
final Color white = Color(0xffFFFFFF);
final Color shadow = Color(0xff0D0706);
final Color gray = Color(0xffB8A48A);
const Color gold1 = Color(0xFFC9A55C);
const Color gold2 = Color(0xFFE6CF97);
const Color gold3 = Color(0xFFF7EBC6);
const Color gold4 = Color(0xFFE6CF97);
const Color gold5 = Color(0xFFC9A55C);

final bgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [darkBlue, darkPurple],
);

final premiumGradient = LinearGradient(
  colors: [gold1, gold2, gold3, gold4, gold5],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

final bgGradientOpacity = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [darkBlue.withValues(alpha: 0.6), darkPurple.withValues(alpha: 0.6)],
);

final btnGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [violet, lightViolet],
);

final btnGradientWithOpacity = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [violet.withValues(alpha: 0.5), lightViolet.withValues(alpha: 0.5)],
);

final sendGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [lightPink, violet],
);
