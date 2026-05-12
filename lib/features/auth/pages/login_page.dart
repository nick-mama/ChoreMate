import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../../../app/router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/auth_repository.dart';

class LoginPage extends StatefulWidget {
  final AuthRepository auth;

  LoginPage({super.key, AuthRepository? auth}) : auth = auth ?? AuthService();

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  late final AuthRepository _auth;

  bool showError = false;
  String errorMessage = '';
  bool loading = false;
  @override
  void initState() {
    super.initState();
    _auth = widget.auth;
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    setState(() {
      loading = true;
      showError = false;
    });

    try {
      await _auth.login(emailController.text.trim(), passwordController.text);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.splash);
    } on FirebaseAuthException catch (e) {
      setState(() {
        showError = true;
        errorMessage = _friendlyError(e.code);
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    const Center(
                      child: AppLogo(type: LogoType.wordmark, width: 220),
                    ),

                    const SizedBox(height: 40),

                    AppTextField(controller: emailController, hint: 'Email'),

                    const SizedBox(height: 16),

                    AppTextField(
                      controller: passwordController,
                      hint: 'Password',
                      obscureText: true,
                    ),

                    const SizedBox(height: 10),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPassword,
                        child: const Text('Forgot password?'),
                      ),
                    ),

                    if (showError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          errorMessage,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    PrimaryButton(
                      label: loading ? 'Logging in...' : 'Log In',
                      onPressed: loading ? null : _login,
                    ),

                    const SizedBox(height: 16),

                    SecondaryButton(
                      label: "Don't have an account? Sign Up",
                      onPressed: () {
                        Navigator.pushNamed(context, AppRouter.signup);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPassword() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: AppTextField(controller: controller, hint: 'Email'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _auth.sendPasswordResetEmail(controller.text.trim());
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password reset email sent.')),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
