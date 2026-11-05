import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/colors.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      width: double.infinity,
      decoration: BoxDecoration(gradient: bgGradient),
      child: child,
    );
  }
}

class PhotoBackground extends StatelessWidget {
  final Widget child;
  final String image;

  const PhotoBackground({super.key, required this.child, required this.image});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: MediaQuery.sizeOf(context).width,
          height: MediaQuery.sizeOf(context).height,
          margin: EdgeInsets.only(top: 40),
          child: Opacity(
            opacity: 0.5,
            child: CachedNetworkImage(
              imageUrl: image,
              alignment: Alignment.topCenter,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.person, color: Colors.white);
              },
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.3, 0.5, 0.6, 0.8, 1.0],
                colors: [
                  darkPurple,
                  darkPurple.withValues(alpha: 0.0),
                  Colors.transparent,
                  Colors.transparent,
                  darkPurple.withValues(alpha: 0.0),
                  darkPurple,
                ],
              ),
            ),
          ),
        ),

        child,
      ],
    );
  }
}
