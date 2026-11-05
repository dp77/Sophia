import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:girlfriend/presentation/view_model/girlfriend_provider.dart';
import 'package:provider/provider.dart';
import '../../core/colors.dart';

class ProfileWidget extends StatelessWidget {
  final String gfId;
  final double size;
  final Color borderColor;
  final String? imageUrl;

  const ProfileWidget({
    super.key,
    required this.gfId,
    required this.size,
    required this.borderColor,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: white,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(40),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                alignment: Alignment.topCenter,
                fit: BoxFit.cover,
                progressIndicatorBuilder: (context, child, loadingProgress) {
                  return Container(
                    width: double.infinity,
                    color: Colors.white.withValues(alpha: 0.05),
                    child: Center(
                      child: ExpressiveLoadingIndicator(color: white),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.person, size: 40, color: gray);
                },
              )
            : context.watch<GirlfriendProvider>().getGirlfriendImageUrlById(
                    gfId,
                  ) !=
                  null
            ? CachedNetworkImage(
                imageUrl: context
                    .watch<GirlfriendProvider>()
                    .getGirlfriendImageUrlById(gfId)!,
                alignment: Alignment.topCenter,
                fit: BoxFit.cover,
                progressIndicatorBuilder: (context, child, loadingProgress) {
                  return Container(
                    width: double.infinity,
                    color: Colors.white.withValues(alpha: 0.05),
                    child: Center(
                      child: ExpressiveLoadingIndicator(color: white),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.person, size: 40, color: gray);
                },
              )
            : Center(
                child: Text(
                  context.watch<GirlfriendProvider>().getGirlfriendNameById(
                        gfId,
                      ) ??
                      gfId,
                  style: TextStyle(color: white, fontWeight: FontWeight.bold),
                ),
              ),
      ),
    );
  }
}
