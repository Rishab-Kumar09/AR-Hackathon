import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/foundation.dart';
import '../models/game_model.dart';
import '../services/camera_service.dart';
import '../services/hand_tracking_service.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/bubble_widget.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late CameraService _cameraService;
  late HandTrackingService _handTrackingService;
  bool _isCameraInitialized = false;
  bool _isWebPlatform = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Check if running on web platform
    _isWebPlatform = kIsWeb;

    // Initialize hand tracking service
    _handTrackingService = HandTrackingService();

    if (!_isWebPlatform) {
      _initializeCamera();
    } else {
      // For web, we'll use mouse position instead of camera
      setState(() {
        _isCameraInitialized = true; // Skip camera initialization
      });
    }
  }

  Future<void> _initializeCamera() async {
    // Initialize camera service
    _cameraService = CameraService();
    try {
      await _cameraService.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }

      // Listen to pose updates and track hands
      _cameraService.detectedPoses.addListener(() {
        final poses = _cameraService.detectedPoses.value;
        if (mounted) {
          final screenSize = MediaQuery.of(context).size;
          _handTrackingService.processPoses(poses, screenSize);
        }
      });
    } catch (e) {
      // Handle camera initialization error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize camera: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Listen to hand position updates and check for bubble pops
    _handTrackingService.handPosition.addListener(() {
      if (mounted) {
        final gameModel = Provider.of<GameModel>(context, listen: false);
        final handPosition = _handTrackingService.handPosition.value;
        gameModel.checkBubblePops(handPosition.dx, handPosition.dy);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes
    if (state == AppLifecycleState.inactive && mounted) {
      Provider.of<GameModel>(context, listen: false).stopGame();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_isWebPlatform && _isCameraInitialized) {
      _cameraService.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: _isWebPlatform ? _buildWebGameScreen() : _buildGameScreen(),
    );
  }

  Widget _buildWebGameScreen() {
    return MouseRegion(
      onHover: (event) {
        // Update hand position based on mouse position
        final screenSize = MediaQuery.of(context).size;
        final normalizedX = event.position.dx / screenSize.width;
        final normalizedY = event.position.dy / screenSize.height;
        _handTrackingService.handPosition.value =
            Offset(normalizedX, normalizedY);
        _handTrackingService.debugInfo.value =
            "Mouse: (${normalizedX.toStringAsFixed(2)}, ${normalizedY.toStringAsFixed(2)})";
      },
      child: GestureDetector(
        onTapDown: (details) {
          // Update hand position based on tap position
          final screenSize = MediaQuery.of(context).size;
          final normalizedX = details.globalPosition.dx / screenSize.width;
          final normalizedY = details.globalPosition.dy / screenSize.height;
          _handTrackingService.handPosition.value =
              Offset(normalizedX, normalizedY);

          // Simulate a "pop" action
          final gameModel = Provider.of<GameModel>(context, listen: false);
          gameModel.checkBubblePops(normalizedX, normalizedY);
        },
        child: _buildGameScreen(),
      ),
    );
  }

  Widget _buildGameScreen() {
    return Consumer<GameModel>(
      builder: (context, gameModel, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview or background for web
            _isWebPlatform
                ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.blue.shade900,
                          Colors.purple.shade900,
                        ],
                      ),
                    ),
                  )
                : CameraPreviewWidget(
                    cameraService: _cameraService,
                    showPoseDetection: true,
                  ),

            // Game UI overlay
            Stack(
              fit: StackFit.expand,
              children: [
                // Background overlay for better visibility
                Container(
                  color: Colors.black.withOpacity(0.1),
                ),

                // Bubbles
                ..._buildBubbles(gameModel),

                // Hand position indicator
                ValueListenableBuilder<Offset>(
                  valueListenable: _handTrackingService.handPosition,
                  builder: (context, handPosition, _) {
                    // Convert normalized coordinates to screen coordinates
                    final screenSize = MediaQuery.of(context).size;
                    final x = handPosition.dx * screenSize.width;
                    final y = handPosition.dy * screenSize.height;

                    return Positioned(
                      left: x - 15,
                      top: y - 15,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.5),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Debug info overlay
                Positioned(
                  top: 100,
                  left: 20,
                  right: 20,
                  child: ValueListenableBuilder<String>(
                    valueListenable: _handTrackingService.debugInfo,
                    builder: (context, debugText, _) {
                      return Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.black.withOpacity(0.5),
                        child: Text(
                          _isWebPlatform
                              ? "Web Mode: Use mouse to pop bubbles\n$debugText"
                              : debugText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Game info overlay
                Positioned(
                  top: 40,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Score
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Score: ${gameModel.score}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // Level
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Level: ${gameModel.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // Time
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: gameModel.timeRemaining < 10
                              ? Colors.red.withOpacity(0.7)
                              : Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.timer,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${gameModel.timeRemaining}s',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Lives
                Positioned(
                  top: 90,
                  right: 20,
                  child: Row(
                    children: List.generate(
                      3,
                      (index) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.favorite,
                          color: index < gameModel.lives
                              ? Colors.red
                              : Colors.grey,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),

                // Game controls
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: gameModel.isPlaying
                            ? gameModel.stopGame
                            : gameModel.startGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              gameModel.isPlaying ? Colors.red : Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          gameModel.isPlaying ? 'Stop Game' : 'Start Game',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Game over overlay
                if (!gameModel.isPlaying && gameModel.score > 0)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Game Over',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ).animate().fadeIn(duration: 500.ms),
                          const SizedBox(height: 20),
                          Text(
                            'Score: ${gameModel.score}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                            ),
                          ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
                          const SizedBox(height: 10),
                          Text(
                            'High Score: ${gameModel.highScore}',
                            style: const TextStyle(
                              color: Colors.yellow,
                              fontSize: 18,
                            ),
                          ).animate().fadeIn(delay: 600.ms, duration: 500.ms),
                          const SizedBox(height: 40),
                          ElevatedButton(
                            onPressed: gameModel.startGame,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Play Again',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ).animate().fadeIn(delay: 900.ms, duration: 500.ms),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  // Build all bubbles
  List<Widget> _buildBubbles(GameModel gameModel) {
    return gameModel.bubbles
        .map((bubble) => BubbleWidget(bubble: bubble))
        .toList();
  }
}
