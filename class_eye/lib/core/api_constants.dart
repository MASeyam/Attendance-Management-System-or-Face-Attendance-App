class ApiConstants {
  static const String baseUrl = 'https://splendor-switch-glance.ngrok-free.dev';

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String studentLogin    = '$baseUrl/auth/student/login';
  static const String instructorLogin = '$baseUrl/auth/instructor/login';
  static const String adminLogin      = '$baseUrl/auth/admin/login';
  static const String changePassword  = '$baseUrl/auth/change-password';

  // ── Legacy (ams_app compat) ───────────────────────────────────────────────
  static const String loginEndpoint             = '$baseUrl/login';
  static const String scanEndpoint              = '$baseUrl/kiosk_scan';
  static const String studentCoursesEndpoint    = '$baseUrl/get_student_courses';
  static const String courseDetailsEndpoint     = '$baseUrl/get_course_details';
  static const String instructorCoursesEndpoint = '$baseUrl/get_my_courses';
  static const String sessionAttendanceEndpoint = '$baseUrl/get_session_attendance';

  // ── Students ──────────────────────────────────────────────────────────────
  static const String students        = '$baseUrl/students';
  static String student(int id)       => '$baseUrl/students/$id';
  static const String createStudent   = '$baseUrl/students/create';
  static String deleteStudent(int id) => '$baseUrl/students/$id';
  static const String studentNextId   = '$baseUrl/students/next-id';
  static String attendanceSummary(int id) => '$baseUrl/students/$id/attendance-summary';
  static String attendanceHistory(int id) => '$baseUrl/students/$id/attendance-history';
  static String studentSchedule(int id)   => '$baseUrl/students/$id/schedule';
  static String studentIssues(int id)     => '$baseUrl/students/$id/issues';

  // ── Instructors ───────────────────────────────────────────────────────────
  static const String instructors         = '$baseUrl/instructors';
  static String instructor(int id)        => '$baseUrl/instructors/$id';
  static const String createInstructor    = '$baseUrl/instructors/create';
  static String deleteInstructor(int id)  => '$baseUrl/instructors/$id';
  static String sessionsToday(int id)     => '$baseUrl/instructors/$id/sessions/today';
  static String instructorReports(int id) => '$baseUrl/instructors/$id/reports';

  // ── Sessions / Attendance ─────────────────────────────────────────────────
  static String openSession(int id)       => '$baseUrl/sessions/$id/open';
  static String closeSession(int id)      => '$baseUrl/sessions/$id/close';
  static String sessionAttendance(int id) => '$baseUrl/sessions/$id/attendance';
  static String updateAttendance(int id)  => '$baseUrl/attendance/$id/update';

  // ── Issues ────────────────────────────────────────────────────────────────
  static const String createIssue           = '$baseUrl/issues/create';
  static String instructorIssues(int id)    => '$baseUrl/issues/instructor/$id';
  static String handleIssue(int id)         => '$baseUrl/issues/$id/handle';

  // ── Courses ───────────────────────────────────────────────────────────────
  static const String courses      = '$baseUrl/courses';
  static const String createCourse = '$baseUrl/courses/create';
  static const String classrooms   = '$baseUrl/classrooms';
  static const String departments  = '$baseUrl/departments';

  // ── Notifications ─────────────────────────────────────────────────────────
  static String notifications(int uid, String role) =>
      '$baseUrl/notifications/$uid/$role';
  static String markNotificationRead(int id) =>
      '$baseUrl/notifications/$id/read';

  // ── Admin ─────────────────────────────────────────────────────────────────
  static const String adminStats          = '$baseUrl/admin/stats';
  static const String adminAttendanceLogs = '$baseUrl/admin/attendance-logs';
  static const String adminAuditLogs      = '$baseUrl/admin/audit-logs';

  // ── Training ──────────────────────────────────────────────────────────────
  static String trainStudent(String id)  => '$baseUrl/train/student/$id';
  static String trainInstructor(int id)  => '$baseUrl/train/instructor/$id';
  static String uploadPhotos(String id)  => '$baseUrl/train/upload/$id';
}
