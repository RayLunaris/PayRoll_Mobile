import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

enum StatusType { pending, approved, rejected, paid, draft }

class StatusChip extends StatelessWidget {
  final String label;
  final StatusType type;

  const StatusChip({
    super.key,
    required this.label,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (type) {
      case StatusType.pending:
        bg = AppColors.warningAmber.withValues(alpha: 0.15);
        fg = AppColors.warningAmber;
        break;
      case StatusType.approved:
      case StatusType.paid:
        bg = AppColors.successEmerald.withValues(alpha: 0.15);
        fg = AppColors.successEmerald;
        break;
      case StatusType.rejected:
        bg = AppColors.dangerRed.withValues(alpha: 0.15);
        fg = AppColors.dangerRed;
        break;
      case StatusType.draft:
        bg = AppColors.outline.withValues(alpha: 0.25);
        fg = AppColors.onSurface;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusBadge),
      ),
      child: Text(
        label,
        style: AppTypography.label.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
