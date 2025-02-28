import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class HandTrackingService {
  // Value notifiers for hand position and debug info
  final ValueNotifier<Offset> handPosition = ValueNotifier<Offset>(Offset.zero);
  final ValueNotifier<String> debugInfo =
      ValueNotifier<String>('Initializing hand tracking...');

  // Tracking variables for improved performance
  Offset? _lastValidPosition;
  Offset? _secondLastPosition;
  DateTime _lastUpdateTime = DateTime.now();
  int _invalidPositionCount = 0;
  final int _maxInvalidPositions = 1; // Keep low for responsiveness

  // Velocity tracking for prediction
  Offset _velocity = Offset.zero;

  // Adaptive smoothing parameters
  double _adaptiveSmoothingFactor = 0.3; // Start with moderate smoothing
  final double _minSmoothingFactor = 0.1; // Minimum smoothing (more responsive)
  final double _maxSmoothingFactor = 0.5; // Maximum smoothing (more stable)

  // Performance optimization
  int _debugUpdateCounter = 0;
  final int _debugUpdateInterval = 10; // Update debug info less frequently

  // Process detected poses to track hand position
  void processPoses(List<Pose> poses, Size screenSize) {
    if (kIsWeb) {
      // On web, we use mouse position instead of pose detection
      return;
    }

    // Calculate time delta for velocity calculations
    final now = DateTime.now();
    final deltaTimeMs = now.difference(_lastUpdateTime).inMilliseconds;
    final deltaTime = deltaTimeMs / 1000.0; // Convert to seconds
    _lastUpdateTime = now;

    // If no poses detected, use prediction based on velocity
    if (poses.isEmpty) {
      if (_lastValidPosition != null && deltaTime > 0 && deltaTime < 0.1) {
        // Predict position based on velocity
        final predictedPosition = Offset(
            _lastValidPosition!.dx + (_velocity.dx * deltaTime),
            _lastValidPosition!.dy + (_velocity.dy * deltaTime));

        // Clamp predicted position to valid range
        final clampedPosition = Offset(predictedPosition.dx.clamp(0.0, 1.0),
            predictedPosition.dy.clamp(0.0, 1.0));

        // Use prediction with reduced confidence
        handPosition.value = clampedPosition;
        _adaptiveSmoothingFactor =
            (_adaptiveSmoothingFactor + _maxSmoothingFactor) /
                2; // Increase smoothing
      }

      _handleInvalidPosition('No poses detected');
      return;
    }

    // Get the first detected pose
    final pose = poses.first;

    // Try to get hand landmarks in order of preference
    PoseLandmark? landmark = _getBestHandLandmark(pose);

    // If no hand landmarks are available, use prediction
    if (landmark == null) {
      if (_lastValidPosition != null && deltaTime > 0 && deltaTime < 0.1) {
        // Use prediction as above
        final predictedPosition = Offset(
            _lastValidPosition!.dx + (_velocity.dx * deltaTime),
            _lastValidPosition!.dy + (_velocity.dy * deltaTime));

        final clampedPosition = Offset(predictedPosition.dx.clamp(0.0, 1.0),
            predictedPosition.dy.clamp(0.0, 1.0));

        handPosition.value = clampedPosition;
        _adaptiveSmoothingFactor =
            (_adaptiveSmoothingFactor + _maxSmoothingFactor) /
                2; // Increase smoothing
      }

      _handleInvalidPosition('No hand landmarks detected');
      return;
    }

    // Convert landmark position to screen coordinates
    final x = landmark.x;
    final y = landmark.y;

    // Validate position
    if (!_isValidPosition(x, y, screenSize)) {
      _handleInvalidPosition('Invalid position');
      return;
    }

    // Convert to normalized coordinates (0.0 to 1.0)
    final normalizedX = x / screenSize.width;
    final normalizedY = y / screenSize.height;

    // The camera preview is flipped horizontally
    final flippedX = 1.0 - normalizedX;

    // Create new raw position
    final rawPosition = Offset(flippedX, normalizedY);

    // Apply adaptive smoothing based on confidence and movement speed
    final double confidence = landmark.likelihood;

    // Calculate movement speed
    double movementSpeed = 0.0;
    if (_lastValidPosition != null) {
      movementSpeed = (rawPosition - _lastValidPosition!).distance;
    }

    // Adjust smoothing factor based on confidence and speed
    // Higher confidence and lower speed = less smoothing (more responsive)
    // Lower confidence and higher speed = more smoothing (more stable)
    if (confidence > 0.7 && movementSpeed < 0.05) {
      // High confidence, slow movement - reduce smoothing for responsiveness
      _adaptiveSmoothingFactor = _minSmoothingFactor;
    } else if (confidence < 0.3 || movementSpeed > 0.1) {
      // Low confidence or fast movement - increase smoothing for stability
      _adaptiveSmoothingFactor = _maxSmoothingFactor;
    } else {
      // Moderate case - use middle value
      _adaptiveSmoothingFactor =
          (_minSmoothingFactor + _maxSmoothingFactor) / 2;
    }

    // Apply smoothing
    Offset smoothedPosition;
    if (_lastValidPosition != null) {
      smoothedPosition = Offset(
          _lastValidPosition!.dx * _adaptiveSmoothingFactor +
              rawPosition.dx * (1 - _adaptiveSmoothingFactor),
          _lastValidPosition!.dy * _adaptiveSmoothingFactor +
              rawPosition.dy * (1 - _adaptiveSmoothingFactor));
    } else {
      smoothedPosition = rawPosition;
    }

    // Calculate velocity for prediction (pixels per second)
    if (_lastValidPosition != null && deltaTime > 0) {
      final instantVelocity = Offset(
          (smoothedPosition.dx - _lastValidPosition!.dx) / deltaTime,
          (smoothedPosition.dy - _lastValidPosition!.dy) / deltaTime);

      // Smooth velocity changes too
      _velocity = Offset(_velocity.dx * 0.7 + instantVelocity.dx * 0.3,
          _velocity.dy * 0.7 + instantVelocity.dy * 0.3);
    }

    // Store positions for next calculation
    _secondLastPosition = _lastValidPosition;
    _lastValidPosition = smoothedPosition;

    // Update hand position
    handPosition.value = smoothedPosition;
    _invalidPositionCount = 0;

    // Update debug info less frequently to reduce overhead
    _debugUpdateCounter++;
    if (kDebugMode && _debugUpdateCounter >= _debugUpdateInterval) {
      _debugUpdateCounter = 0;
      debugInfo.value =
          'Hand: (${smoothedPosition.dx.toStringAsFixed(2)}, ${smoothedPosition.dy.toStringAsFixed(2)}) ' +
              'Conf: ${confidence.toStringAsFixed(2)} ' +
              'Smooth: ${_adaptiveSmoothingFactor.toStringAsFixed(2)}';
    }
  }

  // Get the best available hand landmark
  PoseLandmark? _getBestHandLandmark(Pose pose) {
    // List of landmarks to try in order of preference
    final landmarkTypes = [
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.rightIndex,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.leftIndex,
      // Add more fallback options for better tracking
      PoseLandmarkType.rightThumb,
      PoseLandmarkType.leftThumb,
      PoseLandmarkType.rightPinky,
      PoseLandmarkType.leftPinky,
    ];

    // Try each landmark type
    for (final landmarkType in landmarkTypes) {
      final landmark = pose.landmarks[landmarkType];
      if (landmark != null && _isLandmarkVisible(landmark)) {
        return landmark;
      }
    }

    return null;
  }

  // Check if landmark is visible (has reasonable confidence)
  bool _isLandmarkVisible(PoseLandmark landmark) {
    // Even lower threshold for better responsiveness
    return landmark.likelihood > 0.05 && landmark.x >= 0 && landmark.y >= 0;
  }

  // Validate position
  bool _isValidPosition(double x, double y, Size screenSize) {
    // More permissive bounds check to avoid losing tracking
    final margin = 150.0; // Increased margin
    return x >= -margin &&
        x <= screenSize.width + margin &&
        y >= -margin &&
        y <= screenSize.height + margin;
  }

  // Handle invalid position
  void _handleInvalidPosition(String reason) {
    _invalidPositionCount++;

    // If we've had too many invalid positions in a row, use prediction
    if (_invalidPositionCount > _maxInvalidPositions) {
      // If we have a last valid position and velocity, use prediction
      if (_lastValidPosition != null && _velocity != Offset.zero) {
        final now = DateTime.now();
        final deltaTime =
            now.difference(_lastUpdateTime).inMilliseconds / 1000.0;

        if (deltaTime > 0 && deltaTime < 0.2) {
          // Only predict for short gaps
          final predictedPosition = Offset(
              _lastValidPosition!.dx + (_velocity.dx * deltaTime),
              _lastValidPosition!.dy + (_velocity.dy * deltaTime));

          // Clamp to valid range
          final clampedPosition = Offset(predictedPosition.dx.clamp(0.0, 1.0),
              predictedPosition.dy.clamp(0.0, 1.0));

          handPosition.value = clampedPosition;
        } else if (_lastValidPosition != null) {
          // Just use last position if time gap is too large
          handPosition.value = _lastValidPosition!;
        }
      }
    }

    // Update debug info less frequently
    if (kDebugMode && _debugUpdateCounter >= _debugUpdateInterval) {
      _debugUpdateCounter = 0;
      debugInfo.value = 'Invalid position: $reason';
    }
  }

  // Method to manually set hand position (used for web)
  void setHandPosition(double x, double y) {
    final now = DateTime.now();
    final deltaTime = now.difference(_lastUpdateTime).inMilliseconds / 1000.0;
    _lastUpdateTime = now;

    final newPosition = Offset(x, y);

    // Calculate velocity for web too
    if (_lastValidPosition != null && deltaTime > 0) {
      final instantVelocity = Offset(
          (newPosition.dx - _lastValidPosition!.dx) / deltaTime,
          (newPosition.dy - _lastValidPosition!.dy) / deltaTime);

      // Smooth velocity changes
      _velocity = Offset(_velocity.dx * 0.7 + instantVelocity.dx * 0.3,
          _velocity.dy * 0.7 + instantVelocity.dy * 0.3);
    }

    _secondLastPosition = _lastValidPosition;
    _lastValidPosition = newPosition;
    handPosition.value = newPosition;
    _invalidPositionCount = 0;
  }

  // Reset tracking state
  void reset() {
    _lastValidPosition = null;
    _secondLastPosition = null;
    _velocity = Offset.zero;
    _invalidPositionCount = 0;
    _adaptiveSmoothingFactor = 0.3;
  }
}
