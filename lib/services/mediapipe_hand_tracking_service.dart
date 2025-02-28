import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// This is a stub implementation of MediaPipeHandTrackingService.
/// The actual hand tracking is handled by HandTrackingService using ML Kit pose detection.
class MediaPipeHandTrackingService {
  // Value notifiers for hand position and debug info
  final ValueNotifier<Offset> handPosition = ValueNotifier<Offset>(Offset.zero);
  final ValueNotifier<String> debugInfo =
      ValueNotifier<String>('MediaPipe hand tracking not available');

  // Initialize MediaPipe hand tracking
  Future<void> initialize() async {
    debugInfo.value =
        'MediaPipe hand tracking not available, using ML Kit instead';
    if (kDebugMode) {
      print('MediaPipe hand tracking not available, using ML Kit instead');
    }
  }

  // Process camera image - stub implementation
  Future<void> processImage(CameraImage image, Size screenSize) async {
    // This method is not used, hand tracking is done via HandTrackingService
  }

  // Method to manually set hand position (used for web)
  void setHandPosition(double x, double y) {
    handPosition.value = Offset(x, y);
  }

  // Dispose resources
  void dispose() {
    // No resources to dispose
  }
}
