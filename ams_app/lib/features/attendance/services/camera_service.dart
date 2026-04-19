import 'dart:io';

import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _selectedIndex = 0;

  CameraController? get controller => _controller;
  CameraDescription? get activeCamera =>
      _cameras.isEmpty ? null : _cameras[_selectedIndex];
  bool get canSwitchCamera => _cameras.length > 1;

  Future<CameraController?> initialize() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      return null;
    }

    _selectedIndex = _preferredCameraIndex();
    await _createController(_cameras[_selectedIndex]);
    return _controller;
  }

  Future<void> switchCamera() async {
    if (!canSwitchCamera) {
      return;
    }

    _selectedIndex = (_selectedIndex + 1) % _cameras.length;
    await _createController(_cameras[_selectedIndex]);
  }

  Future<XFile> takePicture() async {
    final controller = _controller;
    if (controller == null) {
      throw StateError('Camera is not initialized.');
    }

    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }

    return controller.takePicture();
  }

  Future<void> startImageStream(onLatestImageAvailable onImage) async {
    final controller = _controller;
    if (controller == null) {
      throw StateError('Camera is not initialized.');
    }

    if (controller.value.isStreamingImages) {
      return;
    }

    await controller.startImageStream(onImage);
  }

  Future<void> stopImageStream() async {
    final controller = _controller;
    if (controller == null || !controller.value.isStreamingImages) {
      return;
    }

    await controller.stopImageStream();
  }

  Future<void> dispose() async {
    await stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  Future<void> _createController(CameraDescription description) async {
    final previousController = _controller;
    if (previousController != null) {
      if (previousController.value.isStreamingImages) {
        await previousController.stopImageStream();
      }
      await previousController.dispose();
    }

    final controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup:
          Platform.isAndroid
              ? ImageFormatGroup.nv21
              : ImageFormatGroup.bgra8888,
    );

    _controller = controller;
    await controller.initialize();
  }

  int _preferredCameraIndex() {
    final frontIndex = _cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );

    return frontIndex >= 0 ? frontIndex : 0;
  }
}
