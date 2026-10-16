class ApiEndpoints {
  // Staging gateway default: :3001
  static const String defaultBaseUrl = 'http://127.0.0.1:3001';

  // Auth endpoints (E01 - E08)
  static const String login = '/api/auth/login';
  static const String refresh = '/api/auth/refresh';
  static const String register = '/api/auth/register';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String resetPassword = '/api/auth/reset-password';
  static const String me = '/api/auth/me';
  static const String logout = '/api/auth/logout';
  static const String updatePassword = '/api/auth/password';

  // Device tokens (B1)
  static const String deviceTokens = '/api/device-tokens';

  // Attendance & Locations endpoints (E09 - E14)
  static const String locations = '/api/locations';
  static const String attendanceCheckIn = '/api/attendance/check-in';
  static const String attendanceCheckOut = '/api/attendance/check-out';
  static const String attendanceToday = '/api/attendance/today';
  static const String attendanceHistory = '/api/attendance/history';
  static const String attendanceReport = '/api/attendance/report';
  static const String attendanceWeeklyStats = '/api/attendance/weekly-stats';
  static const String attendanceTodaySummary = '/api/attendance/today-summary';
}

