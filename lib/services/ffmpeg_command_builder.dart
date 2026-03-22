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
    List<CropSegment> cropSegments = const [],
    List<OverlayItem> overlays = const [],
    List<String> overlayImagePaths = const [],
    List<SubtitleItem> subtitles = const [],
    List<String> subtitleImagePaths = const [],
    List<MediaSegment> mediaSegments = const [],
    int? targetHeight,
    int crf = 23,
  }) {
    final args = <String>['-y'];

    args.addAll(['-i', inputPath]);

    // 오버레이 스티커 PNG 이미지를 추가 입력으로 등록
    // -loop 1: 단일 프레임 PNG를 무한 반복하여 영상 전체 구간에 overlay
    for (final imgPath in overlayImagePaths) {
      args.addAll(['-loop', '1', '-i', imgPath]);
    }

    // 자막 PNG 이미지를 추가 입력으로 등록
    // -loop 1: 단일 프레임 PNG를 무한 반복하여 enable 시간 조건이 정상 동작하도록 함
    for (final imgPath in subtitleImagePaths) {
      args.addAll(['-loop', '1', '-i', imgPath]);
    }

    args.addAll([
      '-ss',
      _formatDuration(trimStart),
      '-to',
      _formatDuration(trimEnd),
    ]);

    // 원본보다 작을 때만 스케일링 적용 (0이면 원본 유지, 업스케일 안 함)
    final needsScale = targetHeight != null &&
        targetHeight > 0 &&
        videoResolution.height > targetHeight;

    final filterComplex = _buildFilterComplex(
      speedSegments: speedSegments,
      cropSegments: cropSegments,
      overlays: overlays,
      overlayImagePaths: overlayImagePaths,
      subtitles: subtitles,
      subtitleImagePaths: subtitleImagePaths,
      mediaSegments: mediaSegments,
      videoResolution: videoResolution,
      targetHeight: needsScale ? targetHeight : null,
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
    } else if (needsScale) {
      // filter_complex가 없고 스케일링만 필요한 경우
      args.addAll(['-vf', 'scale=-2:$targetHeight']);
    }

    args.addAll([
      '-c:v', 'libx264',
      '-preset', 'fast',
      '-crf', '$crf',
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
    List<CropSegment> cropSegments = const [],
    required List<OverlayItem> overlays,
    required List<String> overlayImagePaths,
    required List<SubtitleItem> subtitles,
    required List<String> subtitleImagePaths,
    List<MediaSegment> mediaSegments = const [],
    required Size videoResolution,
    int? targetHeight,
  }) {
    final hasSpeedChange =
        speedSegments.isNotEmpty && speedSegments.any((s) => s.speed != 1.0);
    final hasOverlayImages =
        overlays.isNotEmpty && overlayImagePaths.length == overlays.length;
    final hasSubtitleImages =
        subtitles.isNotEmpty && subtitleImagePaths.length == subtitles.length;
    final hasCrop = cropSegments.isNotEmpty && cropSegments.any((s) => s.hasCrop);
    final hasScale = targetHeight != null;
    // 삭제된 미디어 세그먼트가 있는지 확인
    final activeMediaSegments =
        mediaSegments.where((s) => !s.isDeleted).toList();
    final hasMediaCut = mediaSegments.isNotEmpty &&
        activeMediaSegments.length < mediaSegments.length;

    debugPrint('[FFmpeg] filterComplex flags: speed=$hasSpeedChange crop=$hasCrop '
        'overlay=$hasOverlayImages subtitle=$hasSubtitleImages scale=$hasScale '
        'mediaCut=$hasMediaCut');
    if (hasCrop) {
      for (int i = 0; i < cropSegments.length; i++) {
        final s = cropSegments[i];
        debugPrint('[FFmpeg] cropSeg[$i] hasCrop=${s.hasCrop} rect=${s.cropRect}');
      }
    }

    if (!hasSpeedChange && !hasCrop && !hasOverlayImages && !hasSubtitleImages && !hasScale && !hasMediaCut) {
      return null;
    }

    final filters = <String>[];

    // --- 미디어 세그먼트 삭제 처리 (select 필터) ---
    // 삭제된 구간을 제거하고 유효 구간만 concat
    if (hasMediaCut) {
      final videoLabels = <String>[];
      final audioLabels = <String>[];

      for (int i = 0; i < activeMediaSegments.length; i++) {
        final seg = activeMediaSegments[i];
        final startSec = seg.start.inMilliseconds / 1000.0;
        final endSec = seg.end.inMilliseconds / 1000.0;

        filters.add(
          '[0:v]trim=start=$startSec:end=$endSec,setpts=PTS-STARTPTS[vm$i]',
        );
        videoLabels.add('[vm$i]');

        filters.add(
          '[0:a]atrim=start=$startSec:end=$endSec,asetpts=PTS-STARTPTS[am$i]',
        );
        audioLabels.add('[am$i]');
      }

      final n = activeMediaSegments.length;
      if (n == 1) {
        // 단일 구간이면 concat 불필요, 라벨만 변환
        filters[filters.length - 2] = filters[filters.length - 2]
            .replaceAll('[vm0]', '[vmedia]');
        filters[filters.length - 1] = filters[filters.length - 1]
            .replaceAll('[am0]', '[amedia]');
      } else {
        filters.add('${videoLabels.join()}concat=n=$n:v=1:a=0[vmedia]');
        filters.add('${audioLabels.join()}concat=n=$n:v=0:a=1[amedia]');
      }
    }

    // 미디어 컷 적용 시 이후 필터의 입력 라벨
    final baseVideoLabel = hasMediaCut ? '[vmedia]' : '[0:v]';
    final baseAudioLabel = hasMediaCut ? '[amedia]' : '[0:a]';

    // --- 배속 처리 ---
    if (hasSpeedChange && speedSegments.length == 1) {
      final speed = speedSegments.first.speed;
      final pts = (1.0 / speed).toStringAsFixed(4);
      filters.add('${baseVideoLabel}setpts=$pts*PTS[vspeed]');
      filters.add('$baseAudioLabel${buildAtempoChain(speed)}[aout]');
    } else if (hasSpeedChange && speedSegments.length > 1) {
      _buildMultiSegmentSpeed(filters, speedSegments, baseVideoLabel, baseAudioLabel);
    }

    // 미디어 컷만 있고 배속/다른 필터가 없는 경우 오디오 출력 매핑
    if (hasMediaCut && !hasSpeedChange) {
      // amedia를 aout으로 매핑
      filters.add('${baseAudioLabel}anull[aout]');
    }

    // --- 크롭 줌 처리 ---
    // crop 후 종횡비를 유지하면서 스케일업 (원본 비율 보존)
    if (hasCrop) {
      final cropInput = hasSpeedChange ? '[vspeed]' : baseVideoLabel;
      final origW = videoResolution.width.round();
      final origH = videoResolution.height.round();

      // 크롭 영역의 종횡비에 맞춰 스케일 결정
      // 가로 기준으로 맞추고 세로는 -2(짝수 자동), 또는 그 반대
      String cropScale(Rect cr) {
        final cropAR = (cr.width * origW) / (cr.height * origH);
        final origAR = origW / origH;
        if (cropAR > origAR) {
          // 크롭이 더 넓음 → 가로를 원본에 맞추고 세로는 비율 유지
          final w = origW % 2 == 0 ? origW : origW + 1;
          return 'scale=$w:-2';
        } else {
          // 크롭이 더 좁음 → 세로를 원본에 맞추고 가로는 비율 유지
          final h = origH % 2 == 0 ? origH : origH + 1;
          return 'scale=-2:$h';
        }
      }

      if (cropSegments.length == 1) {
        // 단일 크롭 구간
        final seg = cropSegments.first;
        if (seg.hasCrop) {
          final cr = seg.cropRect;
          final cw = '${cr.width.toStringAsFixed(4)}*iw';
          final ch = '${cr.height.toStringAsFixed(4)}*ih';
          final cx = '${cr.left.toStringAsFixed(4)}*iw';
          final cy = '${cr.top.toStringAsFixed(4)}*ih';
          final sc = cropScale(cr);
          filters.add(
              '${cropInput}crop=$cw:$ch:$cx:$cy,$sc[vcrop]');
        }
      } else {
        // 다중 크롭 구간 — trim+crop per segment, then concat, then scale
        _buildMultiSegmentCrop(
            filters, cropSegments, cropInput, origW, origH);
      }
    }

    // --- 오버레이 스티커 (PNG 이미지 overlay) ---
    // Flutter Canvas에서 렌더링한 PNG를 overlay 필터로 합성 (drawtext 대신)
    if (hasOverlayImages) {
      String currentLabel = hasCrop
          ? '[vcrop]'
          : (hasSpeedChange ? '[vspeed]' : baseVideoLabel);

      for (int i = 0; i < overlays.length; i++) {
        final isLast = i == overlays.length - 1 && !hasSubtitleImages && !hasScale;
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
    } else if ((hasSpeedChange || hasCrop || hasMediaCut) && !hasSubtitleImages && !hasScale) {
      // 오버레이/자막/스케일 없이 배속/크롭/미디어컷만 있는 경우 최종 출력 라벨로 변환
      final targetLabel = hasCrop ? '[vcrop]' : (hasSpeedChange ? '[vspeed]' : '[vmedia]');
      final lastIdx = filters.lastIndexWhere((f) => f.contains(targetLabel));
      if (lastIdx >= 0) {
        filters[lastIdx] = filters[lastIdx].replaceAll(targetLabel, '[vout]');
      }
    }

    // --- 자막 (PNG 이미지 overlay) ---
    // Flutter Canvas에서 렌더링한 PNG를 overlay 필터로 합성
    if (hasSubtitleImages) {
      String currentLabel;
      if (hasOverlayImages) {
        currentLabel = '[vovl${overlays.length - 1}]';
      } else if (hasCrop) {
        currentLabel = '[vcrop]';
      } else if (hasSpeedChange) {
        currentLabel = '[vspeed]';
      } else {
        currentLabel = baseVideoLabel;
      }

      for (int i = 0; i < subtitles.length; i++) {
        final isLast = i == subtitles.length - 1 && !hasScale;
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

    // --- 해상도 스케일링 ---
    if (hasScale) {
      // 마지막 비디오 필터의 출력 라벨을 찾아서 scale 체인 연결
      String scaleInput;
      if (hasSubtitleImages) {
        scaleInput = '[vsub${subtitles.length - 1}]';
      } else if (hasOverlayImages) {
        scaleInput = '[vovl${overlays.length - 1}]';
      } else if (hasCrop) {
        scaleInput = '[vcrop]';
      } else if (hasSpeedChange) {
        scaleInput = '[vspeed]';
      } else {
        scaleInput = baseVideoLabel;
      }
      filters.add('${scaleInput}scale=-2:$targetHeight[vout]');
    }

    final result = filters.isEmpty ? null : filters.join(';');
    debugPrint('[FFmpeg] filter_complex: $result');
    return result;
  }

  static void _buildMultiSegmentSpeed(
      List<String> filters, List<SpeedSegment> segments,
      [String baseVideo = '[0:v]', String baseAudio = '[0:a]']) {
    final videoLabels = <String>[];
    final audioLabels = <String>[];

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final startSec = seg.start.inMilliseconds / 1000.0;
      final endSec = seg.end.inMilliseconds / 1000.0;
      final pts = (1.0 / seg.speed).toStringAsFixed(4);

      filters.add(
        '${baseVideo}trim=start=$startSec:end=$endSec,setpts=$pts*(PTS-STARTPTS)[v$i]',
      );
      videoLabels.add('[v$i]');

      final atempo = buildAtempoChain(seg.speed);
      filters.add(
        '${baseAudio}atrim=start=$startSec:end=$endSec,asetpts=PTS-STARTPTS,$atempo[a$i]',
      );
      audioLabels.add('[a$i]');
    }

    final n = segments.length;
    filters.add('${videoLabels.join()}concat=n=$n:v=1:a=0[vspeed]');
    filters.add('${audioLabels.join()}concat=n=$n:v=0:a=1[aout]');
  }

  /// 다중 크롭 구간: 각 구간을 crop → 통일 해상도로 scale → concat
  ///
  /// concat 필터는 모든 입력의 해상도가 동일해야 하므로,
  /// 모든 구간을 동일한 출력 해상도(종횡비 유지 기준)로 맞춘다.
  static void _buildMultiSegmentCrop(List<String> filters,
      List<CropSegment> segments, String inputLabel, int origW, int origH) {
    final cropLabels = <String>[];
    const fps = 30;
    const transitionDurationSec = 0.3;
    final transitionFrames = (transitionDurationSec * fps).round(); // 9

    // 모든 구간에 통일된 출력 해상도 결정:
    // 첫 번째 hasCrop 구간의 종횡비를 기준으로 한다.
    // 세로 기준으로 원본 높이에 맞추고, 가로는 종횡비에 따라 결정.
    final refSeg = segments.firstWhere((s) => s.hasCrop, orElse: () => segments.first);
    final refCr = refSeg.cropRect;
    final cropAR = (refCr.width * origW) / (refCr.height * origH);
    final origAR = origW / origH;
    final int outW;
    final int outH;
    if (cropAR > origAR) {
      // 크롭이 더 넓음 → 가로를 원본에 맞추고 세로는 비율 유지
      outW = origW % 2 == 0 ? origW : origW + 1;
      final h = (outW / cropAR).round();
      outH = h % 2 == 0 ? h : h + 1;
    } else {
      // 크롭이 더 좁음 → 세로를 원본에 맞추고 가로는 비율 유지
      outH = origH % 2 == 0 ? origH : origH + 1;
      final w = (outH * cropAR).round();
      outW = w % 2 == 0 ? w : w + 1;
    }
    final scaleUp = ',scale=$outW:$outH';

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final startSec = seg.start.inMilliseconds / 1000.0;
      final endSec = seg.end.inMilliseconds / 1000.0;

      if (seg.animateTransition && i > 0) {
        // 이전 구간에서 현재 구간으로 전환 애니메이션
        final prev = segments[i - 1];
        final prevCr = prev.cropRect;
        final cr = seg.cropRect;

        final durSec = endSec - startSec;
        final totalFrames = (durSec * fps).round();
        final tranFrames = transitionFrames.clamp(1, totalFrames);

        final lerpLeft =
            "'(${_lerpExpr(prevCr.left, cr.left, tranFrames)})*iw'";
        final lerpTop =
            "'(${_lerpExpr(prevCr.top, cr.top, tranFrames)})*ih'";
        final lerpW =
            "'(${_lerpExpr(prevCr.width, cr.width, tranFrames)})*iw'";
        final lerpH =
            "'(${_lerpExpr(prevCr.height, cr.height, tranFrames)})*ih'";

        filters.add(
          '${inputLabel}trim=start=$startSec:end=$endSec,setpts=PTS-STARTPTS,'
          'crop=w=$lerpW:h=$lerpH:x=$lerpLeft:y=$lerpTop$scaleUp[vc$i]',
        );
      } else {
        // 고정 크롭
        final cr = seg.cropRect;
        if (seg.hasCrop) {
          final cw = '${cr.width.toStringAsFixed(4)}*iw';
          final ch = '${cr.height.toStringAsFixed(4)}*ih';
          final cx = '${cr.left.toStringAsFixed(4)}*iw';
          final cy = '${cr.top.toStringAsFixed(4)}*ih';
          filters.add(
            '${inputLabel}trim=start=$startSec:end=$endSec,setpts=PTS-STARTPTS,'
            'crop=$cw:$ch:$cx:$cy$scaleUp[vc$i]',
          );
        } else {
          // 크롭 없는 구간도 통일 해상도로 맞춤
          filters.add(
            '${inputLabel}trim=start=$startSec:end=$endSec,setpts=PTS-STARTPTS$scaleUp[vc$i]',
          );
        }
      }
      cropLabels.add('[vc$i]');
    }

    final n = segments.length;
    filters.add('${cropLabels.join()}concat=n=$n:v=1:a=0[vcrop]');
  }

  static String _lerpExpr(double from, double to, int frames) {
    final a = from.toStringAsFixed(4);
    final b = to.toStringAsFixed(4);
    return '(1-min(n/$frames\\,1))*$a+min(n/$frames\\,1)*$b';
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

  /// 업로드용 압축 명령 생성 (단순 재인코딩 + 스케일링)
  static List<String> buildCompressArgs({
    required String inputPath,
    required String outputPath,
    required int targetHeight,
    int crf = 28,
    String preset = 'fast',
  }) {
    return [
      '-y',
      '-i', inputPath,
      '-vf', 'scale=-2:$targetHeight',
      '-c:v', 'libx264',
      '-preset', preset,
      '-crf', '$crf',
      '-c:a', 'aac',
      '-b:a', '96k',
      '-movflags', '+faststart',
      '-r', '30',
      outputPath,
    ];
  }

  static String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    final millis = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds.$millis';
  }

}
