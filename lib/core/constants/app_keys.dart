import 'package:flutter/foundation.dart';

/// Semantic Keys required by Planning/05 §3 for resilient testing
class AppKeys {
  // E01 Login
  static const Key loginEmail = Key('login-email');
  static const Key loginPassword = Key('login-password');
  static const Key loginSubmit = Key('login-submit');
  static const Key loginError = Key('login-error');
  static const Key loginToRegister = Key('login-to-register');
  static const Key loginToForgot = Key('login-to-forgot');

  // E03 Register
  static const Key registerFullName = Key('register-full-name');
  static const Key registerEmail = Key('register-email');
  static const Key registerPassword = Key('register-password');
  static const Key registerSubmit = Key('register-submit');
  static const Key registerError = Key('register-error');
  static const Key registerToLogin = Key('register-to-login');

  // E04 Forgot Password
  static const Key forgotEmail = Key('forgot-email');
  static const Key forgotSubmit = Key('forgot-submit');
  static const Key forgotSuccessBanner = Key('forgot-success-banner');
  static const Key forgotError = Key('forgot-error');
  static const Key forgotToReset = Key('forgot-to-reset');

  // E05 Reset Password
  static const Key resetToken = Key('reset-token');
  static const Key resetNewPassword = Key('reset-new-password');
  static const Key resetSubmit = Key('reset-submit');
  static const Key resetSuccessBanner = Key('reset-success-banner');
  static const Key resetError = Key('reset-error');
  static const Key resetToLogin = Key('reset-to-login');

  // E08 Change Password (/profile/password)
  static const Key changeCurrentPassword = Key('change-current-password');
  static const Key changeNewPassword = Key('change-new-password');
  static const Key changePasswordSubmit = Key('change-password-submit');
  static const Key changePasswordSuccess = Key('change-password-success');
  static const Key changePasswordError = Key('change-password-error');

  // E06 / Non-Employee Role Guard
  static const Key nonEmployeeScreen = Key('non-employee-screen');
  static const Key nonEmployeeLogoutButton = Key('non-employee-logout-button');

  // E07 Logout & Pending Sync Confirmation Modal
  static const Key logoutSubmit = Key('logout-submit');
  static const Key logoutConfirmModal = Key('logout-confirm-modal');
  static const Key logoutConfirmProceed = Key('logout-confirm-proceed');
  static const Key logoutConfirmCancel = Key('logout-confirm-cancel');

  // Home & Navigation
  static const Key homeScreen = Key('home-screen');
  static const Key homeToChangePassword = Key('home-to-change-password');
  static const Key homeToAttendance = Key('home-to-attendance');
  static const Key homeTodaySummaryCard = Key('home-today-summary-card');

  // E09 - E14 Attendance & J2 Critical Journey
  static const Key attendanceScreen = Key('attendance-screen');
  static const Key gpsStatusCard = Key('gps-status-card');
  static const Key gpsDistanceText = Key('gps-distance-text');
  static const Key gpsAccuracyText = Key('gps-accuracy-text');
  static const Key locationDropdown = Key('location-dropdown');
  static const Key selfieStubToggle = Key('selfie-stub-toggle');
  static const Key checkinSubmit = Key('checkin-submit');
  static const Key checkoutSubmit = Key('checkout-submit');
  static const Key syncBadge = Key('sync-badge');
  static const Key syncRetryButton = Key('sync-retry-button');
  static const Key attendanceErrorBanner = Key('attendance-error-banner');
  static const Key attendanceStatusBanner = Key('attendance-status-banner');
  static const Key attendanceToHistory = Key('attendance-to-history');
  static const Key attendanceHistoryScreen = Key('attendance-history-screen');
  static const Key attendanceHistoryList = Key('attendance-history-list');
}


