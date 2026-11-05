import 'package:girlfriend/core/haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:girlfriend/core/colors.dart';
import 'package:gradient_borders/gradient_borders.dart';

class ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? image;

  const ProfileMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.image,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: Haptics.wrap(onTap),
      child: Container(
        padding: const EdgeInsets.all(10),
        margin: EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: darkPurple.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(50),
          border: GradientBoxBorder(
            gradient: LinearGradient(
              colors: [white.withValues(alpha: 0.5), extraLightViolet.withValues(alpha: 0.5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(gradient: btnGradient, borderRadius: BorderRadius.circular(50)),
              child: Center(
                child: image != null
                    ? SvgPicture.asset('assets/svg/$image.svg', height: 24, width: 24)
                    : Icon(icon, color: white, size: 24),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: gray, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            if (title != 'App Information') ...[
              Icon(Icons.chevron_right_rounded, color: extraLightViolet.withValues(alpha: 0.85), size: 24),
            ],
          ],
        ),
      ),
    );
  }
}
