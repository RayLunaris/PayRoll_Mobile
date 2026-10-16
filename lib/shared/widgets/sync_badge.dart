import 'package:flutter/material.dart';
import '../../core/constants/app_keys.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Offline & sync status states required by Planning/01 §12 and Planning/02 §7:
/// pending_sync -> syncing -> synced | failed
enum SyncStatus {
  synced,
  pendingSync,
  syncing,
  failed,
}

class SyncBadge extends StatelessWidget {
  final SyncStatus status;
  final int pendingCount;
  final VoidCallback? onRetry;

  const SyncBadge({
    super.key,
    required this.status,
    this.pendingCount = 0,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color fgColor;
    final IconData icon;
    final String label;

    switch (status) {
      case SyncStatus.synced:
        bgColor = AppColors.successEmerald.withValues(alpha: 0.14);
        fgColor = AppColors.successEmerald;
        icon = Icons.cloud_done_rounded;
        label = 'Terkirim';
        break;
      case SyncStatus.pendingSync:
        bgColor = AppColors.warningAmber.withValues(alpha: 0.16);
        fgColor = AppColors.warningAmber;
        icon = Icons.cloud_upload_outlined;
        label = pendingCount > 0
            ? 'Menunggu Sinkronisasi ($pendingCount)'
            : 'Menunggu Sinkronisasi';
        break;
      case SyncStatus.syncing:
        bgColor = AppColors.primaryContainer;
        fgColor = AppColors.primaryNavy;
        icon = Icons.sync_rounded;
        label = 'Menyinkronkan...';
        break;
      case SyncStatus.failed:
        bgColor = AppColors.dangerRed.withValues(alpha: 0.14);
        fgColor = AppColors.dangerRed;
        icon = Icons.sync_problem_rounded;
        label = 'Gagal Sinkron';
        break;
    }

    return Container(
      key: AppKeys.syncBadge,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusBadge),
        border: Border.all(color: fgColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fgColor),
          const SizedBox(width: AppSpacing.s4),
          Text(
            label,
            style: AppTypography.label.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if ((status == SyncStatus.pendingSync || status == SyncStatus.failed) &&
              onRetry != null) ...[
            const SizedBox(width: AppSpacing.s8),
            InkWell(
              key: AppKeys.syncRetryButton,
              onTap: onRetry,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                child: Text(
                  'Coba Lagi',
                  style: AppTypography.label.copyWith(
                    color: fgColor,
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
