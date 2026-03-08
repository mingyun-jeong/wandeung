import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/record_provider.dart';
import 'main_shell_screen.dart';

class HomeLoadingScreen extends ConsumerStatefulWidget {
  const HomeLoadingScreen({super.key});

  @override
  ConsumerState<HomeLoadingScreen> createState() => _HomeLoadingScreenState();
}

class _HomeLoadingScreenState extends ConsumerState<HomeLoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _progressController;
  late final AnimationController _dotController;
  bool _dataReady = false;
  bool _timerDone = false;
  bool _finishing = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _timerDone = true);
        _tryFinish();
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  void _tryFinish() {
    if (_finishing) return;
    if (_dataReady || _timerDone) {
      _finishing = true;
      final remaining = 1.0 - _progressController.value;
      if (remaining > 0.01) {
        _progressController.duration = const Duration(milliseconds: 300);
        _progressController.forward(from: _progressController.value).then((_) {
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) setState(() => _done = true);
            });
          }
        });
      } else {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _done = true);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Watch providers to trigger data fetching in the background
    final stats = ref.watch(userStatsProvider);
    final records = ref.watch(recentRecordsProvider);
    final gyms = ref.watch(recentGymsProvider);

    // Check if all data is loaded
    final allLoaded = stats.hasValue && records.hasValue && gyms.hasValue;
    if (allLoaded && !_dataReady) {
      _dataReady = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryFinish());
    }

    if (_done) {
      return const MainShellScreen();
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _dotController,
                builder: (context, _) {
                  // 0.0~1.0 -> 1~5 dots, then 5~1 dots
                  final v = _dotController.value;
                  final dotCount = v < 0.5
                      ? (1 + (v * 2 * 4)).round()
                      : (5 - ((v - 0.5) * 2 * 4)).round();
                  final dots = '.' * dotCount.clamp(1, 5);
                  return Text(
                    'Loading$dots',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, _) {
                    return LinearProgressIndicator(
                      value: _progressController.value,
                      minHeight: 4,
                      backgroundColor:
                          colorScheme.primary.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
