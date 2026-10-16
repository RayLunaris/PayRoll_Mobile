import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/payroll_cta_button.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../auth/data/auth_repository.dart';

class HomeScreen extends StatelessWidget {
  final AuthRepository authRepository;
  final AttendanceRepository? attendanceRepository;

  const HomeScreen({
    super.key,
    required this.authRepository,
    this.attendanceRepository,
  });

  Future<void> _handleLogoutWithPendingCheck(BuildContext context) async {
    final pendingCount = await authRepository.getPendingSyncCount();
    if (pendingCount > 0 && context.mounted) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: AppKeys.logoutConfirmModal,
          title: const Text('Antrean Belum Tersinkron'),
          content: Text(
            'Ada $pendingCount antrean absensi/data offline yang belum tersinkron ke server. '
            'Keluar sekarang akan menghapus seluruh antrean lokal secara permanen.',
          ),
          actions: [
            TextButton(
              key: AppKeys.logoutConfirmCancel,
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              key: AppKeys.logoutConfirmProceed,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.dangerRed,
              ),
              child: const Text('Tetap Keluar & Hapus'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) {
        return;
      }
    }

    await authRepository.logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = authRepository.currentUser;
    final isSelfCheckedIn =
        attendanceRepository?.todaySummary?.isSelfCheckedIn ?? false;

    return Scaffold(
      key: AppKeys.homeScreen,
      appBar: AppBar(
        title: const Text('PayrollPro Home'),
        actions: [
          IconButton(
            key: AppKeys.homeToChangePassword,
            icon: const Icon(Icons.lock_reset_rounded),
            tooltip: 'Ganti Kata Sandi',
            onPressed: () => context.push('/profile/password'),
          ),
          IconButton(
            key: AppKeys.logoutSubmit,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
            onPressed: () => _handleLogoutWithPendingCheck(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primaryContainer,
                            child: Text(
                              (user?.email.isNotEmpty == true)
                                  ? user!.email[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: AppColors.primaryNavy,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.email ?? 'Employee',
                                  style: AppTypography.title,
                                ),
                                Text(
                                  'Role: ${user?.role ?? "employee"}',
                                  style: AppTypography.label.copyWith(
                                    color: AppColors.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (user?.employeeId != null) ...[
                        const SizedBox(height: AppSpacing.s12),
                        const Divider(),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          'Employee ID: ${user!.employeeId}',
                          style: AppTypography.mono,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),

              // E14 Today Summary Card (strictly only consumes isSelfCheckedIn)
              Card(
                key: AppKeys.homeTodaySummaryCard,
                color: AppColors.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isSelfCheckedIn
                                ? Icons.verified_rounded
                                : Icons.access_time_rounded,
                            color: isSelfCheckedIn
                                ? AppColors.successEmerald
                                : AppColors.primaryNavy,
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Text(
                            isSelfCheckedIn
                                ? 'Kehadiran Hari Ini: Sudah Check-In'
                                : 'Kehadiran Hari Ini: Belum Check-In',
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      PayrollCtaButton(
                        buttonKey: AppKeys.homeToAttendance,
                        text: 'Buka Absensi GPS',
                        onPressed: () => context.push('/attendance'),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              PayrollCtaButton(
                buttonKey: const Key('home-logout-cta'),
                text: 'Keluar (Logout)',
                variant: PayrollButtonVariant.danger,
                onPressed: () => _handleLogoutWithPendingCheck(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


