import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:girlfriend/core/colors.dart';

class LoadingIndicator extends StatelessWidget {
  final bool isLoading;
  const LoadingIndicator({super.key, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final Offset offset = isLoading ? Offset.zero : const Offset(0, -0.3);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isLoading ? 1.0 : 0.0,
      curve: Curves.easeInOut,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: offset,
        curve: Curves.easeInOut,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(100), color: Colors.white),
            margin: const EdgeInsets.only(top: 210),
            padding: const EdgeInsets.all(3),
            width: 62,
            height: 62,
            child: ExpressiveLoadingIndicator(color: lightViolet),
          ),
        ),
      ),
    );
  }
}
