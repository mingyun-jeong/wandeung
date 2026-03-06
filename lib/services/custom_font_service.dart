import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/subtitle_item.dart';

class CustomFontService {
  CustomFontService._();

  static const _prefsKey = 'custom_fonts';

  /// 기본 제공 폰트 목록 (에셋 번들에 포함)
  static const List<CustomFont> defaultFonts = [
    CustomFont(name: 'Noto Sans KR Bold', filePath: 'NotoSansKR-Bold.otf'),
    CustomFont(name: 'Noto Sans KR Regular', filePath: 'NotoSansKR-Regular.otf'),
    CustomFont(name: '나눔고딕 Bold', filePath: 'NanumGothic-Bold.ttf'),
  ];

  /// 기본 폰트를 앱 문서 디렉토리에 복사 (최초 1회)
  static Future<void> ensureDefaultFonts() async {
    final appDir = await getApplicationDocumentsDirectory();
    for (final font in defaultFonts) {
      final fontFile = File('${appDir.path}/${font.filePath}');
      if (!await fontFile.exists()) {
        try {
          final data = await rootBundle.load('assets/fonts/${font.filePath}');
          await fontFile.writeAsBytes(data.buffer.asUint8List());
        } catch (_) {
          // 폰트 파일이 에셋에 없으면 무시
        }
      }
    }
  }

  /// 기본 폰트의 실제 파일 경로 반환
  static Future<String> getDefaultFontPath(String fileName) async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$fileName';
  }

  /// 커스텀 폰트 import (file_picker로 .ttf/.otf 선택)
  static Future<CustomFont?> importFont() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ttf', 'otf'],
    );

    if (result == null || result.files.isEmpty) return null;

    final pickedFile = result.files.first;
    if (pickedFile.path == null) return null;

    final appDir = await getApplicationDocumentsDirectory();
    final fontsDir = Directory('${appDir.path}/custom_fonts');
    if (!await fontsDir.exists()) {
      await fontsDir.create(recursive: true);
    }

    final fileName = pickedFile.name;
    final destPath = '${fontsDir.path}/$fileName';
    await File(pickedFile.path!).copy(destPath);

    final displayName = fileName.replaceAll(RegExp(r'\.(ttf|otf)$'), '');
    final font = CustomFont(name: displayName, filePath: destPath);

    await _addToPrefs(font);
    return font;
  }

  /// 저장된 커스텀 폰트 목록 로드
  static Future<List<CustomFont>> loadCustomFonts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefsKey);
    if (jsonStr == null) return [];

    final List<dynamic> list = jsonDecode(jsonStr);
    return list
        .map((e) => CustomFont.fromJson(e as Map<String, dynamic>))
        .where((f) => File(f.filePath).existsSync())
        .toList();
  }

  /// 커스텀 폰트 삭제
  static Future<void> deleteFont(CustomFont font) async {
    final file = File(font.filePath);
    if (await file.exists()) {
      await file.delete();
    }
    await _removeFromPrefs(font);
  }

  static Future<void> _addToPrefs(CustomFont font) async {
    final fonts = await loadCustomFonts();
    fonts.add(font);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey, jsonEncode(fonts.map((f) => f.toJson()).toList()));
  }

  static Future<void> _removeFromPrefs(CustomFont font) async {
    final fonts = await loadCustomFonts();
    fonts.removeWhere((f) => f.filePath == font.filePath);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey, jsonEncode(fonts.map((f) => f.toJson()).toList()));
  }
}
