import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../domain/auth_state.dart';

/// Login screen matching UI-SPEC:
///   - Full-screen dark background (#141413)
///   - Email, Password, and Device Name fields
///   - Device Name pre-filled with "My Phone" (per D-17, editable)
///   - "Log In" CTA in accent color
///   - Error display below password field
///   - Link to Register at bottom
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deviceNameController = TextEditingController(text: 'My Phone');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return _emailController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty;
  }

  Future<void> _onLogin() async {
    await ref.read(authStateProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
          _deviceNameController.text.trim().isNotEmpty
              ? _deviceNameController.text.trim()
              : 'My Phone',
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

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

                // Error message
                if (authState.error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    authState.error!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.destructive,
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.md),

                // Device name label + field
                Text(
                  'Device name',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _AuthTextField(
                  controller: _deviceNameController,
                  hintText: 'My Phone',
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: AppSpacing.md),

                // Log In button
                Opacity(
                  opacity:
                      (!_canSubmit || authState.isLoading) ? 0.6 : 1.0,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed:
                          (!_canSubmit || authState.isLoading)
                              ? null
                              : _onLogin,
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
                        authState.isLoading ? 'Logging in...' : 'Log In',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Register link
                GestureDetector(
                  onTap: () => context.go(AppRoutes.register),
                  child: Text.rich(
                    TextSpan(
                      text: 'No account? ',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.loginText,
                      ),
                      children: [
                        TextSpan(
                          text: 'Register',
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
