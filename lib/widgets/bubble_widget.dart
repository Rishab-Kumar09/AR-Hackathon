import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/game_model.dart';

class BubbleWidget extends StatelessWidget {
  final Bubble bubble;

  const BubbleWidget({
    Key? key,
    required this.bubble,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get screen size
    final screenSize = MediaQuery.of(context).size;

    // Calculate bubble position in screen coordinates
    final x = bubble.x * screenSize.width;
    final y = bubble.y * screenSize.height;

    // Calculate visual size based on bubble size
    final baseSize = bubble.size * screenSize.width;
    final size = baseSize;

    // If bubble is popped or too small, don't render
    if (size < 5 || bubble.isPopped) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: x - size / 2,
      top: y - size / 2,
      child: _buildBubble(size),
    );
  }

  Widget _buildBubble(double size) {
    // If bubble is popped, show pop animation
    if (bubble.isPopped) {
      return _buildPoppedBubble(size);
    }

    // Regular bubble
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bubble.color.withOpacity(0.7),
        gradient: RadialGradient(
          colors: [
            bubble.color.withOpacity(0.5),
            bubble.color.withOpacity(0.3),
          ],
          stops: const [0.2, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: bubble.color.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Bubble shine effect
          Positioned(
            top: size * 0.2,
            left: size * 0.2,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ),

          // Bubble points
          Center(
            child: Text(
              '${bubble.points}',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.3,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildPoppedBubble(double size) {
    return Container(
      width: size * 1.5,
      height: size * 1.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(
          color: bubble.color.withOpacity(0.5),
          width: 2,
        ),
      ),
    )
        .animate()
        .scale(
          duration: 300.ms,
          curve: Curves.easeOut,
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.5, 1.5),
        )
        .fadeOut(
          duration: 300.ms,
          curve: Curves.easeOut,
        );
  }
}
