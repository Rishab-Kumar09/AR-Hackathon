import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/game_model.dart';
import 'dart:math' as math;

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

    // If bubble is too small, don't render
    if (size < 5) {
      return const SizedBox.shrink();
    }

    // If bubble is popped, use its scale and opacity properties
    final displaySize = bubble.isPopped ? size * bubble.scale : size;
    // Ensure opacity is between 0.0 and 1.0
    final displayOpacity =
        bubble.isPopped ? math.max(0.0, math.min(1.0, bubble.opacity)) : 1.0;

    return Positioned(
      left: x - displaySize / 2,
      top: y - displaySize / 2,
      child: _buildBubble(size, displaySize, displayOpacity),
    );
  }

  Widget _buildBubble(double size, double displaySize, double opacity) {
    // If bubble is popped, show pop animation
    if (bubble.isPopped) {
      return _buildPoppedBubble(size, displaySize, opacity);
    }

    // Simplified bubble with minimal effects
    return Container(
      width: displaySize,
      height: displaySize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bubble.color.withOpacity(clampOpacity(0.7 * opacity)),
        gradient: RadialGradient(
          colors: [
            Colors.white.withOpacity(clampOpacity(0.8 * opacity)),
            bubble.color.withOpacity(clampOpacity(0.7 * opacity)),
          ],
          stops: const [0.0, 1.0],
          center: const Alignment(0.3, -0.3),
        ),
        // Removed box shadow for better performance
      ),
      child: Center(
        // Simplified content - just the points text
        child: Text(
          '${bubble.points}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: displaySize * 0.3,
            // Removed text shadows for better performance
          ),
        ),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .moveY(
          begin: -1, // Reduced movement amount
          end: 1,
          duration: 1500.ms,
          curve: Curves.easeInOut,
        )
        .animate()
        .fadeIn(duration: 300.ms, curve: Curves.easeOut);
  }

  Widget _buildPoppedBubble(double size, double displaySize, double opacity) {
    // Simplified pop effect
    return Container(
      width: displaySize,
      height: displaySize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(
          color: bubble.color.withOpacity(clampOpacity(opacity * 0.7)),
          width: 2,
        ),
      ),
      child: Center(
        child: Container(
          width: displaySize * 0.4,
          height: displaySize * 0.4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(clampOpacity(opacity * 0.8)),
          ),
        ),
      ),
    );
  }

  // Helper method to ensure opacity is between 0.0 and 1.0
  double clampOpacity(double value) {
    return math.max(0.0, math.min(1.0, value));
  }
}
