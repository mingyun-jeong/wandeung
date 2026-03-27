import 'dart:async';
import 'dart:math' as math;
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
  late final AnimationController _dotController;
  bool _dataReady = false;
  bool _timerDone = false;
  bool _finishing = false;
  bool _done = false;

  static const _wallPainter = _WallTexturePainter();

  // 홀드 10개 색상 (아래→위, 쉬운→어려운)
  static const _holdColors = [
    Color(0xFFF48FB1), // 분홍
    Color(0xFFFF9800), // 주황
    Color(0xFFFFEB3B), // 노랑
    Color(0xFFFFEB3B), // 노랑
    Color(0xFF4CAF50), // 초록
    Color(0xFF4CAF50), // 초록
    Color(0xFF2196F3), // 파랑
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
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _checkEntryModeAndStart();
  }

  Future<void> _checkEntryModeAndStart() async {
    final prefs = await SharedPreferences.getInstance();
    final isCameraEntry = prefs.getBool('entry_mode_camera') ?? false;
    if (isCameraEntry) {
      // 촬영 모드 진입 시 로딩 애니메이션 건너뜀
      ref.read(bottomNavIndexProvider.notifier).state = 2;
      if (mounted) setState(() => _done = true);
      return;
    }

    // 일반 모드: 로딩 애니메이션 시작
    _progressController.forward();
    _pulseController.repeat(reverse: true);
    _dotController.repeat();

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

  void _applyEntryModeAndFinish() {
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(userStatsProvider);
    final records = ref.watch(recentRecordsProvider);
    final gyms = ref.watch(recentGymsProvider);

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
              painter: _wallPainter,
            ),
          ),
          // 전체 화면 클라이밍 애니메이션
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _progressController,
                _pulseController,
              ]),
              builder: (context, _) {
                return CustomPaint(
                  painter: _ClimbingScenePainter(
                    progress: _progressController.value,
                    pulseValue: _pulseController.value,
                    holdColors: _holdColors,
                  ),
                );
              },
            ),
          ),
          // 하단 앱 이름 + 로딩 텍스트
          Positioned(
            left: 0,
            right: 0,
            bottom: 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '리클림',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: ReclimColors.primary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _dotController,
                  builder: (context, _) {
                    final dotCount = (_dotController.value * 3).floor() + 1;
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
                  backgroundColor: const Color(0x14E94560),
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
  const _WallTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8E8E8)
      ..style = PaintingStyle.fill;

    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
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

/// 전체 화면 클라이밍 씬: 홀드 + 경로 + 클라이머 캐릭터
class _ClimbingScenePainter extends CustomPainter {
  final double progress;
  final double pulseValue;
  final List<Color> holdColors;

  _ClimbingScenePainter({
    required this.progress,
    required this.pulseValue,
    required this.holdColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final holdCount = holdColors.length;
    const holdRadius = 14.0;

    // 홀드 영역: 상단 12%~하단 65% (하단에 텍스트 공간 확보)
    final topMargin = size.height * 0.12;
    final bottomMargin = size.height * 0.35;
    final climbHeight = size.height - topMargin - bottomMargin;
    final verticalSpacing = climbHeight / (holdCount - 1);

    // 홀드 좌표 계산 (아래→위, 자연스러운 지그재그)
    final centerX = size.width / 2;
    final holds = <Offset>[];
    // 고정된 시드로 일관된 홀드 배치
    final rng = math.Random(42);
    for (int i = 0; i < holdCount; i++) {
      final y = size.height - bottomMargin - (i * verticalSpacing);
      // 지그재그 + 약간의 랜덤성으로 실제 루트 느낌
      final baseOffset = (i.isEven ? -1 : 1) * (size.width * 0.12);
      final randomOffset = (rng.nextDouble() - 0.5) * (size.width * 0.08);
      holds.add(Offset(centerX + baseOffset + randomOffset, y));
    }

    final litCount = (progress * holdCount).ceil().clamp(0, holdCount);
    final activeIndex = litCount > 0 ? litCount - 1 : -1;

    // 경로선 (점선 느낌의 얇은 선)
    if (litCount > 1) {
      final pathPaint = Paint()
        ..color = const Color(0x20E94560)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      final path = Path()..moveTo(holds[0].dx, holds[0].dy);
      for (int i = 1; i < litCount; i++) {
        // 부드러운 곡선 경로
        final prev = holds[i - 1];
        final curr = holds[i];
        final midY = (prev.dy + curr.dy) / 2;
        path.cubicTo(prev.dx, midY, curr.dx, midY, curr.dx, curr.dy);
      }
      canvas.drawPath(path, pathPaint);
    }

    // 모든 홀드 그리기
    for (int i = 0; i < holdCount; i++) {
      final center = holds[i];
      final isLit = i < litCount;
      final isActive = i == activeIndex;

      if (isLit) {
        // 그림자
        canvas.drawCircle(
          center.translate(0, 2),
          holdRadius,
          Paint()..color = holdColors[i].withOpacity(0.2),
        );

        // 활성 홀드 글로우
        if (isActive) {
          final glowRadius = holdRadius + 4 + (pulseValue * 6);
          canvas.drawCircle(
            center,
            glowRadius,
            Paint()..color = holdColors[i].withOpacity(0.12 + pulseValue * 0.08),
          );
        }

        _drawHold(canvas, center, holdRadius, holdColors[i]);
      } else {
        _drawHold(canvas, center, holdRadius, const Color(0xFFD8D8D8));
      }
    }

    // 클라이머 캐릭터 그리기
    if (litCount > 0) {
      _drawClimber(canvas, holds, activeIndex, litCount, holdRadius);
    }
  }

  void _drawHold(Canvas canvas, Offset center, double radius, Color color) {
    final rect = Rect.fromCenter(
      center: center,
      width: radius * 2.2,
      height: radius * 1.8,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius * 0.7));

    canvas.drawRRect(rrect, Paint()..color = color);

    // 하이라이트
    final highlightRect = Rect.fromCenter(
      center: center.translate(-2, -2),
      width: radius * 1.2,
      height: radius * 0.9,
    );
    canvas.drawOval(highlightRect, Paint()..color = const Color(0x4DFFFFFF));

    // 볼트 구멍
    canvas.drawCircle(
      center.translate(0, 1),
      2.5,
      Paint()..color = const Color(0x80FFFFFF),
    );
  }

  void _drawClimber(
    Canvas canvas,
    List<Offset> holds,
    int activeIndex,
    int litCount,
    double holdRadius,
  ) {
    final currentHold = holds[activeIndex];
    final nextHold =
        activeIndex + 1 < holds.length ? holds[activeIndex + 1] : null;
    final isTop = nextHold == null;

    // 졸라맨 비율: 큰 동그란 머리 + 짧은 몸 + 짧은 팔다리
    const headR = 10.0;
    const bodyLen = 20.0;
    const limbLen = 16.0;
    const strokeW = 2.5;

    // 잡는 손 위치 (홀드 바로 아래)
    final gripX = currentHold.dx;
    final gripY = currentHold.dy + holdRadius * 0.6;

    // 몸 중심은 잡는 손 아래
    final bodyTopY = gripY + 6;
    final bodyBottomY = bodyTopY + bodyLen;
    // 몸이 홀드 쪽으로 약간 기울어짐
    final bodyX = gripX;

    // 머리 위치 (몸통 위)
    final headCenter = Offset(bodyX, bodyTopY - headR - 2);

    final linePaint = Paint()
      ..color = ReclimColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = ReclimColors.primary
      ..style = PaintingStyle.fill;

    // === 머리 (큰 원 — 졸라맨 특징) ===
    // 흰 배경 원
    canvas.drawCircle(
      headCenter,
      headR,
      Paint()..color = Colors.white,
    );
    // 테두리
    canvas.drawCircle(headCenter, headR, linePaint);
    // 눈 (점 두 개)
    canvas.drawCircle(
      headCenter.translate(-3.5, -1),
      1.5,
      fillPaint,
    );
    canvas.drawCircle(
      headCenter.translate(3.5, -1),
      1.5,
      fillPaint,
    );

    if (isTop) {
      // 꼭대기 도달 — 활짝 웃는 입
      canvas.drawArc(
        Rect.fromCenter(center: headCenter.translate(0, 3), width: 8, height: 6),
        0,
        math.pi,
        false,
        linePaint..strokeWidth = 1.5,
      );
      linePaint.strokeWidth = strokeW;
    } else {
      // 등반 중 — 일자 입
      canvas.drawLine(
        headCenter.translate(-3, 3),
        headCenter.translate(3, 3),
        linePaint..strokeWidth = 1.5,
      );
      linePaint.strokeWidth = strokeW;
    }

    // === 몸통 (짧은 직선) ===
    canvas.drawLine(
      Offset(bodyX, bodyTopY),
      Offset(bodyX, bodyBottomY),
      linePaint,
    );

    if (isTop) {
      // === 꼭대기 만세 포즈 ===
      // 양팔 위로 \o/
      canvas.drawLine(
        Offset(bodyX, bodyTopY + 4),
        Offset(bodyX - 14, bodyTopY - 10),
        linePaint,
      );
      canvas.drawLine(
        Offset(bodyX, bodyTopY + 4),
        Offset(bodyX + 14, bodyTopY - 10),
        linePaint,
      );
      // 다리 — 벌리고 서기
      canvas.drawLine(
        Offset(bodyX, bodyBottomY),
        Offset(bodyX - 10, bodyBottomY + limbLen),
        linePaint,
      );
      canvas.drawLine(
        Offset(bodyX, bodyBottomY),
        Offset(bodyX + 10, bodyBottomY + limbLen),
        linePaint,
      );
    } else {
      // === 등반 포즈 ===
      // 팔1: 현재 홀드를 잡고 있음
      canvas.drawLine(
        Offset(bodyX, bodyTopY + 4),
        Offset(gripX, gripY),
        linePaint,
      );

      // 팔2: 다음 홀드를 향해 뻗음 (펄스로 움직임)
      final reachT = 0.35 + pulseValue * 0.25;
      final targetX = nextHold.dx;
      final targetY = nextHold.dy + holdRadius * 0.6;
      final reachX = bodyX + (targetX - bodyX) * reachT;
      final reachY = bodyTopY + 4 + (targetY - (bodyTopY + 4)) * reachT;
      canvas.drawLine(
        Offset(bodyX, bodyTopY + 4),
        Offset(reachX, reachY),
        linePaint,
      );

      // 다리: 자연스럽게 아래로 벌림
      canvas.drawLine(
        Offset(bodyX, bodyBottomY),
        Offset(bodyX - 10, bodyBottomY + limbLen),
        linePaint,
      );
      canvas.drawLine(
        Offset(bodyX, bodyBottomY),
        Offset(bodyX + 10, bodyBottomY + limbLen),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ClimbingScenePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.pulseValue != pulseValue;
}
