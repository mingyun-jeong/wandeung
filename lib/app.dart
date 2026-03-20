import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/splash_screen.dart';

/// 클림픽 앱 컬러 상수
class ClimpickColors {
  ClimpickColors._();

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

class ClimpickApp extends ConsumerWidget {
  const ClimpickApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: '클림픽',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: ClimpickColors.accent,
          brightness: Brightness.light,
          primary: ClimpickColors.accent,
          onPrimary: Colors.white,
          secondary: ClimpickColors.secondary,
          surface: ClimpickColors.surface,
          onSurface: ClimpickColors.textPrimary,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: ClimpickColors.surface,
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: ClimpickColors.border),
          ),
          color: ClimpickColors.card,
        ),
        appBarTheme: const AppBarTheme(
          scrolledUnderElevation: 0,
          backgroundColor: ClimpickColors.surface,
          surfaceTintColor: Colors.transparent,
          foregroundColor: ClimpickColors.textPrimary,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: ClimpickColors.accent.withOpacity(0.12),
          elevation: 0,
          height: 64,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: ClimpickColors.accent);
            }
            return const IconThemeData(color: ClimpickColors.textSecondary);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ClimpickColors.accent,
              );
            }
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: ClimpickColors.textSecondary,
            );
          }),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: ClimpickColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: ClimpickColors.accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        dialogTheme: const DialogTheme(
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
          color: ClimpickColors.border,
          thickness: 1,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: ClimpickColors.accent,
          foregroundColor: Colors.white,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
