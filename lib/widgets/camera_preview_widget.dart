import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../services/camera_service.dart';

class CameraPreviewWidget extends StatelessWidget {
  final CameraService cameraService;
  final bool showPoseDetection;

  const CameraPreviewWidget({
    Key? key,
    required this.cameraService,
    this.showPoseDetection = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = cameraService.cameraController;

    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Get screen size
    final screenSize = MediaQuery.of(context).size;

    if (kDebugMode) {
      print('Camera aspect ratio: ${controller.value.aspectRatio}');
      print('Screen size: ${screenSize.width} x ${screenSize.height}');
    }

    // Calculate the size needed to cover the screen while maintaining aspect ratio
    final double cameraAspectRatio = controller.value.aspectRatio;
    final double screenAspectRatio = screenSize.width / screenSize.height;

    double width, height;
    if (screenAspectRatio > cameraAspectRatio) {
      // Screen is wider than camera feed
      width = screenSize.width;
      height = screenSize.width / cameraAspectRatio;
    } else {
      // Screen is taller than camera feed
      height = screenSize.height;
      width = screenSize.height * cameraAspectRatio;
    }

    return Container(
      color: Colors.black,
      width: screenSize.width,
      height: screenSize.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview that covers the entire screen
          ClipRect(
            child: OverflowBox(
              alignment: Alignment.center,
              maxWidth: width,
              maxHeight: height,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..scale(-1.0, 1.0, 1.0), // Flip horizontally with matrix
                child: CameraPreview(
                  controller,
                  // Set lower frame rate to avoid buffer queue issues
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
