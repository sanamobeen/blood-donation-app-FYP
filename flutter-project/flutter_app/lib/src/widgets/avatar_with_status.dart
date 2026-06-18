import 'package:flutter/material.dart';

/// An avatar widget with an online status indicator following the LifeDrop design system.
///
/// Features:
/// - Circular avatar
/// - Green online dot positioned at bottom-right
/// - Configurable size and online status
class AvatarWithStatus extends StatelessWidget {
  const AvatarWithStatus({
    super.key,
    required this.imageUrl,
    required this.isOnline,
    this.size = 48,
    this.radius,
  });

  final String imageUrl;
  final bool isOnline;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = radius ?? size / 2;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          CircleAvatar(
            radius: effectiveRadius,
            backgroundImage: NetworkImage(imageUrl),
            backgroundColor: const Color(0xFFFFD6CC),
            onBackgroundImageError: (exception, stackTrace) {
              // Handle image load error
            },
            child: imageUrl.isEmpty
                ? Icon(
                    Icons.person,
                    size: size * 0.5,
                    color: const Color(0xFFD62828),
                  )
                : null,
          ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
