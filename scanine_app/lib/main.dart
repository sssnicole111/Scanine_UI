import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'debug/mlkit_eval_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/tokens.dart';

// Evaluation-only entry: flutter run --dart-define=MLKIT_EVAL=true
const _mlkitEval = bool.fromEnvironment('MLKIT_EVAL');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Enable edge-to-edge so UI extends smoothly behind status bar and notches
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

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
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: T.navy,
          primary: T.navy,
        ),
      ),
      home: _mlkitEval ? const MlkitEvalScreen() : const SplashScreen(),
    );
  }
}
