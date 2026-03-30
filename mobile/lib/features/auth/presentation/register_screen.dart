import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../domain/auth_state.dart';

/// Register screen matching UI-SPEC:
///   - Same dark background and layout as Login
///   - Fields: Email, Password, Confirm Password, Device Name (pre-filled per D-17)
///   - Client-side validation: passwords match, password >= 8 chars
///   - "Create Account" CTA in accent color
///   - Error display below Confirm Password
///   - Link to Log In at bottom
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _validationError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return _emailController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty;
  }

  String? _validateForm() {
    if (_emailController.text.trim().isEmpty) {
      return 'Email is required';
    }
    if (_passwordController.text.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _onRegister() async {
    final validationError = _validateForm();
    if (validationError != null) {
      setState(() => _validationError = validationError);
      return;
    }

    setState(() => _validationError = null);

    final deviceName = Platform.localHostname;
    await ref.read(authStateProvider.notifier).register(
          _emailController.text.trim(),
          _passwordController.text,
          deviceName.isNotEmpty ? deviceName : 'My Phone',
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    // Show API error or local validation error
    final errorToShow = authState.error ?? _validationError;

    return Scaffold(
      backgroundColor: AppColors.loginBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxl),

                // Heading
                Text(
                  'Folip',
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.loginText,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.xl),

                // Email field
                _AuthTextField(
                  controller: _emailController,
                  hintText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: AppSpacing.md),

                // Password field
                _AuthTextField(
                  controller: _passwordController,
                  hintText: 'Password',
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: AppSpacing.md),

                // Confirm Password field
                _AuthTextField(
                  controller: _confirmPasswordController,
                  hintText: 'Confirm Password',
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                ),

                // Error message (validation or API)
                if (errorToShow != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    errorToShow,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.destructive,
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.md),

                // Create Account button
                Opacity(
                  opacity:
                      (!_canSubmit || authState.isLoading) ? 0.6 : 1.0,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed:
                          (!_canSubmit || authState.isLoading)
                              ? null
                              : _onRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.accent,
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        authState.isLoading
                            ? 'Creating account...'
                            : 'Create Account',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Login link
                GestureDetector(
                  onTap: () => context.go(AppRoutes.login),
                  child: Text.rich(
                    TextSpan(
                      text: 'Already have an account? ',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.loginText,
                      ),
                      children: [
                        TextSpan(
                          text: 'Log In',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable text field styled for the dark auth screens.
class _AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const _AuthTextField({
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.loginText,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
          filled: true,
          fillColor: AppColors.loginInputBg,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: const Color(0xFFB0AEA5).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: const Color(0xFFB0AEA5).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: const Color(0xFFB0AEA5).withValues(alpha: 0.6),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}
