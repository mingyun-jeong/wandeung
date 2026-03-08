import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:wandeung/models/subtitle_item.dart';

void main() {
  group('SubtitleItem', () {
    test('creates with default values', () {
      const item = SubtitleItem(
        id: '1',
        text: '핵심 무브',
        startTime: Duration(seconds: 2),
        endTime: Duration(seconds: 5),
      );

      expect(item.text, '핵심 무브');
      expect(item.position, const Offset(0.5, 0.8));
      expect(item.fontSize, 24.0);
      expect(item.color, const Color(0xFFFFFFFF));
      expect(item.backgroundColor, isNull);
      expect(item.strokeColor, isNull);
      expect(item.strokeWidth, 0.0);
      expect(item.isBold, false);
      expect(item.hasShadow, false);
    });

    test('copyWith updates fields correctly', () {
      const item = SubtitleItem(
        id: '1',
        text: '원본',
        startTime: Duration(seconds: 1),
        endTime: Duration(seconds: 3),
      );

      final updated = item.copyWith(
        text: '수정됨',
        fontSize: 32.0,
        color: const Color(0xFFFF0000),
        hasShadow: true,
      );

      expect(updated.text, '수정됨');
      expect(updated.fontSize, 32.0);
      expect(updated.color, const Color(0xFFFF0000));
      expect(updated.hasShadow, true);
      expect(updated.id, '1');
      expect(updated.startTime, const Duration(seconds: 1));
    });

    test('copyWith clearBackground sets null', () {
      const item = SubtitleItem(
        id: '1',
        text: 'test',
        startTime: Duration.zero,
        endTime: Duration(seconds: 3),
        backgroundColor: Color(0xFF000000),
      );

      final updated = item.copyWith(clearBackground: true);
      expect(updated.backgroundColor, isNull);
    });

    test('copyWith clearStroke sets null', () {
      const item = SubtitleItem(
        id: '1',
        text: 'test',
        startTime: Duration.zero,
        endTime: Duration(seconds: 3),
        strokeColor: Color(0xFF000000),
      );

      final updated = item.copyWith(clearStroke: true);
      expect(updated.strokeColor, isNull);
    });

    test('isVisibleAt returns true when time is within range', () {
      const item = SubtitleItem(
        id: '1',
        text: 'test',
        startTime: Duration(seconds: 2),
        endTime: Duration(seconds: 5),
      );

      expect(item.isVisibleAt(const Duration(seconds: 3)), true);
      expect(item.isVisibleAt(const Duration(seconds: 2)), true);
      expect(item.isVisibleAt(const Duration(seconds: 1)), false);
      expect(item.isVisibleAt(const Duration(seconds: 5)), false);
    });
  });

}
