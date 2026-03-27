import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/splash_screen.dart';

/// 리클림 앱 컬러 상수
class ReclimColors {
  ReclimColors._();

  static const primary = Color(0xFF1A1A2E);       // Deep Navy
  static const accent = Color(0xFFE94560);         // Climbing Red
  static const accentLight = Color(0xFFFF6B6B);    // Light Red
  static const secondary = Color(0xFF0F3460);      // Mid Navy
  static const success = Color(0xFF16C784);        // 완등 Green
  static const inProgress = Color(0xFFF5A623);     // 도전중 Amber
  static const surface = Color(0xFFF5F5F7);        // Warm Gray BG
  static const card = Colors.white;
  static const border = Color(0xFFE8ECF0);
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);
}

class ReclimApp extends ConsumerWidget {
  const ReclimApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: '리클림',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: ReclimColors.accent,
          brightness: Brightness.light,
          primary: ReclimColors.accent,
          onPrimary: Colors.white,
          secondary: ReclimColors.secondary,
          surface: ReclimColors.surface,
          onSurface: ReclimColors.textPrimary,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: ReclimColors.surface,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: ReclimColors.border),
          ),
          color: ReclimColors.card,
        ),
        appBarTheme: const AppBarTheme(
          scrolledUnderElevation: 0,
          backgroundColor: ReclimColors.surface,
          surfaceTintColor: Colors.transparent,
          foregroundColor: ReclimColors.textPrimary,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: ReclimColors.accent.withOpacity(0.12),
          elevation: 0,
          height: 64,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: ReclimColors.accent);
            }
            return const IconThemeData(color: ReclimColors.textSecondary);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ReclimColors.accent,
              );
            }
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: ReclimColors.textSecondary,
            );
          }),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: ReclimColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: ReclimColors.accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        dividerTheme: const DividerThemeData(
          color: ReclimColors.border,
          thickness: 1,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: ReclimColors.accent,
          foregroundColor: Colors.white,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
