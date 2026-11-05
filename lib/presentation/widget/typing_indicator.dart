import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer_animation/shimmer_animation.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator();

  @override
  TypingIndicatorState createState() => TypingIndicatorState();
}

class TypingIndicatorState extends State<TypingIndicator> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Shimmer(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
              ),
              child: Lottie.asset('assets/lottie/Typing.json', height: 35),
            ),
          ),
        ),
      ],
    );
  }
}
