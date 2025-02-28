import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class HandTrackingService {
  // Value notifiers for hand position and debug info
  final ValueNotifier<Offset> handPosition = ValueNotifier<Offset>(Offset.zero);
  final ValueNotifier<String> debugInfo =
      ValueNotifier<String>('Initializing hand tracking...');

  // Process detected poses to track hand position
  void processPoses(List<Pose> poses, Size screenSize) {
    if (kIsWeb) {
      // On web, we use mouse position instead of pose detection
      // This method will still be called but we'll ignore the poses
      debugInfo.value =
          'Web mode: Using mouse position instead of pose detection';
      return;
    }

    if (poses.isEmpty) {
      debugInfo.value = 'No poses detected';
      return;
    }

    // Get the first detected pose
    final pose = poses.first;

    // Try to get right wrist landmark first
    PoseLandmark? landmark = pose.landmarks[PoseLandmarkType.rightWrist];

    // If right wrist is not available, try other landmarks
    if (landmark == null || !_isLandmarkVisible(landmark)) {
      landmark = pose.landmarks[PoseLandmarkType.rightIndex];
    }

    if (landmark == null || !_isLandmarkVisible(landmark)) {
      landmark = pose.landmarks[PoseLandmarkType.rightPinky];
    }

    // If right hand landmarks are not available, try left hand
    if (landmark == null || !_isLandmarkVisible(landmark)) {
      landmark = pose.landmarks[PoseLandmarkType.leftWrist];
    }

    if (landmark == null || !_isLandmarkVisible(landmark)) {
      landmark = pose.landmarks[PoseLandmarkType.leftIndex];
    }

    if (landmark == null || !_isLandmarkVisible(landmark)) {
      landmark = pose.landmarks[PoseLandmarkType.leftPinky];
    }

    // If no hand landmarks are available
    if (landmark == null || !_isLandmarkVisible(landmark)) {
      debugInfo.value = 'No hand landmarks detected';
      return;
    }

    // Convert landmark position to normalized coordinates (0.0 to 1.0)
    final normalizedX = landmark.x / screenSize.width;
    final normalizedY = landmark.y / screenSize.height;

    // Update hand position
    handPosition.value = Offset(normalizedX, normalizedY);

    // Update debug info
    debugInfo.value =
        'Hand position: (${normalizedX.toStringAsFixed(2)}, ${normalizedY.toStringAsFixed(2)})';
  }

  // Check if landmark is visible (has reasonable confidence)
  bool _isLandmarkVisible(PoseLandmark landmark) {
    // Consider landmark visible if likelihood is above threshold
    // and position is within reasonable bounds
    return landmark.likelihood > 0.5 && landmark.x >= 0 && landmark.y >= 0;
  }

  // Method to manually set hand position (used for web)
  void setHandPosition(double x, double y) {
    if (kIsWeb) {
      handPosition.value = Offset(x, y);
      debugInfo.value =
          'Web hand position: (${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
    }
  }
}
