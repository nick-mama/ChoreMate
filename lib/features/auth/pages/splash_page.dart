import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/household_service.dart';
import '../../../shared/widgets/app_logo.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  double progress = 0.0;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();

    _progressTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      setState(() {
        progress += 0.02;
        if (progress >= 1) {
          progress = 1;
          timer.cancel();
          Future.delayed(const Duration(milliseconds: 250), _navigate);
        }
      });
    });
  }

  Future<void> _navigate() async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.pushReplacementNamed(context, AppRouter.login);
      return;
    }

    await user.reload();
    if (!mounted) return;
    if (!user.emailVerified) {
      Navigator.pushReplacementNamed(context, AppRouter.verify);
      return;
    }

    final householdId = await HouseholdService().getCurrentHouseholdId();
    if (!mounted) return;

    if (householdId == null) {
      // No household yet → setup
      Navigator.pushReplacementNamed(context, AppRouter.householdSetup);
    } else {
      // Everything good → shell
      Navigator.pushReplacementNamed(context, AppRouter.shell);
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const AppLogo(type: LogoType.full, width: 260),
              const SizedBox(height: 48),
              const Spacer(flex: 3),
              Container(
                height: 22,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.tan,
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.all(4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress.clamp(0, 1),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
