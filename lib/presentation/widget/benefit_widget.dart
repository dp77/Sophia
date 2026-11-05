import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:girlfriend/core/colors.dart';

class BenefitWidget extends StatelessWidget {
  final String benefit;
  const BenefitWidget({super.key, required this.benefit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        spacing: 10,
        children: [
          SizedBox(width: 30),
          SvgPicture.asset('assets/svg/proStar.svg', height: 20, width: 20),
          Text(
            benefit,
            style: TextStyle(color: white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
