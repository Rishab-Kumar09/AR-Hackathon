import 'dart:async';
import 'dart:math';
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
  });
}

class GameModel extends ChangeNotifier {
  // Game state
  bool _isPlaying = false;
  int _score = 0;
  int _highScore = 0;
  int _level = 1;
  int _lives = 3;
  int _timeRemaining = 60;
  List<Bubble> _bubbles = [];
  final Random _random = Random();
  Timer? _gameTimer;
  Timer? _bubbleTimer;

  // Game settings
  final double _bubbleBaseSize = 0.1; // 10% of screen width
  final double _bubbleMinSize = 0.05; // 5% of screen width
  final double _bubbleMaxSize = 0.15; // 15% of screen width
  final double _popRadius = 0.08; // 8% of screen width
  final int _maxBubbles = 10;
  final int _pointsPerBubble = 10;
  final int _pointsPerLevel = 100;

  // Getters
  bool get isPlaying => _isPlaying;
  int get score => _score;
  int get highScore => _highScore;
  int get level => _level;
  int get lives => _lives;
  int get timeRemaining => _timeRemaining;
  List<Bubble> get bubbles => _bubbles;

  // Start the game
  void startGame() {
    if (_isPlaying) return;

    _isPlaying = true;
    _score = 0;
    _level = 1;
    _lives = 3;
    _timeRemaining = 60;
    _bubbles = [];

    // Start game timer
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _timeRemaining--;
      if (_timeRemaining <= 0 || _lives <= 0) {
        _endGame();
      }
      notifyListeners();
    });

    // Start bubble spawning timer
    _startBubbleTimer();

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
    final spawnInterval = max(200, 1000 - (_level * 100));

    // Start new timer
    _bubbleTimer =
        Timer.periodic(Duration(milliseconds: spawnInterval), (timer) {
      if (_bubbles.length < _maxBubbles) {
        _spawnBubble();
      }
      _updateBubbles();
      notifyListeners();
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

    // Generate random velocity
    final velocityX = (_random.nextDouble() - 0.5) * 0.01 * _level;
    final velocityY = (_random.nextDouble() - 0.5) * 0.01 * _level;

    // Generate random color
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
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
    // Update bubble positions
    for (final bubble in _bubbles) {
      if (bubble.isPopped) continue;

      // Update position
      bubble.x += bubble.velocityX;
      bubble.y += bubble.velocityY;

      // Bounce off edges
      if (bubble.x < 0 || bubble.x > 1) {
        bubble.velocityX *= -1;
        bubble.x = bubble.x < 0 ? 0 : 1;
      }

      if (bubble.y < 0 || bubble.y > 1) {
        bubble.velocityY *= -1;
        bubble.y = bubble.y < 0 ? 0 : 1;
      }
    }

    // Remove popped bubbles after animation
    _bubbles.removeWhere((bubble) => bubble.isPopped);
  }

  // Check for bubble pops
  void checkBubblePops(double handX, double handY) {
    if (!_isPlaying) return;

    if (kDebugMode) {
      print('Checking bubble pops at ($handX, $handY)');
    }

    bool bubblePopped = false;

    // Check each bubble
    for (final bubble in _bubbles) {
      if (bubble.isPopped) continue;

      // Calculate distance between hand and bubble
      final distance =
          sqrt(pow(bubble.x - handX, 2) + pow(bubble.y - handY, 2));

      // Check if hand is close enough to pop the bubble
      if (distance < _popRadius + bubble.size / 2) {
        // Pop the bubble
        bubble.isPopped = true;

        // Add points
        _score += bubble.points;

        // Check for level up
        if (_score >= _level * _pointsPerLevel) {
          _levelUp();
        }

        bubblePopped = true;

        if (kDebugMode) {
          print('Bubble popped! Score: $_score');
        }
      }
    }

    if (bubblePopped) {
      notifyListeners();
    }
  }

  // Level up
  void _levelUp() {
    _level++;
    _timeRemaining += 10; // Bonus time

    // Restart bubble timer with new interval
    _startBubbleTimer();

    if (kDebugMode) {
      print('Level up! Level: $_level');
    }
  }
}
