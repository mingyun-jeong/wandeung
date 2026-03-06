import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:wandeung/models/subtitle_item.dart';
import 'package:wandeung/models/video_edit_models.dart';
import 'package:wandeung/services/ffmpeg_command_builder.dart';

void main() {
  group('FFmpegCommandBuilder subtitle support', () {
    test('includes subtitle drawtext with enable/between', () {
      const subtitle = SubtitleItem(
        id: '1',
        text: '핵심 무브',
        startTime: Duration(seconds: 2),
        endTime: Duration(seconds: 5),
        position: Offset(0.5, 0.8),
        fontSize: 24.0,
        color: Color(0xFFFFFFFF),
      );

      final command = FFmpegCommandBuilder.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        subtitles: [subtitle],
        videoResolution: const Size(1920, 1080),
        fontPath: '/fonts/NotoSansKR-Bold.otf',
      );

      expect(command, contains('drawtext='));
      expect(command, contains("enable='between(t,2.000,5.000)'"));
      expect(command, contains('fontcolor=0xffffff'));
    });

    test('subtitle with stroke adds borderw and bordercolor', () {
      const subtitle = SubtitleItem(
        id: '1',
        text: 'stroke test',
        startTime: Duration.zero,
        endTime: Duration(seconds: 3),
        strokeColor: Color(0xFF000000),
        strokeWidth: 3.0,
      );

      final command = FFmpegCommandBuilder.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        subtitles: [subtitle],
        videoResolution: const Size(1920, 1080),
      );

      expect(command, contains('borderw=3'));
      expect(command, contains('bordercolor=0x000000'));
    });

    test('subtitle with shadow adds shadow params', () {
      const subtitle = SubtitleItem(
        id: '1',
        text: 'shadow test',
        startTime: Duration.zero,
        endTime: Duration(seconds: 3),
        hasShadow: true,
      );

      final command = FFmpegCommandBuilder.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        subtitles: [subtitle],
        videoResolution: const Size(1920, 1080),
      );

      expect(command, contains('shadowcolor='));
      expect(command, contains('shadowx='));
      expect(command, contains('shadowy='));
    });

    test('subtitle with background adds box params', () {
      const subtitle = SubtitleItem(
        id: '1',
        text: 'bg test',
        startTime: Duration.zero,
        endTime: Duration(seconds: 3),
        backgroundColor: Color(0xFF000000),
      );

      final command = FFmpegCommandBuilder.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        subtitles: [subtitle],
        videoResolution: const Size(1920, 1080),
      );

      expect(command, contains('box=1'));
      expect(command, contains('boxcolor=0x000000'));
    });

    test('subtitle with custom fontPath uses it', () {
      const subtitle = SubtitleItem(
        id: '1',
        text: 'font test',
        startTime: Duration.zero,
        endTime: Duration(seconds: 3),
        fontFamily: 'MyCustomFont',
      );

      final command = FFmpegCommandBuilder.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        subtitles: [subtitle],
        videoResolution: const Size(1920, 1080),
        subtitleFontPaths: {
          'MyCustomFont': '/fonts/MyCustomFont.ttf',
        },
      );

      expect(command, contains('fontfile=/fonts/MyCustomFont.ttf'));
    });

    test('overlays and subtitles chain correctly', () {
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

      final command = FFmpegCommandBuilder.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        overlays: [overlay],
        subtitles: [subtitle],
        videoResolution: const Size(1920, 1080),
      );

      // Both drawtext filters present
      expect('drawtext='.allMatches(command).length, 2);
      expect(command, contains('[vout]'));
    });

    test('works without subtitles (backward compat)', () {
      final command = FFmpegCommandBuilder.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        videoResolution: const Size(1920, 1080),
      );

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

      final command = FFmpegCommandBuilder.buildExportCommand(
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
        videoResolution: const Size(1920, 1080),
      );

      expect(command, contains('[vspeed]'));
      expect(command, contains('[vout]'));
      expect(command, contains("enable='between(t,0.000,3.000)'"));
    });
  });
}
