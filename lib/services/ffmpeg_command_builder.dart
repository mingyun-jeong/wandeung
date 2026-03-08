import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/subtitle_item.dart';
import '../models/video_edit_models.dart';

/// FFmpeg 필터 체인을 조합하여 내보내기 명령을 생성하는 순수 함수 서비스
class FFmpegCommandBuilder {
  FFmpegCommandBuilder._();


  /// 전체 내보내기 명령을 인수 리스트로 생성
  ///
  /// [fontPath] 오버레이(스티커) 텍스트용 폰트 파일 경로
  /// [subtitleImagePaths] Flutter Canvas로 렌더링된 자막 PNG 이미지 경로 리스트
  static List<String> buildExportArgs({
    required String inputPath,
    required String outputPath,
    required Duration trimStart,
    required Duration trimEnd,
    required Size videoResolution,
    String? fontPath,
    List<SpeedSegment> speedSegments = const [],
    List<OverlayItem> overlays = const [],
    List<SubtitleItem> subtitles = const [],
    List<String> subtitleImagePaths = const [],
  }) {
    final args = <String>['-y'];

    args.addAll(['-i', inputPath]);

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
      subtitles: subtitles,
      subtitleImagePaths: subtitleImagePaths,
      videoResolution: videoResolution,
      fontPath: fontPath,
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
    required List<SubtitleItem> subtitles,
    required List<String> subtitleImagePaths,
    required Size videoResolution,
    required String? fontPath,
  }) {
    final hasSpeedChange =
        speedSegments.isNotEmpty && speedSegments.any((s) => s.speed != 1.0);
    final hasOverlays = overlays.isNotEmpty;
    final hasSubtitleImages =
        subtitles.isNotEmpty && subtitleImagePaths.length == subtitles.length;

    if (!hasSpeedChange && !hasOverlays && !hasSubtitleImages) return null;

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

    // --- 오버레이(drawtext) 처리 (스티커 등 ASCII 텍스트) ---
    if (hasOverlays) {
      String currentLabel = hasSpeedChange ? '[vspeed]' : '[0:v]';

      for (int i = 0; i < overlays.length; i++) {
        final isLast = i == overlays.length - 1 && !hasSubtitleImages;
        final outputLabel = isLast ? '[vout]' : '[vtxt$i]';
        final drawtext = _buildOverlayDrawtext(
          item: overlays[i],
          videoResolution: videoResolution,
          fontPath: fontPath,
        );
        filters.add('${currentLabel}drawtext=$drawtext$outputLabel');
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
      if (hasOverlays) {
        currentLabel = '[vtxt${overlays.length - 1}]';
      } else if (hasSpeedChange) {
        currentLabel = '[vspeed]';
      } else {
        currentLabel = '[0:v]';
      }

      for (int i = 0; i < subtitles.length; i++) {
        final isLast = i == subtitles.length - 1;
        final outputLabel = isLast ? '[vout]' : '[vsub$i]';
        // 입력 인덱스: 0=영상, 1~N=자막 PNG
        final inputIdx = 1 + i;

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

  /// 오버레이용 drawtext 필터 파라미터 생성
  static String _buildOverlayDrawtext({
    required OverlayItem item,
    required Size videoResolution,
    required String? fontPath,
  }) {
    final x = (item.position.dx * videoResolution.width).round();
    final y = (item.position.dy * videoResolution.height).round();
    final fontSize = (item.fontSize * (videoResolution.height / 800)).round();

    final parts = <String>[];
    if (fontPath != null) {
      parts.add("fontfile=${_escapePath(fontPath)}");
    }
    parts.add("text=${_escapeText(item.text)}");
    parts.add('x=$x');
    parts.add('y=$y');
    parts.add('fontsize=$fontSize');
    parts.add('fontcolor=${_colorToFFmpeg(item.color)}');
    parts.add('borderw=2');
    parts.add('bordercolor=black@0.5');

    if (item.backgroundColor != null) {
      parts.add('box=1');
      parts.add('boxcolor=${_colorToFFmpeg(item.backgroundColor!)}@0.6');
      parts.add('boxborderw=8');
    }

    return parts.join(':');
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

  static String _escapeText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll(':', '\\:')
        .replaceAll(';', '\\;');
  }

  static String _escapePath(String path) {
    return path
        .replaceAll('\\', '\\\\')
        .replaceAll(':', '\\:')
        .replaceAll("'", "\\'");
  }

  static String _colorToFFmpeg(Color color) {
    final r = color.red.toInt().toRadixString(16).padLeft(2, '0');
    final g = color.green.toInt().toRadixString(16).padLeft(2, '0');
    final b = color.blue.toInt().toRadixString(16).padLeft(2, '0');
    return '0x$r$g$b';
  }
}
