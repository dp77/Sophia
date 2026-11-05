import 'package:girlfriend/core/haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NavbarWidget extends StatelessWidget {
  final String image;
  final bool isActive;
  final GestureTapCallback onTap;
  const NavbarWidget({
    super.key,
    required this.image,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: Haptics.wrap(onTap),
      child: Container(
        height: 55,
        width: 55,
        color: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: SvgPicture.asset(
                'assets/svg/$image.svg',
                height: image.contains('heart_edit') ? 28 : 24,
                width: image.contains('heart_edit') ? 28 : 24,
                fit: BoxFit.cover,
              ),
            ),
            if (isActive) ...[
              Align(
                alignment: Alignment.center,
                child: Container(
                  height: 10,
                  width: 10,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white,
                        blurRadius: 20,
                        spreadRadius: 4,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
