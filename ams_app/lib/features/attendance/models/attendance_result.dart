enum AttendanceResultType { success, warning, unknownFace, error }

class AttendanceResult {
  const AttendanceResult({
    required this.type,
    required this.title,
    required this.message,
  });

  final AttendanceResultType type;
  final String title;
  final String message;
}
