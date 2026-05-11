import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/router.dart';
import '../../../core/constants/app_assets.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/services/auth_service.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _auth = AuthService();
  bool loading = false;
  bool showError = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final verified = await _auth.checkEmailVerified();

      if (verified && mounted) {
        _pollingTimer?.cancel();
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRouter.splash,
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _goBack() async {
    _pollingTimer?.cancel();
    await _auth.logout();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRouter.login,
      (route) => false,
    );
  }

  Future<void> _resend() async {
    setState(() => loading = true);

    await _auth.sendVerificationEmail();

    if (!mounted) return;

    setState(() => loading = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Verification email resent.')));
  }

  Future<void> _checkManually() async {
    setState(() {
      loading = true;
      showError = false;
    });

    final verified = await _auth.checkEmailVerified();

    if (!mounted) return;

    if (verified) {
      _pollingTimer?.cancel();
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.splash,
        (route) => false,
      );
    } else {
      setState(() {
        loading = false;
        showError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) {
        if (!loading) _goBack();
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leadingWidth: 56,
            leading: IconButton(
              onPressed: loading ? null : _goBack,
              padding: const EdgeInsets.only(left: 8),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.black,
                size: 22,
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),

                      Center(
                        child: Image.asset(
                          AppAssets.logoWordmark,
                          width: 220,
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(height: 56),

                      const Text(
                        'Verify your email',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'We sent a verification link to your email. Click it and this screen will update automatically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, height: 1.4),
                      ),

                      const SizedBox(height: 28),

                      if (showError)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Email not verified yet. Please check your inbox.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red, fontSize: 15),
                          ),
                        ),

                      PrimaryButton(
                        label: loading
                            ? 'Checking...'
                            : "I've verified my email",
                        onPressed: loading ? null : _checkManually,
                      ),

                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: loading ? null : _resend,
                        child: const Text('Resend email'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
