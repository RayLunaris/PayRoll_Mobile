import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/payroll_cta_button.dart';
import '../data/auth_repository.dart';

class ResetPasswordScreen extends StatefulWidget {
  final AuthRepository authRepository;
  final String? initialToken;

  const ResetPasswordScreen({
    super.key,
    required this.authRepository,
    this.initialToken,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tokenController;
  final _newPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _successMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.initialToken ?? '');
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
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
      final msg = await widget.authRepository.resetPassword(
        token: _tokenController.text,
        newPassword: _newPasswordController.text,
      );
      if (mounted) {
        setState(() {
          _successMessage = msg;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is ApiException) {
            _errorMessage = e.message;
          } else {
            _errorMessage = 'Token tidak valid atau sudah kedaluwarsa.';
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
        title: const Text('Reset Kata Sandi'),
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
                  'Buat Kata Sandi Baru',
                  style: AppTypography.display.copyWith(
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  'Masukkan token dari email Anda dan kata sandi baru minimal 6 karakter.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: AppSpacing.s24),

                if (_successMessage != null) ...[
                  Container(
                    key: AppKeys.resetSuccessBanner,
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
                    key: AppKeys.resetError,
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
                  key: AppKeys.resetToken,
                  controller: _tokenController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Token Reset',
                    hintText: 'Masukkan token reset',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Token reset wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s16),

                TextFormField(
                  key: AppKeys.resetNewPassword,
                  controller: _newPasswordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleReset(),
                  decoration: InputDecoration(
                    labelText: 'Kata Sandi Baru',
                    hintText: 'Minimal 6 karakter',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Kata sandi baru wajib diisi';
                    }
                    if (val.length < 6) {
                      return 'Kata sandi minimal 6 karakter';
                    }
                    if (val.length > 72) {
                      return 'Kata sandi maksimal 72 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s24),

                PayrollCtaButton(
                  buttonKey: AppKeys.resetSubmit,
                  text: 'Simpan Kata Sandi Baru',
                  isLoading: _isLoading,
                  onPressed: _handleReset,
                ),
                const SizedBox(height: AppSpacing.s16),

                TextButton(
                  key: AppKeys.resetToLogin,
                  onPressed: () => context.go('/login'),
                  child: const Text('Kembali ke Halaman Masuk'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
