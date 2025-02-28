import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class CameraService {
  CameraController? _cameraController;
  final ValueNotifier<List<Pose>> detectedPoses = ValueNotifier<List<Pose>>([]);
  PoseDetector? _poseDetector;
  bool _isProcessing = false;
  int _frameSkipCount = 0;
  final int _frameSkipTarget =
      2; // Skip every 2 frames to reduce buffer pressure

  // Store the last camera image for TFLite processing
  CameraImage? _lastCameraImage;

  // Flag to track if camera is active
  bool _isActive = false;

  // Initialize camera
  Future<void> initialize() async {
    // Skip initialization on web platform
    if (kIsWeb) {
      if (kDebugMode) {
        print('Camera not supported on web platform');
      }
      return;
    }

    try {
      // Clean up any existing resources
      await dispose();

      // Initialize pose detector with lighter model for better performance
      _poseDetector = PoseDetector(
        options: PoseDetectorOptions(
          model:
              PoseDetectionModel.base, // Use base model for better performance
          mode: PoseDetectionMode.stream,
        ),
      );

      // Get available cameras
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        if (kDebugMode) {
          print('No cameras available');
        }
        return;
      }

      // Use front camera
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      if (kDebugMode) {
        print(
            'Using camera: ${frontCamera.name} with orientation: ${frontCamera.sensorOrientation}');
      }

      // Initialize camera controller with medium resolution for better balance
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium, // Medium resolution for better tracking
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      // Initialize camera
      await _cameraController!.initialize();

      _isActive = true;

      // Start image stream with frame skipping to reduce buffer pressure
      await _cameraController!.startImageStream(_processCameraImage);

      if (kDebugMode) {
        print('Camera initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing camera: $e');
      }
      // Don't rethrow - just log the error and continue
    }
  }

  // Process camera image for pose detection
  Future<void> _processCameraImage(CameraImage image) async {
    // Skip if already processing an image or camera is not active
    if (_isProcessing || !_isActive) return;

    // Implement frame skipping to reduce buffer pressure
    if (_frameSkipCount < _frameSkipTarget) {
      _frameSkipCount++;
      return;
    }
    _frameSkipCount = 0;

    _isProcessing = true;
    _lastCameraImage = image;

    try {
      // Convert CameraImage to InputImage
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      // Process the image with ML Kit
      final poses = await _poseDetector!.processImage(inputImage);

      // Only update if still active
      if (_isActive) {
        // Update the detected poses
        detectedPoses.value = poses;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error processing image: $e');
      }
    } finally {
      _isProcessing = false;
    }
  }

  // Convert CameraImage to InputImage
  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    try {
      // Get camera rotation
      final camera = _cameraController!.description;
      final rotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation);

      if (rotation == null) return null;

      // Get image format
      final format = InputImageFormatValue.fromRawValue(image.format.raw);

      if (format == null) return null;

      // Create InputImage
      final inputImage = InputImage.fromBytes(
        bytes: _concatenatePlanes(image.planes),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      return inputImage;
    } catch (e) {
      if (kDebugMode) {
        print('Error converting camera image: $e');
      }
      return null;
    }
  }

  // Concatenate image planes
  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();

    for (final plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }

    return allBytes.done().buffer.asUint8List();
  }

  // Dispose resources
  Future<void> dispose() async {
    _isActive = false;

    // Stop image stream first to prevent buffer queue issues
    if (_cameraController?.value.isStreamingImages ?? false) {
      try {
        await _cameraController?.stopImageStream();
      } catch (e) {
        if (kDebugMode) {
          print('Error stopping image stream: $e');
        }
      }
    }

    // Dispose camera controller
    if (_cameraController != null) {
      try {
        await _cameraController?.dispose();
        _cameraController = null;
      } catch (e) {
        if (kDebugMode) {
          print('Error disposing camera controller: $e');
        }
      }
    }

    // Close pose detector
    try {
      await _poseDetector?.close();
      _poseDetector = null;
    } catch (e) {
      if (kDebugMode) {
        print('Error closing pose detector: $e');
      }
    }

    // Clear last camera image
    _lastCameraImage = null;

    if (kDebugMode) {
      print('Camera resources disposed');
    }
  }

  // Get camera controller
  CameraController? get cameraController => _cameraController;

  // Get last camera image
  CameraImage? get lastCameraImage => _lastCameraImage;

  // Check if camera is active
  bool get isActive => _isActive;
}
