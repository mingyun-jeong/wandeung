import 'dart:ui';

import '../models/subtitle_item.dart';
import '../models/video_edit_models.dart';

/// FFmpeg 필터 체인을 조합하여 내보내기 명령을 생성하는 순수 함수 서비스
class FFmpegCommandBuilder {
  FFmpegCommandBuilder._();

  /// 전체 내보내기 명령을 인수 리스트로 생성
  ///
  /// [inputPath] 입력 파일 경로
  /// [outputPath] 출력 파일 경로
  /// [trimStart] 트림 시작 시각
  /// [trimEnd] 트림 끝 시각
  /// [speedSegments] 구간별 배속 목록 (비어있으면 1x)
  /// [overlays] 오버레이 아이템 목록
  /// [videoResolution] 영상의 원본 해상도
  /// [fontPath] drawtext용 폰트 파일 경로
  static List<String> buildExportArgs({
    required String inputPath,
    required String outputPath,
    required Duration trimStart,
    required Duration trimEnd,
    List<SpeedSegment> speedSegments = const [],
    List<OverlayItem> overlays = const [],
    List<SubtitleItem> subtitles = const [],
    Map<String, String> subtitleFontPaths = const {},
    required Size videoResolution,
    String? fontPath,
  }) {
    final args = <String>['-y'];

    // 입력 파일
    args.addAll(['-i', inputPath]);

    // 트림: -ss와 -to를 input 이후에 배치 (정확한 디코딩)
    args.addAll([
      '-ss',
      _formatDuration(trimStart),
      '-to',
      _formatDuration(trimEnd),
    ]);

    // 필터 체인 빌드
    final filterComplex =
        _buildFilterComplex(speedSegments, overlays, subtitles, subtitleFontPaths, videoResolution, fontPath);

    if (filterComplex != null) {
      args.addAll(['-filter_complex', filterComplex]);

      // 필터 출력 매핑
      if (filterComplex.contains('[vout]')) {
        args.addAll(['-map', '[vout]']);
      }
      if (filterComplex.contains('[aout]')) {
        args.addAll(['-map', '[aout]']);
      }
    }

    // 인코딩 설정
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

  /// filter_complex 문자열 생성 (필터가 없으면 null)
  static String? _buildFilterComplex(
    List<SpeedSegment> speedSegments,
    List<OverlayItem> overlays,
    List<SubtitleItem> subtitles,
    Map<String, String> subtitleFontPaths,
    Size videoResolution,
    String? fontPath,
  ) {
    // 유효한 배속 구간 (1x가 아닌 것만)
    final hasSpeedChange =
        speedSegments.isNotEmpty && speedSegments.any((s) => s.speed != 1.0);
    final hasOverlays = overlays.isNotEmpty;
    final hasSubtitles = subtitles.isNotEmpty;

    if (!hasSpeedChange && !hasOverlays && !hasSubtitles) return null;

    final filters = <String>[];

    // --- 배속 처리 ---
    if (hasSpeedChange && speedSegments.length == 1) {
      // 단일 구간: 전체에 균일 배속
      final speed = speedSegments.first.speed;
      final pts = (1.0 / speed).toStringAsFixed(4);
      filters.add('[0:v]setpts=$pts*PTS[vspeed]');
      filters.add('[0:a]${buildAtempoChain(speed)}[aout]');
    } else if (hasSpeedChange && speedSegments.length > 1) {
      // 다중 구간: trim → setpts → concat
      _buildMultiSegmentSpeed(filters, speedSegments);
    }

    // --- 오버레이(drawtext) 처리 ---
    if (hasOverlays) {
      String currentLabel =
          hasSpeedChange ? '[vspeed]' : '[0:v]';

      for (int i = 0; i < overlays.length; i++) {
        final isLast = i == overlays.length - 1 && !hasSubtitles;
        final outputLabel = isLast ? '[vout]' : '[vtxt$i]';
        final drawtext =
            _buildDrawtext(overlays[i], videoResolution, fontPath);
        filters.add('${currentLabel}drawtext=$drawtext$outputLabel');
        currentLabel = outputLabel;
      }
    } else if (hasSpeedChange && !hasSubtitles) {
      // 배속만 있고 오버레이/자막 없음 → vspeed를 vout으로 변경
      final lastIdx = filters.lastIndexWhere((f) => f.contains('[vspeed]'));
      if (lastIdx >= 0) {
        filters[lastIdx] = filters[lastIdx].replaceAll('[vspeed]', '[vout]');
      }
    }

    // --- 자막(drawtext with enable) 처리 ---
    if (hasSubtitles) {
      // Determine input label for first subtitle
      String currentLabel;
      if (hasOverlays) {
        currentLabel = '[vtxt${overlays.length - 1}]'; // last overlay output
      } else if (hasSpeedChange) {
        currentLabel = '[vspeed]';
      } else {
        currentLabel = '[0:v]';
      }

      for (int i = 0; i < subtitles.length; i++) {
        final isLast = i == subtitles.length - 1;
        final outputLabel = isLast ? '[vout]' : '[vsub$i]';
        final drawtext = _buildSubtitleDrawtext(
          subtitles[i], videoResolution, fontPath, subtitleFontPaths,
        );
        filters.add('${currentLabel}drawtext=$drawtext$outputLabel');
        currentLabel = outputLabel;
      }
    }

    // 배속 없이 오버레이만 있는 경우 오디오는 그대로
    if (!hasSpeedChange && hasOverlays) {
      // 오디오 스트림은 복사되므로 별도 필터 불필요
    }

    return filters.isEmpty ? null : filters.join(';');
  }

  /// 다중 구간 배속 처리: trim → setpts 각 구간 → concat
  static void _buildMultiSegmentSpeed(
      List<String> filters, List<SpeedSegment> segments) {
    final videoLabels = <String>[];
    final audioLabels = <String>[];

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final startSec = seg.start.inMilliseconds / 1000.0;
      final endSec = seg.end.inMilliseconds / 1000.0;
      final pts = (1.0 / seg.speed).toStringAsFixed(4);

      // 비디오: trim → setpts (PTS-STARTPTS로 타임스탬프 리셋 필수)
      filters.add(
        '[0:v]trim=start=$startSec:end=$endSec,setpts=$pts*(PTS-STARTPTS)[v$i]',
      );
      videoLabels.add('[v$i]');

      // 오디오: atrim → atempo
      final atempo = buildAtempoChain(seg.speed);
      filters.add(
        '[0:a]atrim=start=$startSec:end=$endSec,asetpts=PTS-STARTPTS,$atempo[a$i]',
      );
      audioLabels.add('[a$i]');
    }

    // concat
    final n = segments.length;
    filters.add(
      '${videoLabels.join()}concat=n=$n:v=1:a=0[vspeed]',
    );
    filters.add(
      '${audioLabels.join()}concat=n=$n:v=0:a=1[aout]',
    );
  }

  /// drawtext 필터 파라미터 생성
  static String _buildDrawtext(
      OverlayItem item, Size videoResolution, String? fontPath) {
    // 정규화 좌표 → 영상 픽셀 좌표
    final x = (item.position.dx * videoResolution.width).round();
    final y = (item.position.dy * videoResolution.height).round();
    // 폰트 크기를 영상 해상도 비율로 스케일링
    final fontSize =
        (item.fontSize * (videoResolution.height / 800)).round();

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
      parts.add(
          'boxcolor=${_colorToFFmpeg(item.backgroundColor!)}@0.6');
      parts.add('boxborderw=8');
    }

    return parts.join(':');
  }

  /// 자막용 drawtext 필터 파라미터 생성 (enable/between 포함)
  static String _buildSubtitleDrawtext(
    SubtitleItem item,
    Size videoResolution,
    String? defaultFontPath,
    Map<String, String> subtitleFontPaths,
  ) {
    final x = (item.position.dx * videoResolution.width).round();
    final y = (item.position.dy * videoResolution.height).round();
    final fontSize = (item.fontSize * (videoResolution.height / 800)).round();
    final startSec = item.startTime.inMilliseconds / 1000.0;
    final endSec = item.endTime.inMilliseconds / 1000.0;

    final parts = <String>[];

    final fontPath = subtitleFontPaths[item.fontFamily] ?? defaultFontPath;
    if (fontPath != null) {
      parts.add("fontfile=${_escapePath(fontPath)}");
    }

    parts.add("text=${_escapeText(item.text)}");
    parts.add('x=$x');
    parts.add('y=$y');
    parts.add('fontsize=$fontSize');
    parts.add('fontcolor=${_colorToFFmpeg(item.color)}');
    parts.add("enable='between(t,${startSec.toStringAsFixed(3)},${endSec.toStringAsFixed(3)})'");

    if (item.strokeColor != null && item.strokeWidth > 0) {
      parts.add('borderw=${item.strokeWidth.round()}');
      parts.add('bordercolor=${_colorToFFmpeg(item.strokeColor!)}');
    }

    if (item.backgroundColor != null) {
      parts.add('box=1');
      parts.add('boxcolor=${_colorToFFmpeg(item.backgroundColor!)}@0.6');
      parts.add('boxborderw=8');
    }

    if (item.hasShadow) {
      parts.add('shadowcolor=0x000000@0.5');
      parts.add('shadowx=2');
      parts.add('shadowy=2');
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

  /// Duration을 HH:MM:SS.mmm 형식으로 변환
  static String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    final millis = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds.$millis';
  }

  /// drawtext용 텍스트 이스케이프 (backslash를 먼저 이스케이프해야 함)
  static String _escapeText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll(':', '\\:')
        .replaceAll(';', '\\;');
  }

  /// drawtext용 파일 경로 이스케이프
  static String _escapePath(String path) {
    return path
        .replaceAll('\\', '\\\\')
        .replaceAll(':', '\\:')
        .replaceAll("'", "\\'");
  }

  /// Color를 FFmpeg 색상 문자열로 변환 (0xRRGGBB)
  static String _colorToFFmpeg(Color color) {
    final r = color.red.toInt().toRadixString(16).padLeft(2, '0');
    final g = color.green.toInt().toRadixString(16).padLeft(2, '0');
    final b = color.blue.toInt().toRadixString(16).padLeft(2, '0');
    return '0x$r$g$b';
  }
}
