import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
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

    // Calculate scale to fill the screen while maintaining aspect ratio
    final scale = _getScale(controller, screenSize);

    return Transform.scale(
      scale: scale,
      alignment: Alignment.center,
      child: CameraPreview(controller),
    );
  }

  // Calculate scale to fill the screen while maintaining aspect ratio
  double _getScale(CameraController controller, Size screenSize) {
    final previewSize = controller.value.previewSize!;

    // Calculate aspect ratios
    final screenAspectRatio = screenSize.width / screenSize.height;
    final previewAspectRatio = previewSize.width / previewSize.height;

    // Calculate scale based on aspect ratios
    double scale;

    if (screenAspectRatio > previewAspectRatio) {
      // Screen is wider than preview, scale to match width
      scale = screenSize.width / previewSize.height;
    } else {
      // Screen is taller than preview, scale to match height
      scale = screenSize.height / previewSize.width;
    }

    return scale;
  }
}
