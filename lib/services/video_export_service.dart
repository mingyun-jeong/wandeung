import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  /// [onProgress] 0.0~1.0 범위의 진행률 콜백
  static Future<VideoEditResult> exportVideo({
    required String inputPath,
    required Duration trimStart,
    required Duration trimEnd,
    required Size videoResolution,
    required void Function(double progress) onProgress,
    List<SpeedSegment> speedSegments = const [],
    List<OverlayItem> overlays = const [],
    List<SubtitleItem> subtitles = const [],
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${appDir.path}/edited_$timestamp.mp4';

    // 오버레이 스티커를 PNG 이미지로 렌더링
    final overlayImagePaths = overlays.isNotEmpty
        ? await SubtitleImageRenderer.renderOverlays(
            overlays: overlays,
            videoResolution: videoResolution,
          )
        : <String>[];

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
      overlayImagePaths: overlayImagePaths,
      videoResolution: videoResolution,
      subtitles: subtitles,
      subtitleImagePaths: subtitleImagePaths,
    );

    final expectedDurationMs = _calculateExpectedDuration(
      trimStart, trimEnd, speedSegments,
    );

    debugPrint('[FFmpeg] overlayImages: $overlayImagePaths');
    debugPrint('[FFmpeg] subtitleImages: $subtitleImagePaths');
    debugPrint('[FFmpeg] args: ${args.join(' ')}');

    await _executeFFmpeg(
      args: args,
      outputPath: outputPath,
      expectedDurationMs: expectedDurationMs,
      onProgress: onProgress,
    );

    await _cleanupExportCache();
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
    required void Function(double progress) onProgress,
    List<SpeedSegment> speedSegments = const [],
    List<OverlayItem> overlays = const [],
    List<SubtitleItem> subtitles = const [],
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${appDir.path}/edited_$timestamp.mp4';

    // 오버레이 스티커를 PNG 이미지로 렌더링
    final overlayImagePaths = overlays.isNotEmpty
        ? await SubtitleImageRenderer.renderOverlays(
            overlays: overlays,
            videoResolution: videoResolution,
          )
        : <String>[];

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
      overlayImagePaths: overlayImagePaths,
      videoResolution: videoResolution,
      subtitles: subtitles,
      subtitleImagePaths: subtitleImagePaths,
    );

    final expectedDurationMs = _calculateExpectedDuration(
      trimStart, trimEnd, speedSegments,
    );

    await _executeFFmpeg(
      args: args,
      outputPath: outputPath,
      expectedDurationMs: expectedDurationMs,
      onProgress: onProgress,
    );

    await _cleanupExportCache();
    onProgress(1.0);

    return VideoEditResult(
      outputPath: outputPath,
      duration: Duration(milliseconds: expectedDurationMs),
    );
  }

  /// FFmpeg 비동기 실행 후 출력 파일 기반으로 성공 여부 판단
  ///
  /// getReturnCode()가 PlatformException(SESSION_NOT_FOUND)을 발생시키는
  /// AAB/릴리즈 빌드 이슈를 우회하기 위해, 출력 파일 존재 + 크기로 판단
  static Future<void> _executeFFmpeg({
    required List<String> args,
    required String outputPath,
    required int expectedDurationMs,
    required void Function(double progress) onProgress,
  }) async {
    final completer = Completer<void>();

    await FFmpegKit.executeWithArgumentsAsync(
      args,
      (session) async {
        // 세션 완료 시 returnCode 확인 시도
        // PlatformException 발생 시 출력 파일로 fallback
        try {
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            if (!completer.isCompleted) completer.complete();
          } else {
            // FFmpeg 비정상 종료 — 출력 파일로 fallback 판단
            final outputFile = File(outputPath);
            if (await outputFile.exists() && await outputFile.length() > 0) {
              debugPrint('[FFmpeg] returnCode=${returnCode?.getValue()} '
                  '이지만 출력 파일 존재, 성공으로 처리');
              if (!completer.isCompleted) completer.complete();
            } else {
              String ffmpegOutput = '';
              try {
                ffmpegOutput = await session.getOutput() ?? '';
              } catch (_) {}
              if (!completer.isCompleted) {
                completer.completeError(VideoExportException(
                  '내보내기 실패 (코드: ${returnCode?.getValue()})',
                  ffmpegOutput,
                ));
              }
            }
          }
        } on PlatformException catch (e) {
          debugPrint('[FFmpeg] getReturnCode PlatformException: $e');
          // SESSION_NOT_FOUND — 출력 파일 존재로 성공 여부 판단
          final outputFile = File(outputPath);
          if (await outputFile.exists() && await outputFile.length() > 0) {
            debugPrint('[FFmpeg] 세션 조회 실패했지만 출력 파일 존재, 성공으로 처리');
            if (!completer.isCompleted) completer.complete();
          } else {
            String ffmpegOutput = '';
            try {
              ffmpegOutput = await session.getOutput() ?? '';
            } catch (_) {}
            debugPrint('[FFmpeg] 세션 조회 실패, 출력 파일 없음. log: $ffmpegOutput');
            if (!completer.isCompleted) {
              completer.completeError(VideoExportException(
                '내보내기 실패: ${e.message}',
                ffmpegOutput,
              ));
            }
          }
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError(VideoExportException(
              '내보내기 실패: $e',
              '',
            ));
          }
        }
      },
      (log) {},
      (statistics) {
        final timeMs = statistics.getTime();
        if (timeMs > 0 && expectedDurationMs > 0) {
          final progress = timeMs / expectedDurationMs;
          onProgress(progress.clamp(0.0, 1.0));
        }
      },
    );

    return completer.future;
  }

  /// 내보내기 후 캐시 정리 (자막 PNG + FFmpeg 세션)
  static Future<void> _cleanupExportCache() async {
    try {
      // 오버레이 + 자막 이미지 캐시 삭제
      final cacheDir = await getTemporaryDirectory();
      for (final dirName in ['overlay_imgs', 'subtitle_imgs']) {
        final dir = Directory('${cacheDir.path}/$dirName');
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    } catch (_) {}
    try {
      // FFmpeg 세션 로그 캐시 정리
      await FFmpegKitConfig.clearSessions();
    } catch (_) {}
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
  String toString() => ffmpegOutput.isNotEmpty
      ? 'VideoExportException: $message\n$ffmpegOutput'
      : 'VideoExportException: $message';
}
