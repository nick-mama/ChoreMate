import 'package:flutter/material.dart';
import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/signup_page.dart';
import '../features/auth/pages/splash_page.dart';
import '../features/auth/pages/verify_code_page.dart';
import '../shared/widgets/main_shell.dart';

class AppRouter {
  static const splash = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const verify = '/verify';
  static const shell = '/shell';

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
      case shell:
        return MaterialPageRoute(builder: (_) => const MainShell());
      default:
        return MaterialPageRoute(builder: (_) => const SplashPage());
    }
  }
}
