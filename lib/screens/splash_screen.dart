import 'package:flutter/material.dart';
import '../theme/routes.dart';
import 'scanine_splash.dart';
import 'home_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScanineSplash(
      onFinished: () {
        AppRoutes.pushReplacement(context, (_) => const HomeScreen());
      },
    );
  }
}
