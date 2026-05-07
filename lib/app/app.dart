import 'package:flutter/material.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class ChoreMateApp extends StatelessWidget {
  const ChoreMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ChoreMate',
      theme: AppTheme.light,
      initialRoute: AppRouter.splash,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
