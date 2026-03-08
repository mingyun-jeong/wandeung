import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:wandeung/models/subtitle_item.dart';
import 'package:wandeung/models/video_edit_models.dart';
import 'package:wandeung/services/ffmpeg_command_builder.dart';

/// 인수 리스트를 하나의 문자열로 합쳐서 내용 검증에 사용
String _joinArgs(List<String> args) => args.join(' ');

void main() {
  group('FFmpegCommandBuilder subtitle image overlay', () {
    test('subtitle with image uses overlay filter with enable/between', () {
      const subtitle = SubtitleItem(
        id: '1',
        text: '핵심 무브',
        startTime: Duration(seconds: 2),
        endTime: Duration(seconds: 5),
        position: Offset(0.5, 0.8),
      );

      final args = FFmpegCommandBuilder.buildExportArgs(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        subtitles: [subtitle],
        subtitleImagePaths: ['/tmp/sub_0.png'],
        videoResolution: const Size(1920, 1080),
      );
      final command = _joinArgs(args);

      // PNG 이미지가 추가 입력으로 등록됨
      expect(command, contains('-i /tmp/sub_0.png'));
      // overlay 필터 사용 (drawtext 아님)
      expect(command, contains('overlay='));
      expect(command, contains("enable='between(t,2.000,5.000)'"));
      expect(command, contains('[vout]'));
      // drawtext는 사용하지 않음
      expect(command, isNot(contains('drawtext=')));
    });

    test('subtitle without image falls through (no filter)', () {
      const subtitle = SubtitleItem(
        id: '1',
        text: 'no image',
        startTime: Duration.zero,
        endTime: Duration(seconds: 3),
      );

      // subtitleImagePaths가 비어있으면 자막 필터 없음
      final args = FFmpegCommandBuilder.buildExportArgs(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        subtitles: [subtitle],
        subtitleImagePaths: [],
        videoResolution: const Size(1920, 1080),
      );
      final command = _joinArgs(args);

      expect(command, isNot(contains('overlay=')));
      expect(command, isNot(contains('filter_complex')));
    });

    test('overlay stickers still use drawtext', () {
      const overlay = OverlayItem(
        id: 'o1',
        text: 'V3',
        position: Offset(0.1, 0.1),
      );

      final args = FFmpegCommandBuilder.buildExportArgs(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        overlays: [overlay],
        videoResolution: const Size(1920, 1080),
        fontPath: '/fonts/NanumGothic-Bold.ttf',
      );
      final command = _joinArgs(args);

      expect(command, contains('drawtext='));
      expect(command, contains('fontfile=/fonts/NanumGothic-Bold.ttf'));
      expect(command, contains('[vout]'));
    });

    test('overlays and subtitle images chain correctly', () {
      const overlay = OverlayItem(
        id: 'o1',
        text: 'V3',
        position: Offset(0.1, 0.1),
      );
      const subtitle = SubtitleItem(
        id: 's1',
        text: '자막',
        startTime: Duration.zero,
        endTime: Duration(seconds: 3),
      );

      final args = FFmpegCommandBuilder.buildExportArgs(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        overlays: [overlay],
        subtitles: [subtitle],
        subtitleImagePaths: ['/tmp/sub_0.png'],
        videoResolution: const Size(1920, 1080),
      );
      final command = _joinArgs(args);

      // drawtext (오버레이) + overlay (자막) 모두 존재
      expect(command, contains('drawtext='));
      expect(command, contains('overlay='));
      expect(command, contains('[vout]'));
    });

    test('works without subtitles (backward compat)', () {
      final args = FFmpegCommandBuilder.buildExportArgs(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        videoResolution: const Size(1920, 1080),
      );
      final command = _joinArgs(args);

      expect(command, contains('/output.mp4'));
      expect(command, isNot(contains("enable='between")));
    });

    test('subtitles with speed change chains correctly', () {
      const subtitle = SubtitleItem(
        id: '1',
        text: 'speed+sub',
        startTime: Duration.zero,
        endTime: Duration(seconds: 3),
      );

      final args = FFmpegCommandBuilder.buildExportArgs(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        speedSegments: [
          const SpeedSegment(
            start: Duration.zero,
            end: Duration(seconds: 10),
            speed: 2.0,
          ),
        ],
        subtitles: [subtitle],
        subtitleImagePaths: ['/tmp/sub_0.png'],
        videoResolution: const Size(1920, 1080),
      );
      final command = _joinArgs(args);

      expect(command, contains('[vspeed]'));
      expect(command, contains('[vout]'));
      expect(command, contains("enable='between(t,0.000,3.000)'"));
    });

    test('filter_complex is passed as single argument', () {
      const subtitle = SubtitleItem(
        id: '1',
        text: 'test',
        startTime: Duration(seconds: 1),
        endTime: Duration(seconds: 3),
      );

      final args = FFmpegCommandBuilder.buildExportArgs(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        subtitles: [subtitle],
        subtitleImagePaths: ['/tmp/sub_0.png'],
        videoResolution: const Size(1920, 1080),
      );

      final fcIndex = args.indexOf('-filter_complex');
      expect(fcIndex, isNot(-1));
      final filterValue = args[fcIndex + 1];
      expect(filterValue, contains("enable='between(t,"));
      expect(filterValue, contains('[vout]'));
    });

    test('multiple subtitles create chained overlays', () {
      const sub1 = SubtitleItem(
        id: '1',
        text: '첫번째',
        startTime: Duration.zero,
        endTime: Duration(seconds: 2),
      );
      const sub2 = SubtitleItem(
        id: '2',
        text: '두번째',
        startTime: Duration(seconds: 3),
        endTime: Duration(seconds: 5),
      );

      final args = FFmpegCommandBuilder.buildExportArgs(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        subtitles: [sub1, sub2],
        subtitleImagePaths: ['/tmp/sub_0.png', '/tmp/sub_1.png'],
        videoResolution: const Size(1920, 1080),
      );
      final command = _joinArgs(args);

      // 두 개의 PNG 입력
      expect(command, contains('-i /tmp/sub_0.png'));
      expect(command, contains('-i /tmp/sub_1.png'));
      // 두 개의 overlay 필터
      expect('overlay='.allMatches(command).length, 2);
      // 중간 라벨과 최종 출력
      expect(command, contains('[vsub0]'));
      expect(command, contains('[vout]'));
    });
  });
}
