// lib/core/api_constants.dart

class ApiConstants {
  // ⚠️ CHANGE THIS IP TO MATCH YOUR SERVER
  static const String baseUrl = 'http://192.168.100.126:5001';

  // Auth & Kiosk
  static const String loginEndpoint = '$baseUrl/login'; // Now the unified login
  static const String scanEndpoint = '$baseUrl/kiosk_scan';

  // Student Dashboard
  static const String studentCoursesEndpoint = '$baseUrl/get_student_courses';
  static const String courseDetailsEndpoint = '$baseUrl/get_course_details';

  // Instructor Dashboard (Prepared for later)
  static const String instructorCoursesEndpoint = '$baseUrl/get_my_courses';
  static const String sessionAttendanceEndpoint =
      '$baseUrl/get_session_attendance';
}
