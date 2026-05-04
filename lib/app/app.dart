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
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: FutureBuilder<String>(
        future: AppRouter.getInitialRoute(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return Navigator(
            onGenerateRoute: (settings) =>
                AppRouter.onGenerateRoute(RouteSettings(name: snapshot.data)),
          );
        },
      ),
    );
  }
}
