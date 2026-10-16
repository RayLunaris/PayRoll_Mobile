import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/payroll_cta_button.dart';
import '../data/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  final AuthRepository authRepository;

  const LoginScreen({
    super.key,
    required this.authRepository,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.authRepository.login(
        _emailController.text,
        _passwordController.text,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          // General message for credentials / validation without leaking user existence
          final errStr = e.toString();
          if (errStr.contains('401') || errStr.toLowerCase().contains('unauthorized')) {
            _errorMessage = 'Email atau kata sandi tidak valid';
          } else if (errStr.contains('400')) {
            _errorMessage = 'Format email atau kata sandi tidak sesuai';
          } else {
            _errorMessage = 'Gagal masuk. Periksa koneksi internet Anda.';
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 64,
                    color: AppColors.primaryNavy,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Text(
                    'PayrollPro',
                    textAlign: TextAlign.center,
                    style: AppTypography.display.copyWith(
                      color: AppColors.primaryNavy,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    'Employee Self-Service Portal',
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: AppColors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s32),

                  // Error banner
                  if (_errorMessage != null) ...[
                    Container(
                      key: AppKeys.loginError,
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusCta),
                        border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.4)),
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

                  // Email field
                  TextFormField(
                    key: AppKeys.loginEmail,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
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
                  const SizedBox(height: AppSpacing.s16),

                  // Password field
                  TextFormField(
                    key: AppKeys.loginPassword,
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                    decoration: InputDecoration(
                      labelText: 'Kata Sandi',
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
                        return 'Kata sandi wajib diisi';
                      }
                      if (val.length < 6) {
                        return 'Kata sandi minimal 6 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.s8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: AppKeys.loginToForgot,
                      onPressed: () => context.push('/forgot-password'),
                      child: const Text('Lupa kata sandi?'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // Submit button
                  PayrollCtaButton(
                    buttonKey: AppKeys.loginSubmit,
                    text: 'Masuk',
                    isLoading: _isLoading,
                    onPressed: _handleLogin,
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  TextButton(
                    key: AppKeys.loginToRegister,
                    onPressed: () => context.push('/register'),
                    child: const Text('Belum punya akun? Daftar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

