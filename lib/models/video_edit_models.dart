import 'dart:ui';

/// 배속 구간 — 영상의 특정 시간 범위에 적용할 속도
class SpeedSegment {
  final Duration start;
  final Duration end;
  final double speed; // 0.25, 0.5, 1.0, 2.0, 4.0

  const SpeedSegment({
    required this.start,
    required this.end,
    this.speed = 1.0,
  });

  SpeedSegment copyWith({Duration? start, Duration? end, double? speed}) {
    return SpeedSegment(
      start: start ?? this.start,
      end: end ?? this.end,
      speed: speed ?? this.speed,
    );
  }

  /// 이 구간의 원본 길이
  Duration get originalDuration => end - start;

  /// 배속 적용 후 실제 재생 길이
  Duration get adjustedDuration =>
      Duration(milliseconds: (originalDuration.inMilliseconds / speed).round());
}

/// 비디오 위 오버레이 아이템 (V-Grade 스티커 등)
class OverlayItem {
  final String id;
  final String text; // "V3", "완등" 등
  final Offset position; // 정규화 좌표 (0.0~1.0)
  final double fontSize;
  final Color color;
  final Color? backgroundColor;
  final Duration? startTime; // null이면 영상 전체
  final Duration? endTime; // null이면 영상 전체
  final double rotation; // 라디안 단위 (기본 0.0)

  const OverlayItem({
    required this.id,
    required this.text,
    this.position = const Offset(0.5, 0.5),
    this.fontSize = 24.0,
    this.color = const Color(0xFFFFFFFF),
    this.backgroundColor,
    this.startTime,
    this.endTime,
    this.rotation = 0.0,
  });

  /// 주어진 시간에 이 스티커가 보이는지 여부
  bool isVisibleAt(Duration time) {
    if (startTime == null || endTime == null) return true;
    return time >= startTime! && time < endTime!;
  }

  OverlayItem copyWith({
    String? id,
    String? text,
    Offset? position,
    double? fontSize,
    Color? color,
    Color? backgroundColor,
    bool clearBackground = false,
    Duration? startTime,
    bool clearStartTime = false,
    Duration? endTime,
    bool clearEndTime = false,
    double? rotation,
  }) {
    return OverlayItem(
      id: id ?? this.id,
      text: text ?? this.text,
      position: position ?? this.position,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      backgroundColor:
          clearBackground ? null : (backgroundColor ?? this.backgroundColor),
      startTime: clearStartTime ? null : (startTime ?? this.startTime),
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      rotation: rotation ?? this.rotation,
    );
  }
}

/// 비디오 내보내기 결과
class VideoEditResult {
  final String outputPath;
  final Duration duration;

  const VideoEditResult({
    required this.outputPath,
    required this.duration,
  });
}
