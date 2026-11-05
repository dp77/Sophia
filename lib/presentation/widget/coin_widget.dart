import 'package:girlfriend/core/haptics.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:girlfriend/core/colors.dart';
import 'package:girlfriend/data/navigation_service.dart';
import 'package:girlfriend/presentation/view/screens/watch_earn_screen.dart';
import 'package:girlfriend/presentation/view_model/user_provider.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart';
import 'package:provider/provider.dart';

class CoinWidget extends StatelessWidget {
  const CoinWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Premium users don't need Watch & Earn, so the pill is display-only.
    final isPremiumUser = context.select<UserProvider, bool>((u) => u.isPremiumUser);
    return GestureDetector(
      onTap: Haptics.wrap(isPremiumUser
          ? null
          : () => NavigationService.navigateToScreen(context, const WatchEarnScreen())),
      child: Container(
        height: 26,
        padding: const EdgeInsets.only(right: 10, left: 8),
        decoration: BoxDecoration(
          border: GradientBoxBorder(gradient: btnGradient, width: 1.2),
          borderRadius: BorderRadius.circular(30),
          color: white.withValues(alpha: 0.1),
        ),
        child: Row(
          spacing: 6,
          children: [
            Container(
              height: 14,
              width: 14,
              padding: const EdgeInsets.only(top: 1),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: 10,
                      width: 10,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        boxShadow: [
                          BoxShadow(
                            color: white,
                            blurRadius: 12,
                            spreadRadius: 0.2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: pi * 2.2,
                    child: SvgPicture.asset(
                      'assets/svg/diamond.svg',
                      height: 14,
                      width: 14,
                    ),
                  ),
                ],
              ),
            ),
            Selector<UserProvider, int>(
              selector: (p0, userProvider) => userProvider.credits,
              builder: (context, credits, _) {
                return Text(
                  credits.toString(),
                  style: TextStyle(
                    color: white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
