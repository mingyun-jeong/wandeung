import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/video_editor_provider.dart';

/// 크롭 줌 오버레이 — 드래그 가능한 크롭 사각형 + 딤 처리
class CropOverlay extends ConsumerStatefulWidget {
  final Size previewSize;

  const CropOverlay({super.key, required this.previewSize});

  @override
  ConsumerState<CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends ConsumerState<CropOverlay> {
  static const _handleSize = 20.0;
  static const _minCropFraction = 0.1; // 최소 10%

  _DragHandle? _activeHandle;
  Offset? _dragStart;
  Rect? _startRect;

  @override
  Widget build(BuildContext context) {
    final segments = ref.watch(cropSegmentsProvider);
    final selectedIdx = ref.watch(selectedCropSegmentProvider);
    final idx = selectedIdx ?? (segments.length == 1 ? 0 : null);

    if (idx == null || idx >= segments.length) {
      return const SizedBox.shrink();
    }

    final cropRect = segments[idx].cropRect;
    final w = widget.previewSize.width;
    final h = widget.previewSize.height;

    // 크롭 영역을 픽셀 좌표로 변환
    final left = cropRect.left * w;
    final top = cropRect.top * h;
    final cropW = cropRect.width * w;
    final cropH = cropRect.height * h;
    final pixelRect = Rect.fromLTWH(left, top, cropW, cropH);

    return SizedBox(
      width: w,
      height: h,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (d) => _onPanStart(d, pixelRect),
        onPanUpdate: (d) => _onPanUpdate(d, idx, w, h),
        onPanEnd: (_) => _onPanEnd(),
        child: CustomPaint(
          painter: _CropPainter(pixelRect: pixelRect),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  void _onPanStart(DragStartDetails details, Rect pixelRect) {
    final pos = details.localPosition;
    _activeHandle = _hitTestHandle(pos, pixelRect);
    _dragStart = pos;
    _startRect = pixelRect;
  }

  void _onPanUpdate(DragUpdateDetails details, int idx, double w, double h) {
    if (_startRect == null || _dragStart == null) return;

    final dx = details.localPosition.dx - _dragStart!.dx;
    final dy = details.localPosition.dy - _dragStart!.dy;
    final sr = _startRect!;

    Rect newPixelRect;
    if (_activeHandle == null) {
      // 전체 이동
      var newLeft = (sr.left + dx).clamp(0.0, w - sr.width);
      var newTop = (sr.top + dy).clamp(0.0, h - sr.height);
      newPixelRect = Rect.fromLTWH(newLeft, newTop, sr.width, sr.height);
    } else {
      newPixelRect = _resizeRect(sr, _activeHandle!, dx, dy, w, h);
    }

    // 정규화 좌표로 변환
    final normalized = Rect.fromLTWH(
      newPixelRect.left / w,
      newPixelRect.top / h,
      newPixelRect.width / w,
      newPixelRect.height / h,
    );

    ref.read(cropSegmentsProvider.notifier).updateCropRect(idx, normalized);
  }

  void _onPanEnd() {
    _activeHandle = null;
    _dragStart = null;
    _startRect = null;
  }

  Rect _resizeRect(
      Rect sr, _DragHandle handle, double dx, double dy, double w, double h) {
    var left = sr.left;
    var top = sr.top;
    var right = sr.right;
    var bottom = sr.bottom;
    final minW = w * _minCropFraction;
    final minH = h * _minCropFraction;

    if (handle == _DragHandle.topLeft ||
        handle == _DragHandle.left ||
        handle == _DragHandle.bottomLeft) {
      left = (sr.left + dx).clamp(0.0, right - minW);
    }
    if (handle == _DragHandle.topRight ||
        handle == _DragHandle.right ||
        handle == _DragHandle.bottomRight) {
      right = (sr.right + dx).clamp(left + minW, w);
    }
    if (handle == _DragHandle.topLeft ||
        handle == _DragHandle.top ||
        handle == _DragHandle.topRight) {
      top = (sr.top + dy).clamp(0.0, bottom - minH);
    }
    if (handle == _DragHandle.bottomLeft ||
        handle == _DragHandle.bottom ||
        handle == _DragHandle.bottomRight) {
      bottom = (sr.bottom + dy).clamp(top + minH, h);
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  _DragHandle? _hitTestHandle(Offset pos, Rect rect) {
    const r = _handleSize;
    if ((pos - rect.topLeft).distance < r) return _DragHandle.topLeft;
    if ((pos - rect.topRight).distance < r) return _DragHandle.topRight;
    if ((pos - rect.bottomLeft).distance < r) return _DragHandle.bottomLeft;
    if ((pos - rect.bottomRight).distance < r) return _DragHandle.bottomRight;
    if ((pos - Offset(rect.left, rect.center.dy)).distance < r) {
      return _DragHandle.left;
    }
    if ((pos - Offset(rect.right, rect.center.dy)).distance < r) {
      return _DragHandle.right;
    }
    if ((pos - Offset(rect.center.dx, rect.top)).distance < r) {
      return _DragHandle.top;
    }
    if ((pos - Offset(rect.center.dx, rect.bottom)).distance < r) {
      return _DragHandle.bottom;
    }
    if (rect.contains(pos)) return null; // 내부 드래그 = 이동
    return null;
  }
}

enum _DragHandle { topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left }

class _CropPainter extends CustomPainter {
  final Rect pixelRect;

  _CropPainter({required this.pixelRect});

  @override
  void paint(Canvas canvas, Size size) {
    // 딤 처리 (크롭 영역 바깥)
    final dimPaint = Paint()..color = Colors.black.withOpacity(0.5);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRect(pixelRect),
      ),
      dimPaint,
    );

    // 크롭 테두리
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(pixelRect, borderPaint);

    // 3등분 격자선
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (int i = 1; i < 3; i++) {
      final x = pixelRect.left + pixelRect.width * i / 3;
      canvas.drawLine(Offset(x, pixelRect.top), Offset(x, pixelRect.bottom), gridPaint);
      final y = pixelRect.top + pixelRect.height * i / 3;
      canvas.drawLine(Offset(pixelRect.left, y), Offset(pixelRect.right, y), gridPaint);
    }

    // 8개 핸들
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    const hs = 6.0; // 핸들 반지름

    final handles = [
      pixelRect.topLeft,
      Offset(pixelRect.center.dx, pixelRect.top),
      pixelRect.topRight,
      Offset(pixelRect.right, pixelRect.center.dy),
      pixelRect.bottomRight,
      Offset(pixelRect.center.dx, pixelRect.bottom),
      pixelRect.bottomLeft,
      Offset(pixelRect.left, pixelRect.center.dy),
    ];

    for (final h in handles) {
      canvas.drawCircle(h, hs, handlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) =>
      oldDelegate.pixelRect != pixelRect;
}
