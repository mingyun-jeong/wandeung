import 'dart:ui';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/subtitle_item.dart';
import '../models/video_edit_models.dart';
import 'ffmpeg_command_builder.dart';
import 'subtitle_image_renderer.dart';

/// FFmpeg를 사용하여 편집된 영상을 내보내는 서비스
class VideoExportService {
  VideoExportService._();

  /// 편집된 영상을 MP4로 내보내기
  ///
  /// [fontPath] 오버레이(스티커) 텍스트용 폰트 파일 경로
  /// [onProgress] 0.0~1.0 범위의 진행률 콜백
  static Future<VideoEditResult> exportVideo({
    required String inputPath,
    required Duration trimStart,
    required Duration trimEnd,
    required Size videoResolution,
    required String? fontPath,
    required void Function(double progress) onProgress,
    List<SpeedSegment> speedSegments = const [],
    List<OverlayItem> overlays = const [],
    List<SubtitleItem> subtitles = const [],
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${appDir.path}/edited_$timestamp.mp4';

    // 자막 텍스트를 PNG 이미지로 렌더링
    final subtitleImagePaths = subtitles.isNotEmpty
        ? await SubtitleImageRenderer.renderAll(
            subtitles: subtitles,
            videoResolution: videoResolution,
          )
        : <String>[];

    final args = FFmpegCommandBuilder.buildExportArgs(
      inputPath: inputPath,
      outputPath: outputPath,
      trimStart: trimStart,
      trimEnd: trimEnd,
      speedSegments: speedSegments,
      overlays: overlays,
      videoResolution: videoResolution,
      fontPath: fontPath,
      subtitles: subtitles,
      subtitleImagePaths: subtitleImagePaths,
    );

    final expectedDurationMs = _calculateExpectedDuration(
      trimStart, trimEnd, speedSegments,
    );

    debugPrint('[FFmpeg] fontPath: $fontPath');
    debugPrint('[FFmpeg] subtitleImages: $subtitleImagePaths');
    debugPrint('[FFmpeg] args: ${args.join(' ')}');

    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final output = await session.getOutput();
      throw VideoExportException(
        '내보내기 실패 (코드: ${returnCode?.getValue()})',
        output ?? '',
      );
    }

    onProgress(1.0);

    return VideoEditResult(
      outputPath: outputPath,
      duration: Duration(milliseconds: expectedDurationMs),
    );
  }

  /// 비동기 내보내기 (진행률 콜백 지원)
  static Future<VideoEditResult> exportVideoAsync({
    required String inputPath,
    required Duration trimStart,
    required Duration trimEnd,
    required Size videoResolution,
    required String? fontPath,
    required void Function(double progress) onProgress,
    List<SpeedSegment> speedSegments = const [],
    List<OverlayItem> overlays = const [],
    List<SubtitleItem> subtitles = const [],
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${appDir.path}/edited_$timestamp.mp4';

    // 자막 텍스트를 PNG 이미지로 렌더링
    final subtitleImagePaths = subtitles.isNotEmpty
        ? await SubtitleImageRenderer.renderAll(
            subtitles: subtitles,
            videoResolution: videoResolution,
          )
        : <String>[];

    final args = FFmpegCommandBuilder.buildExportArgs(
      inputPath: inputPath,
      outputPath: outputPath,
      trimStart: trimStart,
      trimEnd: trimEnd,
      speedSegments: speedSegments,
      overlays: overlays,
      videoResolution: videoResolution,
      fontPath: fontPath,
      subtitles: subtitles,
      subtitleImagePaths: subtitleImagePaths,
    );

    final expectedDurationMs = _calculateExpectedDuration(
      trimStart, trimEnd, speedSegments,
    );

    final session = await FFmpegKit.executeWithArgumentsAsync(
      args,
      (session) async {},
      (log) {},
      (statistics) {
        final timeMs = statistics.getTime();
        if (timeMs > 0 && expectedDurationMs > 0) {
          final progress = timeMs / expectedDurationMs;
          onProgress(progress.clamp(0.0, 1.0));
        }
      },
    );

    await session.getReturnCode();
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final output = await session.getOutput();
      throw VideoExportException(
        '내보내기 실패 (코드: ${returnCode?.getValue()})',
        output ?? '',
      );
    }

    onProgress(1.0);

    return VideoEditResult(
      outputPath: outputPath,
      duration: Duration(milliseconds: expectedDurationMs),
    );
  }

  static int _calculateExpectedDuration(
    Duration trimStart,
    Duration trimEnd,
    List<SpeedSegment> speedSegments,
  ) {
    if (speedSegments.isEmpty ||
        speedSegments.every((s) => s.speed == 1.0)) {
      return (trimEnd - trimStart).inMilliseconds;
    }

    int totalMs = 0;
    for (final seg in speedSegments) {
      totalMs += seg.adjustedDuration.inMilliseconds;
    }
    return totalMs;
  }
}

class VideoExportException implements Exception {
  final String message;
  final String ffmpegOutput;

  const VideoExportException(this.message, this.ffmpegOutput);

  @override
  String toString() => 'VideoExportException: $message';
}
