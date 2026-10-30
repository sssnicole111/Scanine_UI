import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';
import 'theme/tokens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Enable edge-to-edge so content draws behind the system bars.
  // Each screen uses a bottom padding equal to MediaQuery.viewPadding.bottom
  // so interactive elements are never hidden behind the navigation bar.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
        fontFamily: 'InstrumentSans',
        scaffoldBackgroundColor: T.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: T.navy,
          primary: T.navy,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
