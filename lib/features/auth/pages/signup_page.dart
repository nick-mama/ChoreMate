import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/auth_repository.dart';

class SignupPage extends StatefulWidget {
  final AuthRepository auth;

  SignupPage({super.key, AuthRepository? auth}) : auth = auth ?? AuthService();

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
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
    firstNameController.dispose();
    lastNameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    FocusScope.of(context).unfocus();

    if (passwordController.text != confirmPasswordController.text) {
      setState(() {
        showError = true;
        errorMessage = 'Passwords do not match.';
      });
      return;
    }

    if (passwordController.text.length < 6) {
      setState(() {
        showError = true;
        errorMessage = 'Password must be at least 6 characters.';
      });
      return;
    }

    setState(() {
      loading = true;
      showError = false;
    });

    try {
      await _auth.signup(
        email: emailController.text.trim(),
        password: passwordController.text,
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        username: usernameController.text.trim(),
        phone: phoneController.text.trim(),
      );
      if (!mounted) return;
      // After signup, verify email → then household setup
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.verify,
        (route) => false,
      );
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
      case 'email-already-in-use':
        return 'An account with that email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
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

                    Center(
                      child: Image.asset(
                        AppAssets.logoWordmark,
                        width: 220,
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 32),

                    AppTextField(
                      controller: firstNameController,
                      hint: 'First Name',
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: lastNameController,
                      hint: 'Last Name',
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: usernameController,
                      hint: 'Username',
                    ),
                    const SizedBox(height: 14),
                    AppTextField(controller: emailController, hint: 'Email'),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: phoneController,
                      hint: 'Phone Number (optional)',
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: passwordController,
                      hint: 'Password',
                      obscureText: true,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: confirmPasswordController,
                      hint: 'Confirm Password',
                      obscureText: true,
                    ),
                    const SizedBox(height: 18),

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
                      label: loading ? 'Creating account...' : 'Sign Up',
                      onPressed: loading ? null : _signup,
                    ),

                    const SizedBox(height: 16),

                    SecondaryButton(
                      label: "Already have an account? Log In",
                      onPressed: () => Navigator.pop(context),
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
}
