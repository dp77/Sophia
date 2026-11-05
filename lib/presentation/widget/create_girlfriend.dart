import 'package:girlfriend/core/haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:girlfriend/core/colors.dart';

class CreateGirlfriend extends StatelessWidget {
  final GestureTapCallback onTap;
  const CreateGirlfriend({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: Haptics.wrap(onTap),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 13, 13, 13),
        margin: EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: btnGradient,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: white, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meet Your Perfect AI Match',
                  style: TextStyle(color: white, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width * 0.65,
                  child: Text(
                    'Craft a virtual friend that thinks, talks, and connects exactly how you want.',
                    style: TextStyle(color: white, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            SvgPicture.asset('assets/svg/plus.svg', height: 45, width: 45),
          ],
        ),
      ),
    );
  }
}
