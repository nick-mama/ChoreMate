import 'package:flutter/material.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

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

  bool showError = false;

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

  void _signup() {
    FocusScope.of(context).unfocus();

    setState(() {
      showError =
          passwordController.text != confirmPasswordController.text ||
          passwordController.text.length < 6;
    });

    if (!showError) {
      Navigator.pushNamed(context, AppRouter.verify);
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
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Invalid password. Please try again.',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    PrimaryButton(label: 'Sign Up', onPressed: _signup),
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
