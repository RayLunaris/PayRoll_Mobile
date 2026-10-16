import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class MoneyText extends StatelessWidget {
  final String amount;
  final String? period;
  final TextStyle? textStyle;

  const MoneyText({
    super.key,
    required this.amount,
    this.period,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          amount.startsWith('Rp') ? amount : 'Rp $amount',
          style: textStyle ??
              AppTypography.display.copyWith(
                color: AppColors.primaryNavy,
              ),
        ),
        if (period != null)
          Text(
            period!,
            style: AppTypography.label.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.6),
            ),
          ),
      ],
    );
  }
}
