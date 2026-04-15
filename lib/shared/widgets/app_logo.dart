import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';

enum LogoType { full, symbol, wordmark }

class AppLogo extends StatelessWidget {
  final LogoType type;
  final double width;

  const AppLogo({super.key, this.type = LogoType.full, this.width = 220});

  String _getAsset() {
    switch (type) {
      case LogoType.full:
        return AppAssets.logoFull;
      case LogoType.symbol:
        return AppAssets.logoSymbol;
      case LogoType.wordmark:
        return AppAssets.logoWordmark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(_getAsset(), width: width, fit: BoxFit.contain);
  }
}
