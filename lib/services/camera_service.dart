import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class CameraService {
  CameraController? _cameraController;
  final ValueNotifier<List<Pose>> detectedPoses = ValueNotifier<List<Pose>>([]);
  PoseDetector? _poseDetector;
  bool _isProcessing = false;

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
      // Initialize pose detector
      _poseDetector = PoseDetector(
        options: PoseDetectorOptions(
          model: PoseDetectionModel.base,
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

      // Initialize camera controller
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      // Initialize camera
      await _cameraController!.initialize();

      // Start image stream
      await _cameraController!.startImageStream(_processCameraImage);

      if (kDebugMode) {
        print('Camera initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing camera: $e');
      }
      rethrow;
    }
  }

  // Process camera image
  Future<void> _processCameraImage(CameraImage image) async {
    // Skip if already processing or pose detector is null
    if (_isProcessing || _poseDetector == null) return;

    _isProcessing = true;

    try {
      // Convert camera image to InputImage
      final inputImage = _convertCameraImageToInputImage(image);

      if (inputImage != null) {
        // Process image with pose detector
        final poses = await _poseDetector!.processImage(inputImage);

        // Update detected poses
        detectedPoses.value = poses;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error processing camera image: $e');
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
  void dispose() {
    if (!kIsWeb) {
      _cameraController?.stopImageStream();
      _cameraController?.dispose();
      _poseDetector?.close();
    }
  }

  // Get camera controller
  CameraController? get cameraController => _cameraController;
}
