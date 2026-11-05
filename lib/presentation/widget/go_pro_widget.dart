import 'package:girlfriend/core/haptics.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../data/navigation_service.dart';
import '../view/screens/premium_screen.dart';

class GoProWidget extends StatelessWidget {
  const GoProWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: Haptics.wrap(() => NavigationService.navigateToScreenFromBottom(
        context,
        PremiumScreen(),
      )),
      child: Lottie.asset(
        'assets/lottie/pro_badge_gold.json',
        height: 35,
        fit: BoxFit.cover,
      ),
    );
  }
}
