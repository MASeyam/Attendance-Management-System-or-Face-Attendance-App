class AppConstants {
  const AppConstants._();

  static const String adminPin = '1234';
  static const String defaultGuidance = 'Center your face';
  static const String setupGuidance =
      'Open settings and enter the server URL and room ID';

  static const Duration frameProcessingInterval = Duration(milliseconds: 350);
  static const Duration resultDisplayDuration = Duration(seconds: 5);

  static const int requiredStableDetections = 3;
  static const double minFaceWidthRatio = 0.18;
  static const double minFaceHeightRatio = 0.18;
  static const double horizontalCenterTolerance = 0.16;
  static const double verticalCenterTolerance = 0.20;
  static const double maxMovementRatio = 0.035;
}
