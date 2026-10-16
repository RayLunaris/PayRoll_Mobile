import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

enum PayrollButtonVariant { primary, secondary, danger }

class PayrollCtaButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final PayrollButtonVariant variant;
  final Key? buttonKey;

  const PayrollCtaButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.variant = PayrollButtonVariant.primary,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color foregroundColor;
    BorderSide? borderSide;

    switch (variant) {
      case PayrollButtonVariant.primary:
        backgroundColor = AppColors.primaryNavy;
        foregroundColor = Colors.white;
        break;
      case PayrollButtonVariant.secondary:
        backgroundColor = AppColors.surface;
        foregroundColor = AppColors.primaryNavy;
        borderSide = const BorderSide(color: AppColors.primaryNavy, width: 1.5);
        break;
      case PayrollButtonVariant.danger:
        backgroundColor = AppColors.dangerRed;
        foregroundColor = Colors.white;
        break;
    }

    final isEnabled = onPressed != null && !isLoading;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        key: buttonKey ?? key,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: AppColors.outline,
          disabledForegroundColor: Colors.white,
          side: borderSide,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusCta),
          ),
          elevation: 0,
        ),
        onPressed: isEnabled ? onPressed : null,
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
