import 'dart:async';
import 'dart:io';

import 'package:ams_app/core/constants/app_constants.dart';
import 'package:ams_app/features/attendance/models/attendance_result.dart';
import 'package:ams_app/features/attendance/services/attendance_api_service.dart';
import 'package:ams_app/features/attendance/services/camera_service.dart';
import 'package:ams_app/features/attendance/services/face_detection_service.dart';
import 'package:ams_app/features/settings/models/app_settings.dart';
import 'package:ams_app/features/settings/services/settings_service.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum KioskStatusTone { neutral, progress, success, warning, error }

class AttendanceController extends ChangeNotifier {
  AttendanceController({
    CameraService? cameraService,
    FaceDetectionService? faceDetectionService,
    AttendanceApiService? attendanceApiService,
    SettingsService? settingsService,
  }) : _cameraService = cameraService ?? CameraService(),
       _faceDetectionService = faceDetectionService ?? FaceDetectionService(),
       _attendanceApiService = attendanceApiService ?? AttendanceApiService(),
       _settingsService = settingsService ?? SettingsService();

  final CameraService _cameraService;
  final FaceDetectionService _faceDetectionService;
  final AttendanceApiService _attendanceApiService;
  final SettingsService _settingsService;

  AppSettings _settings = const AppSettings.empty();
  AttendanceResult? _activeResult;
  Timer? _resumeTimer;
  Rect? _previousFaceBox;
  DateTime _lastFrameProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isUploading = false;
  bool _isProcessingFrame = false;
  bool _isShowingResult = false;
  bool _isDisposed = false;
  int _stableDetections = 0;
  String _guidanceText = AppConstants.setupGuidance;
  String? _startupError;

  CameraController? get cameraController => _cameraService.controller;
  AppSettings get settings => _settings;
  bool get isInitializing => _isInitializing;
  bool get canSwitchCamera => _cameraService.canSwitchCamera;
  bool get hasActiveCamera => cameraController?.value.isInitialized ?? false;
  bool get isBusy => _isCapturing || _isUploading;

  KioskStatusTone get statusTone {
    if (_activeResult != null) {
      switch (_activeResult!.type) {
        case AttendanceResultType.success:
          return KioskStatusTone.success;
        case AttendanceResultType.warning:
          return KioskStatusTone.warning;
        case AttendanceResultType.unknownFace:
          return KioskStatusTone.error;
        case AttendanceResultType.error:
          return KioskStatusTone.error;
      }
    }

    if (_startupError != null) {
      return KioskStatusTone.error;
    }

    if (!_settings.isComplete) {
      return KioskStatusTone.warning;
    }

    if (_isCapturing || _isUploading) {
      return KioskStatusTone.progress;
    }

    return KioskStatusTone.neutral;
  }

  String get statusTitle {
    if (_activeResult != null) {
      return _activeResult!.title;
    }

    if (_startupError != null) {
      return 'Camera Error';
    }

    if (!_settings.isComplete) {
      return 'Setup Required';
    }

    if (_isCapturing) {
      return 'Capturing...';
    }

    if (_isUploading) {
      return 'Uploading...';
    }

    return 'Auto Scan Active';
  }

  String get statusMessage {
    if (_activeResult != null) {
      return _activeResult!.message;
    }

    if (_startupError != null) {
      return _startupError!;
    }

    return _guidanceText;
  }

  Future<void> initialize() async {
    try {
      _settings = await _settingsService.loadSettings();
      await _cameraService.initialize();

      if (cameraController == null) {
        _startupError = 'No camera was found on this device.';
        _guidanceText = 'This kiosk needs a camera to scan faces.';
      } else if (_settings.isComplete) {
        _guidanceText = AppConstants.defaultGuidance;
      } else {
        _guidanceText = AppConstants.setupGuidance;
      }
    } catch (_) {
      _startupError = 'Unable to start the camera.';
      _guidanceText = 'Restart the app and check the camera permission.';
    } finally {
      _isInitializing = false;
      _notify();
    }

    if (_startupError == null && _settings.isComplete) {
      await resumeScanning();
    }
  }

  Future<void> refreshSettings() async {
    _settings = await _settingsService.loadSettings();

    if (!_settings.isComplete) {
      await pauseScanning();
      _activeResult = null;
      _isShowingResult = false;
      _guidanceText = AppConstants.setupGuidance;
      _notify();
      return;
    }

    _guidanceText = AppConstants.defaultGuidance;
    _notify();

    if (!_isShowingResult && !_isCapturing && !_isUploading) {
      await resumeScanning();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _settingsService.saveSettings(settings);
    await refreshSettings();
  }

  Future<void> pauseScanning() async {
    _resumeTimer?.cancel();
    _resetFaceTracking();
    await _cameraService.stopImageStream();
    _notify();
  }

  Future<void> resumeScanning() async {
    if (!_settings.isComplete ||
        _startupError != null ||
        cameraController == null ||
        _isShowingResult ||
        _isCapturing ||
        _isUploading) {
      return;
    }

    _resumeTimer?.cancel();
    _resetFaceTracking();
    _guidanceText = AppConstants.defaultGuidance;
    _notify();
    await _cameraService.startImageStream(_handleCameraImage);
    _notify();
  }

  Future<void> switchCamera() async {
    if (!canSwitchCamera) {
      return;
    }

    await pauseScanning();
    await _cameraService.switchCamera();
    _notify();

    if (_settings.isComplete) {
      await resumeScanning();
    }
  }

  void _handleCameraImage(CameraImage image) {
    if (_isProcessingFrame ||
        _isShowingResult ||
        _isCapturing ||
        _isUploading ||
        !_settings.isComplete) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastFrameProcessedAt) <
        AppConstants.frameProcessingInterval) {
      return;
    }

    _isProcessingFrame = true;
    _lastFrameProcessedAt = now;
    unawaited(_processFrame(image));
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      final controller = cameraController;
      final activeCamera = _cameraService.activeCamera;
      if (controller == null || activeCamera == null) {
        return;
      }

      final faces = await _faceDetectionService.detectFaces(
        image: image,
        camera: activeCamera,
        deviceOrientation: controller.value.deviceOrientation,
      );

      if (_isShowingResult || _isCapturing || _isUploading) {
        return;
      }

      _evaluateFaces(
        faces: faces,
        frameSize: Size(image.width.toDouble(), image.height.toDouble()),
      );
    } catch (_) {
      if (!_isShowingResult && !_isCapturing && !_isUploading) {
        _setGuidance(AppConstants.defaultGuidance);
      }
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _evaluateFaces({required List<Face> faces, required Size frameSize}) {
    if (faces.isEmpty) {
      _resetFaceTracking();
      _setGuidance('Center your face');
      return;
    }

    if (faces.length > 1) {
      _resetFaceTracking();
      _setGuidance('One person at a time');
      return;
    }

    final face = faces.first;

    if (_isFaceTooSmall(face, frameSize)) {
      _resetFaceTracking();
      _previousFaceBox = face.boundingBox;
      _setGuidance('Get closer');
      return;
    }

    if (!_isFaceCentered(face, frameSize)) {
      _resetFaceTracking();
      _previousFaceBox = face.boundingBox;
      _setGuidance('Center your face');
      return;
    }

    if (!_isFaceStill(face, frameSize)) {
      _stableDetections = 0;
      _previousFaceBox = face.boundingBox;
      _setGuidance('Stand still');
      return;
    }

    _previousFaceBox = face.boundingBox;
    _stableDetections += 1;

    if (_stableDetections < AppConstants.requiredStableDetections) {
      _setGuidance('Stand still');
      return;
    }

    _startAutoCapture();
  }

  void _startAutoCapture() {
    if (_isCapturing || _isUploading || _isShowingResult) {
      return;
    }

    _isCapturing = true;
    _guidanceText = 'Capturing...';
    _notify();
    unawaited(_captureAndUpload());
  }

  Future<void> _captureAndUpload() async {
    try {
      await _cameraService.stopImageStream();
      _resetFaceTracking();

      final picture = await _cameraService.takePicture();
      _isCapturing = false;
      _isUploading = true;
      _guidanceText = 'Uploading...';
      _notify();

      final imageFile = File(picture.path);
      final result = await _attendanceApiService.submitAttendance(
        imageFile: imageFile,
        settings: _settings,
      );
      await _deleteCapturedFile(imageFile);
      _showResult(result);
    } catch (_) {
      _showResult(
        const AttendanceResult(
          type: AttendanceResultType.error,
          title: 'System Error',
          message: 'Failed to capture or upload the photo.',
        ),
      );
    }
  }

  void _showResult(AttendanceResult result) {
    _resumeTimer?.cancel();
    _activeResult = result;
    _isCapturing = false;
    _isUploading = false;
    _isShowingResult = true;
    _notify();

    _resumeTimer = Timer(AppConstants.resultDisplayDuration, () {
      _activeResult = null;
      _isShowingResult = false;
      _guidanceText =
          _settings.isComplete
              ? AppConstants.defaultGuidance
              : AppConstants.setupGuidance;
      _notify();

      if (_settings.isComplete) {
        unawaited(resumeScanning());
      }
    });
  }

  bool _isFaceTooSmall(Face face, Size frameSize) {
    final widthRatio = face.boundingBox.width / frameSize.width;
    final heightRatio = face.boundingBox.height / frameSize.height;

    return widthRatio < AppConstants.minFaceWidthRatio ||
        heightRatio < AppConstants.minFaceHeightRatio;
  }

  bool _isFaceCentered(Face face, Size frameSize) {
    final faceCenter = face.boundingBox.center;
    final horizontalOffset =
        (faceCenter.dx - frameSize.width / 2).abs() / frameSize.width;
    final verticalOffset =
        (faceCenter.dy - frameSize.height / 2).abs() / frameSize.height;

    return horizontalOffset <= AppConstants.horizontalCenterTolerance &&
        verticalOffset <= AppConstants.verticalCenterTolerance;
  }

  bool _isFaceStill(Face face, Size frameSize) {
    final previousFaceBox = _previousFaceBox;
    if (previousFaceBox == null) {
      return false;
    }

    final currentCenter = face.boundingBox.center;
    final previousCenter = previousFaceBox.center;
    final deltaX =
        (currentCenter.dx - previousCenter.dx).abs() / frameSize.width;
    final deltaY =
        (currentCenter.dy - previousCenter.dy).abs() / frameSize.height;

    return deltaX <= AppConstants.maxMovementRatio &&
        deltaY <= AppConstants.maxMovementRatio;
  }

  void _setGuidance(String value) {
    if (_guidanceText == value) {
      return;
    }

    _guidanceText = value;
    _notify();
  }

  void _resetFaceTracking() {
    _stableDetections = 0;
    _previousFaceBox = null;
  }

  Future<void> _deleteCapturedFile(File imageFile) async {
    if (await imageFile.exists()) {
      await imageFile.delete();
    }
  }

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _resumeTimer?.cancel();
    unawaited(_cameraService.dispose());
    unawaited(_faceDetectionService.dispose());
    super.dispose();
  }
}
