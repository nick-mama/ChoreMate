import 'package:flutter/material.dart';
import '../../../app/router.dart';
import '../../../core/constants/app_assets.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';

class VerifyCodePage extends StatefulWidget {
  const VerifyCodePage({super.key});

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final codeController = TextEditingController();

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  void _verify() {
    FocusScope.of(context).unfocus();
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRouter.shell,
      (route) => false,
    );
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
                    const SizedBox(height: 24),

                    Center(
                      child: Image.asset(
                        AppAssets.logoWordmark,
                        width: 220,
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 56),

                    const Text(
                      'Enter Code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Please enter the 6 digit code we sent to your email address.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, height: 1.4),
                    ),

                    const SizedBox(height: 28),

                    AppTextField(controller: codeController, hint: 'Code'),

                    const SizedBox(height: 24),

                    PrimaryButton(label: 'Verify', onPressed: _verify),
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
