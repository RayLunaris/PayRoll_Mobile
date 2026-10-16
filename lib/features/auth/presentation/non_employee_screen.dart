import 'package:flutter/material.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/payroll_cta_button.dart';
import '../data/auth_repository.dart';

/// Blocking screen shown when a non-employee role (super_admin, hr_admin, manager)
/// logs into the mobile app (Planning/03 §Aturan Flutter #3, Planning/09 §5).
class NonEmployeeScreen extends StatelessWidget {
  final AuthRepository authRepository;

  const NonEmployeeScreen({
    super.key,
    required this.authRepository,
  });

  @override
  Widget build(BuildContext context) {
    final role = authRepository.currentUser?.role ?? 'admin';

    return Scaffold(
      key: AppKeys.nonEmployeeScreen,
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.desktop_windows_rounded,
                size: 64,
                color: AppColors.warningAmber,
              ),
              const SizedBox(height: AppSpacing.s24),
              Text(
                'Gunakan versi web',
                textAlign: TextAlign.center,
                style: AppTypography.display.copyWith(
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                'Aplikasi mobile PayrollPro khusus untuk karyawan (Employee Self-Service). '
                'Akun Anda memiliki role "$role". Silakan gunakan versi web untuk fitur manajemen, HR, atau approval.',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.onSurface.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: AppSpacing.s32),
              PayrollCtaButton(
                buttonKey: AppKeys.nonEmployeeLogoutButton,
                text: 'Keluar (Logout)',
                variant: PayrollButtonVariant.danger,
                onPressed: () async {
                  await authRepository.logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
