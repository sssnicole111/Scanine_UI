import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'theme/tokens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ScanineApp());
}

class ScanineApp extends StatelessWidget {
  const ScanineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scanine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: T.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: T.navy,
          primary: T.navy,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
