import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/subtitle_item.dart';
import '../models/video_edit_models.dart';

/// FFmpeg 필터 체인을 조합하여 내보내기 명령을 생성하는 순수 함수 서비스
class FFmpegCommandBuilder {
  FFmpegCommandBuilder._();


  /// 전체 내보내기 명령을 인수 리스트로 생성
  ///
  /// [subtitleImagePaths] Flutter Canvas로 렌더링된 자막 PNG 이미지 경로 리스트
  static List<String> buildExportArgs({
    required String inputPath,
    required String outputPath,
    required Duration trimStart,
    required Duration trimEnd,
    required Size videoResolution,
    List<SpeedSegment> speedSegments = const [],
    List<OverlayItem> overlays = const [],
    List<String> overlayImagePaths = const [],
    List<SubtitleItem> subtitles = const [],
    List<String> subtitleImagePaths = const [],
  }) {
    final args = <String>['-y'];

    args.addAll(['-i', inputPath]);

    // 오버레이 스티커 PNG 이미지를 추가 입력으로 등록
    // -loop 1: 단일 프레임 PNG를 무한 반복하여 영상 전체 구간에 overlay
    for (final imgPath in overlayImagePaths) {
      args.addAll(['-loop', '1', '-i', imgPath]);
    }

    // 자막 PNG 이미지를 추가 입력으로 등록
    for (final imgPath in subtitleImagePaths) {
      args.addAll(['-i', imgPath]);
    }

    args.addAll([
      '-ss',
      _formatDuration(trimStart),
      '-to',
      _formatDuration(trimEnd),
    ]);

    final filterComplex = _buildFilterComplex(
      speedSegments: speedSegments,
      overlays: overlays,
      overlayImagePaths: overlayImagePaths,
      subtitles: subtitles,
      subtitleImagePaths: subtitleImagePaths,
      videoResolution: videoResolution,
    );

    if (filterComplex != null) {
      args.addAll(['-filter_complex', filterComplex]);

      if (filterComplex.contains('[vout]')) {
        args.addAll(['-map', '[vout]']);
      }
      if (filterComplex.contains('[aout]')) {
        args.addAll(['-map', '[aout]']);
      } else if (filterComplex.contains('[vout]')) {
        // 비디오 필터만 있고 오디오 필터가 없는 경우 원본 오디오 매핑
        args.addAll(['-map', '0:a?']);
      }
    }

    args.addAll([
      '-c:v', 'libx264',
      '-preset', 'fast',
      '-crf', '23',
      '-c:a', 'aac',
      '-b:a', '128k',
      '-movflags', '+faststart',
      '-r', '30',
      outputPath,
    ]);

    return args;
  }

  static String? _buildFilterComplex({
    required List<SpeedSegment> speedSegments,
    required List<OverlayItem> overlays,
    required List<String> overlayImagePaths,
    required List<SubtitleItem> subtitles,
    required List<String> subtitleImagePaths,
    required Size videoResolution,
  }) {
    final hasSpeedChange =
        speedSegments.isNotEmpty && speedSegments.any((s) => s.speed != 1.0);
    final hasOverlayImages =
        overlays.isNotEmpty && overlayImagePaths.length == overlays.length;
    final hasSubtitleImages =
        subtitles.isNotEmpty && subtitleImagePaths.length == subtitles.length;

    if (!hasSpeedChange && !hasOverlayImages && !hasSubtitleImages) return null;

    final filters = <String>[];

    // --- 배속 처리 ---
    if (hasSpeedChange && speedSegments.length == 1) {
      final speed = speedSegments.first.speed;
      final pts = (1.0 / speed).toStringAsFixed(4);
      filters.add('[0:v]setpts=$pts*PTS[vspeed]');
      filters.add('[0:a]${buildAtempoChain(speed)}[aout]');
    } else if (hasSpeedChange && speedSegments.length > 1) {
      _buildMultiSegmentSpeed(filters, speedSegments);
    }

    // --- 오버레이 스티커 (PNG 이미지 overlay) ---
    // Flutter Canvas에서 렌더링한 PNG를 overlay 필터로 합성 (drawtext 대신)
    if (hasOverlayImages) {
      String currentLabel = hasSpeedChange ? '[vspeed]' : '[0:v]';

      for (int i = 0; i < overlays.length; i++) {
        final isLast = i == overlays.length - 1 && !hasSubtitleImages;
        final outputLabel = isLast ? '[vout]' : '[vovl$i]';
        // 입력 인덱스: 0=영상, 1~N=오버레이 PNG
        final inputIdx = 1 + i;

        final item = overlays[i];
        final px = item.position.dx.toStringAsFixed(4);
        final py = item.position.dy.toStringAsFixed(4);

        String overlayFilter =
            "$currentLabel[$inputIdx:v]overlay="
            "x=$px*W-w/2:y=$py*H-h/2";

        // 시간 범위가 지정된 경우 enable 조건 추가
        if (item.startTime != null && item.endTime != null) {
          final startSec = item.startTime!.inMilliseconds / 1000.0;
          final endSec = item.endTime!.inMilliseconds / 1000.0;
          overlayFilter += ":"
              "enable='between(t,${startSec.toStringAsFixed(3)},${endSec.toStringAsFixed(3)})'";
        }

        filters.add('$overlayFilter$outputLabel');
        currentLabel = outputLabel;
      }
    } else if (hasSpeedChange && !hasSubtitleImages) {
      final lastIdx = filters.lastIndexWhere((f) => f.contains('[vspeed]'));
      if (lastIdx >= 0) {
        filters[lastIdx] = filters[lastIdx].replaceAll('[vspeed]', '[vout]');
      }
    }

    // --- 자막 (PNG 이미지 overlay) ---
    // Flutter Canvas에서 렌더링한 PNG를 overlay 필터로 합성
    if (hasSubtitleImages) {
      String currentLabel;
      if (hasOverlayImages) {
        currentLabel = '[vovl${overlays.length - 1}]';
      } else if (hasSpeedChange) {
        currentLabel = '[vspeed]';
      } else {
        currentLabel = '[0:v]';
      }

      for (int i = 0; i < subtitles.length; i++) {
        final isLast = i == subtitles.length - 1;
        final outputLabel = isLast ? '[vout]' : '[vsub$i]';
        // 입력 인덱스: 0=영상, 오버레이PNG 개수 + 1~N=자막 PNG
        final inputIdx = 1 + overlayImagePaths.length + i;

        final sub = subtitles[i];
        final px = sub.position.dx.toStringAsFixed(4);
        final py = sub.position.dy.toStringAsFixed(4);
        final startSec = sub.startTime.inMilliseconds / 1000.0;
        final endSec = sub.endTime.inMilliseconds / 1000.0;

        // overlay_w(w), overlay_h(h), main_w(W), main_h(H) 자동 변수 사용
        // 자막 위치를 중심 기준으로 배치
        final overlayFilter =
            "$currentLabel[$inputIdx:v]overlay="
            "x=$px*W-w/2:y=$py*H-h/2:"
            "enable='between(t,${startSec.toStringAsFixed(3)},${endSec.toStringAsFixed(3)})'";

        filters.add('$overlayFilter$outputLabel');
        currentLabel = outputLabel;
      }
    }

    final result = filters.isEmpty ? null : filters.join(';');
    debugPrint('[FFmpeg] filter_complex: $result');
    return result;
  }

  static void _buildMultiSegmentSpeed(
      List<String> filters, List<SpeedSegment> segments) {
    final videoLabels = <String>[];
    final audioLabels = <String>[];

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final startSec = seg.start.inMilliseconds / 1000.0;
      final endSec = seg.end.inMilliseconds / 1000.0;
      final pts = (1.0 / seg.speed).toStringAsFixed(4);

      filters.add(
        '[0:v]trim=start=$startSec:end=$endSec,setpts=$pts*(PTS-STARTPTS)[v$i]',
      );
      videoLabels.add('[v$i]');

      final atempo = buildAtempoChain(seg.speed);
      filters.add(
        '[0:a]atrim=start=$startSec:end=$endSec,asetpts=PTS-STARTPTS,$atempo[a$i]',
      );
      audioLabels.add('[a$i]');
    }

    final n = segments.length;
    filters.add('${videoLabels.join()}concat=n=$n:v=1:a=0[vspeed]');
    filters.add('${audioLabels.join()}concat=n=$n:v=0:a=1[aout]');
  }

  /// atempo 필터 체인 생성 (0.5~2.0 범위 제한 대응)
  static String buildAtempoChain(double speed) {
    if (speed == 1.0) return 'atempo=1.0';

    final filters = <String>[];
    var remaining = speed;

    while (remaining > 2.0) {
      filters.add('atempo=2.0');
      remaining /= 2.0;
    }
    while (remaining < 0.5) {
      filters.add('atempo=0.5');
      remaining /= 0.5;
    }
    filters.add('atempo=${remaining.toStringAsFixed(4)}');
    return filters.join(',');
  }

  static String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    final millis = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds.$millis';
  }

}
