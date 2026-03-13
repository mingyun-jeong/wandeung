import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'home_loading_screen.dart';
import 'login_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _iconController;
  late final AnimationController _textController;
  late final AnimationController _subtitleController;
  late final AnimationController _fadeOutController;

  late final Animation<double> _iconScale;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _fadeOut;

  bool _navigating = false;

  @override
  void initState() {
    super.initState();

    // Icon: scale up + fade in (0ms ~ 800ms)
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _iconScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeOutBack),
    );
    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeOut),
    );

    // App name: fade in + slide up (400ms ~ 1000ms)
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    // Subtitle: fade in (800ms ~ 1300ms)
    _subtitleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _subtitleController, curve: Curves.easeOut),
    );

    // Fade out transition
    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: Curves.easeIn),
    );

    _startAnimations();
  }

  void _startAnimations() async {
    // Staggered entrance
    _iconController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _subtitleController.forward();

    // Minimum splash duration: wait until at least 2.5s total
    await Future.delayed(const Duration(milliseconds: 1200));
    _tryNavigate();
  }

  void _tryNavigate() {
    if (_navigating || !mounted) return;
    _navigating = true;

    _fadeOutController.forward().then((_) {
      if (!mounted) return;
      final authState = ref.read(authProvider);
      final destination = authState.whenOrNull(
        data: (user) =>
            user != null ? const HomeLoadingScreen() : const LoginScreen(),
      );

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              destination ?? const LoginScreen(),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _iconController.dispose();
    _textController.dispose();
    _subtitleController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: AnimatedBuilder(
        animation: _fadeOutController,
        builder: (context, child) => Opacity(
          opacity: _fadeOut.value,
          child: child,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App icon with scale + fade
              AnimatedBuilder(
                animation: _iconController,
                builder: (context, child) => Opacity(
                  opacity: _iconOpacity.value,
                  child: Transform.scale(
                    scale: _iconScale.value,
                    child: child,
                  ),
                ),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // App name "완등"
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textOpacity,
                  child: const Text(
                    '완등',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle
              FadeTransition(
                opacity: _subtitleOpacity,
                child: Text(
                  '나만의 클라이밍 기록',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.6),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
