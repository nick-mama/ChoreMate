import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/signup_page.dart';
import '../features/auth/pages/splash_page.dart';
import '../features/auth/pages/verify_code_page.dart';
import '../features/household/pages/household_setup_page.dart';
import '../shared/widgets/main_shell.dart';

class AppRouter {
  static const splash = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const verify = '/verify';
  static const householdSetup = '/household-setup';
  static const shell = '/shell';

  static Future<String> getInitialRoute() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return login;
    if (!user.emailVerified) return verify;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final householdId = doc.data()?['householdId'];
    if (householdId == null || householdId.isEmpty) return householdSetup;

    return shell;
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashPage());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case signup:
        return MaterialPageRoute(builder: (_) => const SignupPage());
      case verify:
        return MaterialPageRoute(builder: (_) => const VerifyCodePage());
      case householdSetup:
        return MaterialPageRoute(builder: (_) => const HouseholdSetupPage());
      case shell:
        return MaterialPageRoute(builder: (_) => const MainShell());
      default:
        return MaterialPageRoute(builder: (_) => const SplashPage());
    }
  }
}
