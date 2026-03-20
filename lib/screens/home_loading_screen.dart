import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app.dart';
import '../providers/camera_settings_provider.dart';
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
  late final AnimationController _pulseController;
  bool _dataReady = false;
  bool _timerDone = false;
  bool _finishing = false;
  bool _done = false;

  // 홀드 7개 색상 (아래→위, 쉬운→어려운 느낌)
  static const _holdColors = [
    Color(0xFFF48FB1), // 분홍
    Color(0xFFFF9800), // 주황
    Color(0xFFFFEB3B), // 노랑
    Color(0xFF4CAF50), // 초록
    Color(0xFF2196F3), // 파랑
    Color(0xFF9C27B0), // 보라
    Color(0xFFE94560), // Climbing Red (top!)
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

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
    _pulseController.dispose();
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
              if (mounted) _applyEntryModeAndFinish();
            });
          }
        });
      } else {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _applyEntryModeAndFinish();
        });
      }
    }
  }

  Future<void> _applyEntryModeAndFinish() async {
    final prefs = await SharedPreferences.getInstance();
    final isCameraEntry = prefs.getBool('entry_mode_camera') ?? false;
    if (isCameraEntry) {
      ref.read(bottomNavIndexProvider.notifier).state = 2;
    }
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 벽 질감 배경
          Positioned.fill(
            child: CustomPaint(
              painter: _WallTexturePainter(),
            ),
          ),
          // 메인 콘텐츠
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 클라이밍 루트 애니메이션
                SizedBox(
                  width: 160,
                  height: 220,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _progressController,
                      _pulseController,
                    ]),
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _ClimbingRoutePainter(
                          progress: _progressController.value,
                          pulseValue: _pulseController.value,
                          holdColors: _holdColors,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
                // 앱 이름
                const Text(
                  '리클림',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: ReclimColors.primary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                // 등반 준비중 텍스트
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final dotCount =
                        ((_pulseController.value * 3).floor() % 3) + 1;
                    final dots = '.' * dotCount;
                    return Text(
                      '등반 준비중$dots',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: ReclimColors.textSecondary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // 하단 프로그레스 바
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (context, _) {
                return LinearProgressIndicator(
                  value: _progressController.value,
                  minHeight: 3,
                  backgroundColor: ReclimColors.accent.withOpacity(0.08),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    ReclimColors.accent,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 미세한 클라이밍 벽 질감 (점 패턴)
class _WallTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8E8E8)
      ..style = PaintingStyle.fill;

    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // 약간의 오프셋으로 자연스러운 느낌
        final offsetX = (y ~/ spacing).isOdd ? spacing / 2 : 0.0;
        canvas.drawCircle(
          Offset(x + offsetX, y),
          1.2,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 클라이밍 루트 — 홀드가 지그재그로 올라가며 점등
class _ClimbingRoutePainter extends CustomPainter {
  final double progress;
  final double pulseValue;
  final List<Color> holdColors;

  _ClimbingRoutePainter({
    required this.progress,
    required this.pulseValue,
    required this.holdColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final holdCount = holdColors.length;
    const holdRadius = 14.0;
    final verticalSpacing = (size.height - holdRadius * 2) / (holdCount - 1);

    // 홀드 좌표 계산 (아래→위, 지그재그)
    final holds = <Offset>[];
    for (int i = 0; i < holdCount; i++) {
      final y = size.height - holdRadius - (i * verticalSpacing);
      final xCenter = size.width / 2;
      final xOffset = (i.isEven ? -1 : 1) * 30.0;
      holds.add(Offset(xCenter + xOffset, y));
    }

    // 현재 진행에 따라 점등된 홀드 수
    final litCount = (progress * holdCount).ceil().clamp(0, holdCount);
    // 현재 활성 홀드 인덱스 (펄스 효과 대상)
    final activeIndex = litCount > 0 ? litCount - 1 : -1;

    // 경로선 그리기 (점등된 홀드 사이)
    if (litCount > 1) {
      final pathPaint = Paint()
        ..color = ReclimColors.accent.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      final path = Path()..moveTo(holds[0].dx, holds[0].dy);
      for (int i = 1; i < litCount; i++) {
        path.lineTo(holds[i].dx, holds[i].dy);
      }
      canvas.drawPath(path, pathPaint);
    }

    // 홀드 그리기
    for (int i = 0; i < holdCount; i++) {
      final center = holds[i];
      final isLit = i < litCount;
      final isActive = i == activeIndex;

      if (isLit) {
        // 점등된 홀드 — 그림자
        canvas.drawCircle(
          center.translate(0, 2),
          holdRadius,
          Paint()..color = holdColors[i].withOpacity(0.25),
        );

        // 활성 홀드 — 펄스 글로우
        if (isActive) {
          final glowRadius = holdRadius + 4 + (pulseValue * 6);
          canvas.drawCircle(
            center,
            glowRadius,
            Paint()..color = holdColors[i].withOpacity(0.15 + pulseValue * 0.1),
          );
        }

        // 홀드 본체
        _drawHold(canvas, center, holdRadius, holdColors[i]);
      } else {
        // 미점등 홀드 — 회색 반투명
        _drawHold(canvas, center, holdRadius, const Color(0xFFD0D0D0));
      }
    }
  }

  void _drawHold(Canvas canvas, Offset center, double radius, Color color) {
    // 홀드 모양: 약간 불규칙한 타원 (실제 홀드 느낌)
    final rect = Rect.fromCenter(
      center: center,
      width: radius * 2.2,
      height: radius * 1.8,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius * 0.7));

    // 홀드 본체
    canvas.drawRRect(
      rrect,
      Paint()..color = color,
    );

    // 하이라이트 (입체감)
    final highlightRect = Rect.fromCenter(
      center: center.translate(-2, -2),
      width: radius * 1.2,
      height: radius * 0.9,
    );
    canvas.drawOval(
      highlightRect,
      Paint()..color = Colors.white.withOpacity(0.3),
    );

    // 볼트 구멍 (홀드 중앙)
    canvas.drawCircle(
      center.translate(0, 1),
      2.5,
      Paint()..color = Colors.white.withOpacity(0.5),
    );
  }

  @override
  bool shouldRepaint(covariant _ClimbingRoutePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.pulseValue != pulseValue;
}
