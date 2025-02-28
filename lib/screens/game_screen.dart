import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/game_model.dart';
import '../services/camera_service.dart';
import '../services/hand_tracking_service.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/bubble_widget.dart';
import 'dart:async';

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

  // Performance optimization variables
  DateTime _lastFrameTime = DateTime.now();
  final ValueNotifier<double> _fps = ValueNotifier<double>(0);
  final ValueNotifier<Offset> _handPositionForUI =
      ValueNotifier<Offset>(Offset.zero);

  // Reduce UI update frequency
  int _uiUpdateCounter = 0;
  final int _uiUpdateInterval =
      1; // Update UI every frame for better responsiveness

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Enable wakelock to prevent screen from sleeping
    WakelockPlus.enable();

    // Check if running on web platform
    _isWebPlatform = kIsWeb;

    // Initialize hand tracking services
    _handTrackingService = HandTrackingService();

    if (!_isWebPlatform) {
      _initializeCamera();
    } else {
      // For web, we'll use mouse position instead of camera
      setState(() {
        _isCameraInitialized = true; // Skip camera initialization
      });
    }

    // Start FPS counter with reduced frequency
    _startFpsCounter();
  }

  // Start FPS counter
  void _startFpsCounter() {
    // Update FPS every 2 seconds instead of every second
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Calculate FPS based on time since last frame
      final now = DateTime.now();
      final elapsed = now.difference(_lastFrameTime).inMilliseconds;
      if (elapsed > 0) {
        _fps.value = 1000 / elapsed;
      }
    });
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
        if (!mounted) return;

        final poses = _cameraService.detectedPoses.value;
        final screenSize = MediaQuery.of(context).size;

        // Update last frame time for FPS calculation
        _lastFrameTime = DateTime.now();

        // Use ML Kit pose detection
        _handTrackingService.processPoses(poses, screenSize);

        // Update UI more frequently for better responsiveness
        _handPositionForUI.value = _handTrackingService.handPosition.value;
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
      if (!mounted) return;

      final gameModel = Provider.of<GameModel>(context, listen: false);
      final handPosition = _handTrackingService.handPosition.value;

      // Check for bubble pops on every frame
      gameModel.checkBubblePops(handPosition.dx, handPosition.dy);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused) &&
        mounted) {
      // Stop game and release camera resources when app is inactive or paused
      Provider.of<GameModel>(context, listen: false).stopGame();

      // Release camera resources to prevent buffer queue issues
      if (!_isWebPlatform && _isCameraInitialized) {
        _cameraService.dispose();
      }

      // Disable wakelock when app is inactive
      WakelockPlus.disable();
    } else if (state == AppLifecycleState.resumed && mounted) {
      // Re-initialize camera when app is resumed
      if (!_isWebPlatform) {
        _initializeCamera();
      }

      // Re-enable wakelock when app is resumed
      WakelockPlus.enable();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // Properly dispose camera resources
    if (!_isWebPlatform && _isCameraInitialized) {
      _cameraService.dispose();
    }

    // Disable wakelock when screen is disposed
    WakelockPlus.disable();
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
        _handTrackingService.setHandPosition(normalizedX, normalizedY);
      },
      child: GestureDetector(
        onTapDown: (details) {
          // Update hand position based on tap position
          final screenSize = MediaQuery.of(context).size;
          final normalizedX = details.globalPosition.dx / screenSize.width;
          final normalizedY = details.globalPosition.dy / screenSize.height;
          _handTrackingService.setHandPosition(normalizedX, normalizedY);

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
                    showPoseDetection: false,
                  ),

            // Game UI overlay - simplified
            Stack(
              fit: StackFit.expand,
              children: [
                // Background overlay for better visibility
                Container(
                  color: Colors.black.withOpacity(0.1),
                ),

                // Bubbles
                ..._buildBubbles(gameModel),

                // Hand position indicator - optimized for responsiveness
                ValueListenableBuilder<Offset>(
                  valueListenable: _handPositionForUI,
                  builder: (context, handPosition, _) {
                    // Convert normalized coordinates to screen coordinates
                    final screenSize = MediaQuery.of(context).size;
                    final x = handPosition.dx * screenSize.width;
                    final y = handPosition.dy * screenSize.height;

                    // Skip rendering if position is invalid
                    if (x.isNaN ||
                        y.isNaN ||
                        x < -100 ||
                        y < -100 ||
                        x > screenSize.width + 100 ||
                        y > screenSize.height + 100) {
                      return const SizedBox.shrink();
                    }

                    return Positioned(
                      left: x - 15,
                      top: y - 15,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.3),
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

                // FPS counter (for debugging)
                if (kDebugMode)
                  Positioned(
                    top: 80,
                    left: 20,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _fps,
                      builder: (context, fps, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'FPS: ${fps.toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Hand tracking debug info
                if (!kIsWeb && gameModel.isPlaying)
                  Positioned(
                    top: 120,
                    left: 20,
                    child: ValueListenableBuilder<String>(
                      valueListenable: _handTrackingService.debugInfo,
                      builder: (context, debugInfo, _) {
                        // Determine if tracking is poor based on debug info
                        bool isPoorTracking = debugInfo.contains('Invalid') ||
                            debugInfo.contains('No hand') ||
                            debugInfo.contains('No poses');

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isPoorTracking
                                ? Colors.red.withOpacity(0.7)
                                : Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: isPoorTracking
                                ? Border.all(color: Colors.yellow, width: 1)
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hand Tracking: ${isPoorTracking ? "Poor" : "Good"}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isPoorTracking)
                                const Text(
                                  'Try adjusting your distance (1.5-2 feet)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              // Add debug info for bubbles
                              Text(
                                'Bubbles: ${gameModel.bubbles.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                // Game info overlay - simplified
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
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Score: ${gameModel.score}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // Time remaining
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Time: ${gameModel.timeRemaining}s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Game controls
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      // Optimal distance reminder - only show when not on web and when hand tracking is active
                      if (!kIsWeb && gameModel.isPlaying)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                  color: Colors.blue.shade400, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.straighten,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Optimal distance: 1.5-2 feet (45-60 cm)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: gameModel.isPlaying
                                ? gameModel.stopGame
                                : gameModel.startGame,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: gameModel.isPlaying
                                  ? Colors.red
                                  : Colors.blue,
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
                    ],
                  ),
                ),

                // Game over overlay - simplified
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
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Score: ${gameModel.score}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'High Score: ${gameModel.highScore}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Time\'s up!',
                            style: TextStyle(
                              color: Colors.yellow,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 30),
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
                          ),
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
