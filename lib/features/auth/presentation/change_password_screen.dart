import 'package:flutter/material.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/payroll_cta_button.dart';
import '../data/auth_repository.dart';

class ChangePasswordScreen extends StatefulWidget {
  final AuthRepository authRepository;

  const ChangePasswordScreen({
    super.key,
    required this.authRepository,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  String? _successMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final msg = await widget.authRepository.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (mounted) {
        setState(() {
          _successMessage = msg;
          _currentPasswordController.clear();
          _newPasswordController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is ApiException) {
            if (e.statusCode == 401) {
              _errorMessage = 'Password saat ini salah';
            } else {
              _errorMessage = e.message;
            }
          } else {
            _errorMessage = 'Gagal mengubah kata sandi. Periksa kembali kata sandi Anda.';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ganti Kata Sandi'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Perbarui Kata Sandi',
                  style: AppTypography.display.copyWith(
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  'Masukkan kata sandi saat ini dan kata sandi baru minimal 6 karakter.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: AppSpacing.s24),

                if (_successMessage != null) ...[
                  Container(
                    key: AppKeys.changePasswordSuccess,
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.successEmerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCta),
                      border: Border.all(
                        color: AppColors.successEmerald.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: AppColors.successEmerald,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: AppTypography.body.copyWith(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                ],

                if (_errorMessage != null) ...[
                  Container(
                    key: AppKeys.changePasswordError,
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCta),
                      border: Border.all(
                        color: AppColors.dangerRed.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.dangerRed,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AppTypography.body.copyWith(
                              color: AppColors.dangerRed,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                ],

                TextFormField(
                  key: AppKeys.changeCurrentPassword,
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrent,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Kata Sandi Saat Ini',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrent
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureCurrent = !_obscureCurrent;
                        });
                      },
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Kata sandi saat ini wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s16),

                TextFormField(
                  key: AppKeys.changeNewPassword,
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleChangePassword(),
                  decoration: InputDecoration(
                    labelText: 'Kata Sandi Baru',
                    hintText: 'Minimal 6 karakter',
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureNew = !_obscureNew;
                        });
                      },
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Kata sandi baru wajib diisi';
                    }
                    if (val.length < 6) {
                      return 'Kata sandi baru minimal 6 karakter';
                    }
                    if (val.length > 72) {
                      return 'Kata sandi baru maksimal 72 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s24),

                PayrollCtaButton(
                  buttonKey: AppKeys.changePasswordSubmit,
                  text: 'Simpan Perubahan',
                  isLoading: _isLoading,
                  onPressed: _handleChangePassword,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
