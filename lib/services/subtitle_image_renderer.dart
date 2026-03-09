import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

import '../models/subtitle_item.dart';
import '../models/video_edit_models.dart';

/// 텍스트를 PNG 이미지로 렌더링하는 서비스.
///
/// FFmpeg drawtext의 한글 advance width 버그 및 Android fontfile 미지정 이슈를
/// 우회하기 위해 Flutter Canvas에서 직접 렌더링 후 overlay 필터로 합성한다.
class SubtitleImageRenderer {
  SubtitleImageRenderer._();

  /// 오버레이 스티커를 PNG 이미지로 렌더링하고 파일 경로 리스트를 반환
  static Future<List<String>> renderOverlays({
    required List<OverlayItem> overlays,
    required ui.Size videoResolution,
  }) async {
    final cacheDir = await getTemporaryDirectory();
    final outputDir = Directory('${cacheDir.path}/overlay_imgs');
    if (await outputDir.exists()) {
      await outputDir.delete(recursive: true);
    }
    await outputDir.create(recursive: true);

    final paths = <String>[];
    for (int i = 0; i < overlays.length; i++) {
      final path = await _renderOverlay(
        item: overlays[i],
        videoResolution: videoResolution,
        outputPath: '${outputDir.path}/ovl_$i.png',
      );
      paths.add(path);
    }
    return paths;
  }

  static Future<String> _renderOverlay({
    required OverlayItem item,
    required ui.Size videoResolution,
    required String outputPath,
  }) async {
    final scale = videoResolution.height / 800;
    final fontSize = item.fontSize * scale;

    // 텍스트 측정
    final paragraph = _buildParagraph(
      text: item.text,
      fontSize: fontSize,
      color: item.color,
      isBold: true,
      maxWidth: videoResolution.width * 0.9,
    );

    final textW = paragraph.longestLine.ceilToDouble();
    final textH = paragraph.height.ceilToDouble();

    if (textW <= 0 || textH <= 0) {
      return _createEmptyPng(outputPath);
    }

    // 패딩
    final pad = item.backgroundColor != null ? 8.0 * scale : 4.0 * scale;
    final contentW = textW + pad * 2;
    final contentH = textH + pad * 2;

    final imgWi = contentW.ceil();
    final imgHi = contentH.ceil();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // 배경
    if (item.backgroundColor != null) {
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(0, 0, contentW, contentH),
          ui.Radius.circular(14 * scale),
        ),
        ui.Paint()..color = item.backgroundColor!.withOpacity(0.85),
      );
    }

    // 외곽선 (텍스트 가독성)
    final strokeParagraph = _buildStrokeParagraph(
      text: item.text,
      fontSize: fontSize,
      strokeColor: const ui.Color(0x80000000),
      strokeWidth: 2 * scale,
      isBold: true,
      maxWidth: videoResolution.width * 0.9,
    );
    canvas.drawParagraph(strokeParagraph, ui.Offset(pad, pad));

    // 텍스트 본체
    canvas.drawParagraph(paragraph, ui.Offset(pad, pad));

    // PNG로 변환
    final picture = recorder.endRecording();
    final image = await picture.toImage(imgWi, imgHi);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    await File(outputPath)
        .writeAsBytes(byteData!.buffer.asUint8List(), flush: true);

    image.dispose();

    debugPrint(
        '[OverlayRenderer] "${item.text}" → ${imgWi}x$imgHi ($outputPath)');
    return outputPath;
  }

  /// 모든 자막을 PNG 이미지로 렌더링하고 파일 경로 리스트를 반환
  static Future<List<String>> renderAll({
    required List<SubtitleItem> subtitles,
    required ui.Size videoResolution,
  }) async {
    final cacheDir = await getTemporaryDirectory();
    final outputDir = Directory('${cacheDir.path}/subtitle_imgs');
    if (await outputDir.exists()) {
      await outputDir.delete(recursive: true);
    }
    await outputDir.create(recursive: true);

    final paths = <String>[];
    for (int i = 0; i < subtitles.length; i++) {
      final path = await _renderOne(
        item: subtitles[i],
        videoResolution: videoResolution,
        outputPath: '${outputDir.path}/sub_$i.png',
      );
      paths.add(path);
    }
    return paths;
  }

  static Future<String> _renderOne({
    required SubtitleItem item,
    required ui.Size videoResolution,
    required String outputPath,
  }) async {
    final scale = videoResolution.height / 800;
    final fontSize = item.fontSize * scale;
    final strokeWidth = item.strokeWidth * scale;

    // 텍스트 측정
    final paragraph = _buildParagraph(
      text: item.text,
      fontSize: fontSize,
      color: item.color,
      isBold: item.isBold,
      maxWidth: videoResolution.width * 0.9,
    );

    final textW = paragraph.longestLine.ceilToDouble();
    final textH = paragraph.height.ceilToDouble();

    if (textW <= 0 || textH <= 0) {
      return _createEmptyPng(outputPath);
    }

    // 패딩 (외곽선/배경 여백)
    final pad = math.max(
      strokeWidth * 2,
      item.backgroundColor != null ? 8.0 * scale : 0.0,
    );

    // 회전 시 필요한 바운딩 박스 계산
    final contentW = textW + pad * 2;
    final contentH = textH + pad * 2;
    final angle = item.rotation;

    final double imgW;
    final double imgH;
    if (angle == 0.0) {
      imgW = contentW;
      imgH = contentH;
    } else {
      final cosA = math.cos(angle).abs();
      final sinA = math.sin(angle).abs();
      imgW = contentW * cosA + contentH * sinA;
      imgH = contentW * sinA + contentH * cosA;
    }

    final imgWi = imgW.ceil();
    final imgHi = imgH.ceil();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // 회전 적용 (중심 기준)
    if (angle != 0.0) {
      canvas.translate(imgWi / 2, imgHi / 2);
      canvas.rotate(angle);
      canvas.translate(-contentW / 2, -contentH / 2);
    } else {
      // 회전 없으면 좌상단 기준
      canvas.translate((imgWi - contentW) / 2, (imgHi - contentH) / 2);
    }

    // 배경
    if (item.backgroundColor != null) {
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(0, 0, contentW, contentH),
          const ui.Radius.circular(4),
        ),
        ui.Paint()..color = item.backgroundColor!.withOpacity(0.6),
      );
    }

    // 그림자
    if (item.hasShadow) {
      final shadow = _buildParagraph(
        text: item.text,
        fontSize: fontSize,
        color: const ui.Color(0x80000000),
        isBold: item.isBold,
        maxWidth: videoResolution.width * 0.9,
      );
      canvas.drawParagraph(shadow, ui.Offset(pad + 2 * scale, pad + 2 * scale));
    }

    // 외곽선
    if (item.strokeColor != null && strokeWidth > 0) {
      final strokeParagraph = _buildStrokeParagraph(
        text: item.text,
        fontSize: fontSize,
        strokeColor: item.strokeColor!,
        strokeWidth: strokeWidth,
        isBold: item.isBold,
        maxWidth: videoResolution.width * 0.9,
      );
      canvas.drawParagraph(strokeParagraph, ui.Offset(pad, pad));
    }

    // 텍스트 본체
    canvas.drawParagraph(paragraph, ui.Offset(pad, pad));

    // PNG로 변환
    final picture = recorder.endRecording();
    final image = await picture.toImage(imgWi, imgHi);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    await File(outputPath)
        .writeAsBytes(byteData!.buffer.asUint8List(), flush: true);

    image.dispose();

    debugPrint(
        '[SubtitleRenderer] "${ item.text}" → ${imgWi}x$imgHi ($outputPath)');
    return outputPath;
  }

  static ui.Paragraph _buildParagraph({
    required String text,
    required double fontSize,
    required ui.Color color,
    required bool isBold,
    required double maxWidth,
  }) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textDirection: ui.TextDirection.ltr,
    ))
      ..pushStyle(ui.TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: isBold ? FontWeight.w800 : FontWeight.normal,
      ))
      ..addText(text);
    final p = builder.build();
    p.layout(ui.ParagraphConstraints(width: maxWidth));
    return p;
  }

  static ui.Paragraph _buildStrokeParagraph({
    required String text,
    required double fontSize,
    required ui.Color strokeColor,
    required double strokeWidth,
    required bool isBold,
    required double maxWidth,
  }) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textDirection: ui.TextDirection.ltr,
    ))
      ..pushStyle(ui.TextStyle(
        fontSize: fontSize,
        fontWeight: isBold ? FontWeight.w800 : FontWeight.normal,
        foreground: ui.Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = strokeColor,
      ))
      ..addText(text);
    final p = builder.build();
    p.layout(ui.ParagraphConstraints(width: maxWidth));
    return p;
  }

  static Future<String> _createEmptyPng(String outputPath) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1, 1);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(outputPath)
        .writeAsBytes(byteData!.buffer.asUint8List(), flush: true);
    image.dispose();
    return outputPath;
  }
}
