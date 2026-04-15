import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../../../app/router.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool showError = false;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _login() {
    FocusScope.of(context).unfocus(); // dismiss keyboard

    setState(() {
      showError = passwordController.text != "123456";
    });

    if (!showError) {
      Navigator.pushReplacementNamed(context, AppRouter.shell);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          FocusScope.of(context).unfocus(), // tap outside to close keyboard
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

                    AppTextField(
                      controller: usernameController,
                      hint: 'Username',
                    ),

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
                        onPressed: () {},
                        child: const Text('Forgot password?'),
                      ),
                    ),

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

                    PrimaryButton(label: 'Log In', onPressed: _login),

                    const SizedBox(height: 16),

                    SecondaryButton(
                      label: "Don’t have an account? Sign Up",
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
}
