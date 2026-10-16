import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Design tokens typography from Planning/02 §3 (Inter font family)
class AppTypography {
  static const TextStyle display = TextStyle(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.bold,
    color: AppColors.onSurface,
  );

  static const TextStyle title = TextStyle(
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.normal,
    color: AppColors.onSurface,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    color: AppColors.onSurface,
  );

  static const TextStyle mono = TextStyle(
    fontSize: 12,
    fontFamily: 'monospace',
    fontWeight: FontWeight.normal,
    color: AppColors.onSurface,
  );
}
