import 'package:flutter/cupertino.dart';
import 'package:girlfriend/core/colors.dart';

class TagContainer extends StatelessWidget {
  final String text;
  const TagContainer({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 19,
      padding: EdgeInsets.symmetric(horizontal: 5),
      margin: EdgeInsets.only(right: 4),
      decoration: BoxDecoration(color: white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(30)),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(color: white, fontSize: 9, fontWeight: FontWeight.w500),
      ),
    );
  }
}
