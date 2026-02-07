import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'screens/home_screen.dart';
import 'services/walkthrough_service.dart';
import 'utils/walkthrough_keys.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Focus Overlay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: ShowCaseWidget(
        onComplete: (index, key) {
           // Handle homepage walkthrough completion
           if (key == WalkthroughKeys.permissionsCard) {
             WalkthroughService().markHomeWalkthroughComplete();
           }
           // Keep existing completion handlers
           if (key == WalkthroughKeys.settingsButton || 
               key == WalkthroughKeys.removeAppButton) {
             WalkthroughService().markWalkthroughComplete();
           }
        },
        builder: (context) => const HomeScreen(),
      ),
    );
  }
}
