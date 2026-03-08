import 'dart:ui';

class SubtitleItem {
  final String id;
  final String text;
  final Duration startTime;
  final Duration endTime;
  final Offset position;
  final double fontSize;
  final Color color;
  final Color? backgroundColor;
  final Color? strokeColor;
  final double strokeWidth;
  final bool isBold;
  final bool hasShadow;
  final double rotation; // 라디안 단위 (0 = 수평)

  const SubtitleItem({
    required this.id,
    required this.text,
    required this.startTime,
    required this.endTime,
    this.position = const Offset(0.5, 0.8),
    this.fontSize = 24.0,
    this.color = const Color(0xFFFFFFFF),
    this.backgroundColor,
    this.strokeColor,
    this.strokeWidth = 0.0,
    this.isBold = false,
    this.hasShadow = false,
    this.rotation = 0.0,
  });

  bool isVisibleAt(Duration time) {
    return time >= startTime && time < endTime;
  }

  SubtitleItem copyWith({
    String? id,
    String? text,
    Duration? startTime,
    Duration? endTime,
    Offset? position,
    double? fontSize,
    Color? color,
    Color? backgroundColor,
    bool clearBackground = false,
    Color? strokeColor,
    bool clearStroke = false,
    double? strokeWidth,
    bool? isBold,
    bool? hasShadow,
    double? rotation,
  }) {
    return SubtitleItem(
      id: id ?? this.id,
      text: text ?? this.text,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      position: position ?? this.position,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      backgroundColor: clearBackground ? null : (backgroundColor ?? this.backgroundColor),
      strokeColor: clearStroke ? null : (strokeColor ?? this.strokeColor),
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isBold: isBold ?? this.isBold,
      hasShadow: hasShadow ?? this.hasShadow,
      rotation: rotation ?? this.rotation,
    );
  }
}
