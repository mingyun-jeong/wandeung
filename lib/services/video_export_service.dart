import 'dart:ui';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

import '../models/video_edit_models.dart';
import 'ffmpeg_command_builder.dart';

/// FFmpeg를 사용하여 편집된 영상을 내보내는 서비스
class VideoExportService {
  VideoExportService._();

  /// 편집된 영상을 MP4로 내보내기
  ///
  /// [onProgress] 0.0~1.0 범위의 진행률 콜백
  /// 성공 시 [VideoEditResult] 반환, 실패 시 예외 throw
  static Future<VideoEditResult> exportVideo({
    required String inputPath,
    required Duration trimStart,
    required Duration trimEnd,
    List<SpeedSegment> speedSegments = const [],
    List<OverlayItem> overlays = const [],
    required Size videoResolution,
    String? fontPath,
    required void Function(double progress) onProgress,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${appDir.path}/edited_$timestamp.mp4';

    final command = FFmpegCommandBuilder.buildExportCommand(
      inputPath: inputPath,
      outputPath: outputPath,
      trimStart: trimStart,
      trimEnd: trimEnd,
      speedSegments: speedSegments,
      overlays: overlays,
      videoResolution: videoResolution,
      fontPath: fontPath,
    );

    // 예상 출력 길이 계산 (진행률 추적용)
    final expectedDurationMs = _calculateExpectedDuration(
      trimStart,
      trimEnd,
      speedSegments,
    );

    final session = await FFmpegKit.execute(command);
    // Note: executeAsync가 아닌 execute를 사용하여 완료 대기
    // 진행률은 통계 콜백 대신 로그 파싱으로 처리

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
    List<SpeedSegment> speedSegments = const [],
    List<OverlayItem> overlays = const [],
    required Size videoResolution,
    String? fontPath,
    required void Function(double progress) onProgress,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${appDir.path}/edited_$timestamp.mp4';

    final command = FFmpegCommandBuilder.buildExportCommand(
      inputPath: inputPath,
      outputPath: outputPath,
      trimStart: trimStart,
      trimEnd: trimEnd,
      speedSegments: speedSegments,
      overlays: overlays,
      videoResolution: videoResolution,
      fontPath: fontPath,
    );

    final expectedDurationMs = _calculateExpectedDuration(
      trimStart,
      trimEnd,
      speedSegments,
    );

    final session = await FFmpegKit.executeAsync(
      command,
      (session) async {
        // 완료 콜백 — Completer로 처리
      },
      (log) {
        // 로그 콜백
      },
      (statistics) {
        final timeMs = statistics.getTime();
        if (timeMs > 0 && expectedDurationMs > 0) {
          final progress = timeMs / expectedDurationMs;
          onProgress(progress.clamp(0.0, 1.0));
        }
      },
    );

    // 세션 완료 대기
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

  /// 배속 구간을 고려한 예상 출력 길이 (밀리초)
  static int _calculateExpectedDuration(
    Duration trimStart,
    Duration trimEnd,
    List<SpeedSegment> speedSegments,
  ) {
    if (speedSegments.isEmpty ||
        speedSegments.every((s) => s.speed == 1.0)) {
      return (trimEnd - trimStart).inMilliseconds;
    }

    // 각 구간의 조정된 길이 합산
    int totalMs = 0;
    for (final seg in speedSegments) {
      totalMs += seg.adjustedDuration.inMilliseconds;
    }
    return totalMs;
  }
}

/// 비디오 내보내기 예외
class VideoExportException implements Exception {
  final String message;
  final String ffmpegOutput;

  const VideoExportException(this.message, this.ffmpegOutput);

  @override
  String toString() => 'VideoExportException: $message';
}
