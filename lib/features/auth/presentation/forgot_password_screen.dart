import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/payroll_cta_button.dart';
import '../data/auth_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final AuthRepository authRepository;

  const ForgotPasswordScreen({
    super.key,
    required this.authRepository,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  String? _successMessage;
  String? _errorMessage;

  static const String _antiEnumerationMessage =
      'Jika email terdaftar, link reset password sudah dikirim ke inbox Anda.';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleForgot() async {
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
      await widget.authRepository.forgotPassword(_emailController.text);
      if (mounted) {
        setState(() {
          // Always show generic anti-enumeration message (Planning/10 E04)
          _successMessage = _antiEnumerationMessage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final errStr = e.toString();
          if (errStr.contains('429')) {
            _errorMessage = 'Terlalu banyak permintaan. Silakan coba beberapa saat lagi.';
          } else if (errStr.contains('400')) {
            _errorMessage = 'Format email tidak valid';
          } else {
            _errorMessage = 'Gagal memproses permintaan. Periksa koneksi Anda.';
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
        title: const Text('Lupa Kata Sandi'),
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
                  'Atur Ulang Kata Sandi',
                  style: AppTypography.display.copyWith(
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  'Masukkan alamat email akun Anda untuk menerima tautan atau token reset kata sandi.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: AppSpacing.s24),

                if (_successMessage != null) ...[
                  Container(
                    key: AppKeys.forgotSuccessBanner,
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
                    key: AppKeys.forgotError,
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
                  key: AppKeys.forgotEmail,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleForgot(),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'nama@payrollpro.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Email wajib diisi';
                    }
                    if (!val.contains('@') || !val.contains('.')) {
                      return 'Format email tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s24),

                PayrollCtaButton(
                  buttonKey: AppKeys.forgotSubmit,
                  text: 'Kirim Link Reset',
                  isLoading: _isLoading,
                  onPressed: _handleForgot,
                ),
                const SizedBox(height: AppSpacing.s16),

                TextButton(
                  key: AppKeys.forgotToReset,
                  onPressed: () => context.go('/reset-password'),
                  child: const Text('Sudah punya token reset? Masukkan di sini'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
