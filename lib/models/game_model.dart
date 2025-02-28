import 'dart:async';
import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class Bubble {
  final int id;
  final double size;
  final Color color;
  double x;
  double y;
  double velocityX;
  double velocityY;
  bool isPopped;
  int points;
  double opacity; // Add opacity for fade effect
  double scale; // Add scale for pop animation

  Bubble({
    required this.id,
    required this.size,
    required this.color,
    required this.x,
    required this.y,
    required this.velocityX,
    required this.velocityY,
    this.isPopped = false,
    required this.points,
    this.opacity = 1.0,
    this.scale = 1.0,
  });
}

class GameModel extends ChangeNotifier {
  // Game state
  bool _isPlaying = false;
  int _score = 0;
  int _highScore = 0;
  int _level = 1;
  int _timeRemaining = 60;
  List<Bubble> _bubbles = [];
  final Random _random = Random();
  Timer? _gameTimer;
  Timer? _bubbleTimer;
  Timer? _animationTimer;

  // Performance tracking
  DateTime _lastUpdateTime = DateTime.now();
  bool _needsUIUpdate = false;
  int _frameCount = 0;
  final int _uiUpdateInterval =
      1; // Changed from 3 to 1 for more frequent updates

  // Hand tracking
  Offset? _lastHandPosition;
  final List<Offset> _handTrail = [];
  final int _maxTrailLength = 2; // Reduced from 3 to 2 for faster response

  // Game settings
  final double _bubbleBaseSize = 0.1; // 10% of screen width
  final double _bubbleMinSize = 0.05; // 5% of screen width
  final double _bubbleMaxSize = 0.15; // 15% of screen width
  final double _popRadius =
      0.18; // Increased from 0.15 to 0.18 for easier popping
  final int _maxBubbles = 4; // Reduced from 6 to 4 for better performance
  final int _pointsPerBubble = 10;
  final int _pointsPerLevel = 100;
  final double _maxBubbleSpeed =
      0.005; // Reduced from 0.007 to 0.005 for slower bubbles

  // Getters
  bool get isPlaying => _isPlaying;
  int get score => _score;
  int get highScore => _highScore;
  int get level => _level;
  int get timeRemaining => _timeRemaining;
  List<Bubble> get bubbles => _bubbles;

  // Start the game
  void startGame() {
    if (_isPlaying) return;

    _isPlaying = true;
    _score = 0;
    _level = 1;
    _timeRemaining = 60;
    _bubbles = [];
    _handTrail.clear();
    _lastHandPosition = null;
    _needsUIUpdate = true;

    // Start game timer
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _timeRemaining--;
      if (_timeRemaining <= 0) {
        _endGame();
      }
      _needsUIUpdate = true;
      notifyListeners();
    });

    // Start bubble spawning timer
    _startBubbleTimer();

    // Start animation timer for smoother updates
    _startAnimationTimer();

    notifyListeners();
  }

  // Stop the game
  void stopGame() {
    if (!_isPlaying) return;

    _endGame();
  }

  // End the game
  void _endGame() {
    _isPlaying = false;
    _gameTimer?.cancel();
    _bubbleTimer?.cancel();
    _animationTimer?.cancel();

    // Update high score
    if (_score > _highScore) {
      _highScore = _score;
    }

    notifyListeners();
  }

  // Start bubble spawning timer
  void _startBubbleTimer() {
    // Cancel existing timer if any
    _bubbleTimer?.cancel();

    // Calculate spawn interval based on level (faster as level increases)
    final spawnInterval = max(
        400, 1500 - (_level * 100)); // Increased intervals for fewer bubbles

    // Start new timer with more frequent updates
    _bubbleTimer =
        Timer.periodic(Duration(milliseconds: spawnInterval), (timer) {
      if (!_isPlaying) return;

      // Spawn new bubbles if needed
      if (_bubbles.length < _maxBubbles) {
        _spawnBubble();
        if (kDebugMode) {
          print('Spawned new bubble. Total bubbles: ${_bubbles.length}');
        }
      }

      // Always update bubble positions
      _updateBubbles();

      // Force UI update every time
      notifyListeners();
    });

    if (kDebugMode) {
      print('Bubble timer started with interval: ${spawnInterval}ms');
    }
  }

  // Start animation timer for smoother updates
  void _startAnimationTimer() {
    // Cancel existing timer if any
    _animationTimer?.cancel();

    // Start new timer for animations (reduced from 60fps to 30fps)
    _animationTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (!_isPlaying) return;

      // Update bubble animations
      bool needsUpdate = false;

      for (final bubble in _bubbles) {
        if (bubble.isPopped) {
          // Update popping animation
          bubble.opacity = math.max(0.0, bubble.opacity - 0.1);
          bubble.scale += 0.15;
          needsUpdate = true;
        }
      }

      if (needsUpdate) {
        _needsUIUpdate = true;
        notifyListeners();
      }
    });
  }

  // Spawn a new bubble
  void _spawnBubble() {
    // Calculate bubble size (smaller bubbles are worth more points)
    final sizeMultiplier = _random.nextDouble();
    final size =
        _bubbleMinSize + sizeMultiplier * (_bubbleMaxSize - _bubbleMinSize);

    // Calculate points (smaller bubbles are worth more)
    final points = (_pointsPerBubble * (1 + (1 - sizeMultiplier) * 2)).round();

    // Generate random position
    final x = _random.nextDouble();
    final y = _random.nextDouble();

    // Generate random velocity (scaled by level)
    final speedMultiplier = 0.5 + (_level * 0.1);
    final maxSpeed = _maxBubbleSpeed * speedMultiplier;
    final velocityX = (_random.nextDouble() - 0.5) * maxSpeed;
    final velocityY = (_random.nextDouble() - 0.5) * maxSpeed;

    // Generate random color
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.teal,
    ];
    final color = colors[_random.nextInt(colors.length)];

    // Create new bubble
    final bubble = Bubble(
      id: DateTime.now().millisecondsSinceEpoch + _random.nextInt(1000),
      size: size,
      color: color,
      x: x,
      y: y,
      velocityX: velocityX,
      velocityY: velocityY,
      points: points,
    );

    // Add bubble to list
    _bubbles.add(bubble);
  }

  // Update bubble positions
  void _updateBubbles() {
    // Calculate delta time for smooth movement regardless of frame rate
    final now = DateTime.now();
    final deltaTime = now.difference(_lastUpdateTime).inMilliseconds /
        16.0; // Normalize to 60fps
    _lastUpdateTime = now;

    // Update bubble positions
    for (final bubble in _bubbles) {
      if (bubble.isPopped) continue;

      // Update position with delta time
      bubble.x += bubble.velocityX * deltaTime;
      bubble.y += bubble.velocityY * deltaTime;

      // Check if bubble has gone off-screen from left, right or bottom
      if (bubble.x < -0.2 || bubble.x > 1.2 || bubble.y > 1.2) {
        // Mark for removal
        bubble.isPopped = true;
        bubble.opacity = 0; // Make it invisible immediately
        continue;
      }

      // Bounce off the top of the screen
      if (bubble.y < 0.05) {
        bubble.y = 0.05;
        bubble.velocityY = bubble.velocityY.abs(); // Reverse direction
      }

      // Bounce off the sides if close to edge
      if (bubble.x < 0.05) {
        bubble.x = 0.05;
        bubble.velocityX = bubble.velocityX.abs(); // Reverse direction
      } else if (bubble.x > 0.95) {
        bubble.x = 0.95;
        bubble.velocityX = -bubble.velocityX.abs(); // Reverse direction
      }
    }

    // Remove popped bubbles after animation
    _bubbles.removeWhere((bubble) => bubble.isPopped && bubble.opacity <= 0);
  }

  // Check for bubble pops
  void checkBubblePops(double handX, double handY) {
    if (!_isPlaying) return;

    // Update hand trail
    final currentPosition = Offset(handX, handY);

    // Only add to trail if position has changed significantly
    // Reduced threshold for more responsive trail
    if (_lastHandPosition == null ||
        (currentPosition - _lastHandPosition!).distance > 0.002) {
      // Reduced from 0.005 to 0.002
      _handTrail.add(currentPosition);
      _lastHandPosition = currentPosition;

      // Keep trail at max length
      if (_handTrail.length > _maxTrailLength) {
        _handTrail.removeAt(0);
      }
    }

    if (kDebugMode) {
      print('Checking bubble pops at ($handX, $handY)');
    }

    bool bubblePopped = false;

    // Check each bubble
    for (final bubble in _bubbles) {
      if (bubble.isPopped) continue;

      // Check direct hit with increased pop radius
      final directDistance =
          sqrt(pow(bubble.x - handX, 2) + pow(bubble.y - handY, 2));

      // Check if hand is close enough to pop the bubble
      if (directDistance < _popRadius + bubble.size / 2) {
        _popBubble(bubble);
        bubblePopped = true;
        continue;
      }

      // Check trail for swipe pops (if we have at least 2 points in the trail)
      if (_handTrail.length >= 2) {
        for (int i = 1; i < _handTrail.length; i++) {
          final start = _handTrail[i - 1];
          final end = _handTrail[i];

          // Check if bubble intersects with line segment
          if (_isPointNearLineSegment(Offset(bubble.x, bubble.y), start, end,
              _popRadius + bubble.size / 2)) {
            _popBubble(bubble);
            bubblePopped = true;
            break;
          }
        }
      }
    }

    if (bubblePopped) {
      notifyListeners();
    }
  }

  // Pop a bubble
  void _popBubble(Bubble bubble) {
    // Pop the bubble
    bubble.isPopped = true;

    // Add points
    _score += bubble.points;

    // Check for level up
    if (_score >= _level * _pointsPerLevel) {
      _levelUp();
    }

    if (kDebugMode) {
      print('Bubble popped! Score: $_score');
    }
  }

  // Check if a point is near a line segment
  bool _isPointNearLineSegment(
      Offset point, Offset lineStart, Offset lineEnd, double threshold) {
    // Calculate squared length of line segment
    final lengthSquared = (lineEnd - lineStart).distanceSquared;

    // If line segment is a point, just check distance to that point
    if (lengthSquared == 0) {
      return (point - lineStart).distance < threshold;
    }

    // Calculate projection of point onto line segment
    final t = max(
        0,
        min(
            1,
            ((point - lineStart).dx * (lineEnd - lineStart).dx +
                    (point - lineStart).dy * (lineEnd - lineStart).dy) /
                lengthSquared));

    // Calculate closest point on line segment
    final projection = lineStart + (lineEnd - lineStart) * t.toDouble();

    // Check distance from point to projection
    return (point - projection).distance < threshold;
  }

  // Level up
  void _levelUp() {
    _level++;

    // Restart bubble timer with new interval
    _startBubbleTimer();

    if (kDebugMode) {
      print('Level up! Level: $_level');
    }
  }
}
