import 'package:girlfriend/core/haptics.dart';
import 'dart:io';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:girlfriend/core/colors.dart';
import 'package:girlfriend/data/model/charcter_model.dart';
import 'package:girlfriend/data/navigation_service.dart';
import 'package:girlfriend/presentation/view/screens/chat_screen.dart';
import 'package:girlfriend/presentation/widget/tag_conatiner.dart';

class CharacterCard extends StatelessWidget {
  final CharacterModel character;

  const CharacterCard({super.key, required this.character});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: Haptics.wrap(() => NavigationService.navigateToScreen(
        context,
        ChatScreen(
          imageUrl: character.imageUrl,
          name: character.characterName,
          companionId: character.id,
        ),
      )),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: white.withValues(alpha: 0.2), width: 0.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: character.imageUrl,
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
                  return Container(
                    width: double.infinity,
                    color: Colors.white.withValues(alpha: 0.05),
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white38,
                        size: 28,
                      ),
                    ),
                  );
                },
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: ClipRRect(
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, 0.46, 1.0],
                        colors: [
                          shadow.withValues(alpha: 0),
                          shadow.withValues(alpha: 0.4),
                          shadow.withValues(alpha: 0.95),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${character.characterName}, ${character.age}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (Platform.isAndroid) ...[
                          SizedBox(height: 5),
                          SizedBox(
                            height: 19,
                            width: double.infinity,
                            child: ListView.builder(
                              itemCount: character.traits.length,
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) {
                                final e = character.traits[index];
                                return TagContainer(text: e);
                              },
                            ),
                          ),
                        ],
                        SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
