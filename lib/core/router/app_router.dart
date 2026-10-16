import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/attendance/data/attendance_repository.dart';
import '../../features/attendance/presentation/attendance_history_screen.dart';
import '../../features/attendance/presentation/attendance_screen.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/change_password_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/non_employee_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/home/presentation/home_screen.dart';

class AppRouter {
  static GoRouter createRouter(
    AuthRepository authRepository, {
    AttendanceRepository? attendanceRepository,
  }) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: authRepository,
      redirect: (context, state) {
        final isAuth = authRepository.isAuthenticated;
        final isEmployee = authRepository.isEmployee;
        final loc = state.matchedLocation;

        final isGoingToAuth = loc == '/login' ||
            loc == '/register' ||
            loc == '/forgot-password' ||
            loc == '/reset-password';

        // Root / splash redirect
        if (loc == '/') {
          if (!isAuth) return '/login';
          return isEmployee ? '/home' : '/non-employee';
        }

        // Unauthenticated access guard
        if (!isAuth && !isGoingToAuth) {
          return '/login';
        }

        // Non-employee role guard: block manager/hr_admin/super_admin with "Gunakan versi web"
        if (isAuth && !isEmployee && loc != '/non-employee') {
          return '/non-employee';
        }

        // Employee trying to access /non-employee or auth screens redirects to /home
        if (isAuth && isEmployee && (isGoingToAuth || loc == '/non-employee')) {
          return '/home';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => LoginScreen(authRepository: authRepository),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => RegisterScreen(authRepository: authRepository),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => ForgotPasswordScreen(authRepository: authRepository),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (context, state) => ResetPasswordScreen(
            authRepository: authRepository,
            initialToken: state.uri.queryParameters['token'],
          ),
        ),
        GoRoute(
          path: '/non-employee',
          builder: (context, state) => NonEmployeeScreen(authRepository: authRepository),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => HomeScreen(
            authRepository: authRepository,
            attendanceRepository: attendanceRepository,
          ),
        ),
        GoRoute(
          path: '/profile/password',
          builder: (context, state) => ChangePasswordScreen(authRepository: authRepository),
        ),
        if (attendanceRepository != null) ...[
          GoRoute(
            path: '/attendance',
            builder: (context, state) => AttendanceScreen(
              attendanceRepository: attendanceRepository,
            ),
          ),
          GoRoute(
            path: '/attendance/history',
            builder: (context, state) => AttendanceHistoryScreen(
              attendanceRepository: attendanceRepository,
            ),
          ),
        ],
      ],
    );
  }
}


