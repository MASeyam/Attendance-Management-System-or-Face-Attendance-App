import 'dart:convert';
import 'dart:io';

import 'package:ams_app/features/attendance/models/attendance_result.dart';
import 'package:ams_app/features/settings/models/app_settings.dart';
import 'package:http/http.dart' as http;

class AttendanceApiService {
  Future<AttendanceResult> submitAttendance({
    required File imageFile,
    required AppSettings settings,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(settings.serverUrl),
      );

      request.fields['classroom_id'] = settings.roomId;
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final response = await request.send();
      final rawBody = await response.stream.bytesToString();
      final message = _extractMessage(rawBody);

      switch (response.statusCode) {
        case 200:
          return AttendanceResult(
            type: AttendanceResultType.success,
            title: 'Attendance Confirmed',
            message: message,
          );
        case 401:
          return AttendanceResult(
            type: AttendanceResultType.unknownFace,
            title: 'Face Not Recognized',
            message: message,
          );
        case 403:
          return AttendanceResult(
            type: AttendanceResultType.warning,
            title: 'Attendance Warning',
            message: message,
          );
        default:
          return AttendanceResult(
            type: AttendanceResultType.error,
            title: 'System Error',
            message: message,
          );
      }
    } on SocketException {
      return const AttendanceResult(
        type: AttendanceResultType.error,
        title: 'Connection Error',
        message:
            'Unable to reach the backend server. Check the saved URL and network connection.',
      );
    } catch (_) {
      return const AttendanceResult(
        type: AttendanceResultType.error,
        title: 'System Error',
        message: 'Something went wrong while sending the photo to the server.',
      );
    }
  }

  String _extractMessage(String rawBody) {
    if (rawBody.trim().isEmpty) {
      return 'No message returned from the server.';
    }

    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {
      // Fall back to the raw response body below.
    }

    return rawBody.trim();
  }
}
