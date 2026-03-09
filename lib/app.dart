import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/splash_screen.dart';

class WandeungApp extends ConsumerWidget {
  const WandeungApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: '완등',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF14B8A6),
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFB),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE8ECF0)),
          ),
          color: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xFFF8FAFB),
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: const Color(0xFF14B8A6).withOpacity(0.15),
          elevation: 0,
          height: 64,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE8ECF0),
          thickness: 1,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
