import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 기본 폰트(NanumGothic-Bold.ttf)를 캐시 디렉토리에 복사하여
/// FFmpeg drawtext에서 사용할 수 있도록 하는 서비스
class CustomFontService {
  CustomFontService._();

  /// TTF 포맷 사용 (OTF/CFF보다 FFmpeg FreeType 호환성이 높음)
  static const _defaultFontFile = 'NanumGothic-Bold.ttf';

  /// 기본 폰트를 캐시 디렉토리에 복사 (최초 1회)
  /// 캐시 디렉토리는 FFmpeg 네이티브 코드에서 접근이 확실함
  static Future<void> ensureDefaultFonts() async {
    final cacheDir = await getTemporaryDirectory();
    final fontFile = File('${cacheDir.path}/$_defaultFontFile');
    if (!await fontFile.exists()) {
      try {
        final data = await rootBundle.load('assets/fonts/$_defaultFontFile');
        await fontFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
        debugPrint('[CustomFontService] 폰트 복사 완료: ${fontFile.path}');
      } catch (e) {
        debugPrint('[CustomFontService] 폰트 복사 실패: $e');
      }
    }
  }

  /// FFmpeg에서 사용할 기본 폰트 경로 반환
  static Future<String?> getDefaultFontPath() async {
    final cacheDir = await getTemporaryDirectory();
    final fontFile = File('${cacheDir.path}/$_defaultFontFile');
    if (await fontFile.exists()) {
      return fontFile.path;
    }
    // 없으면 복사 시도
    try {
      final data = await rootBundle.load('assets/fonts/$_defaultFontFile');
      await fontFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return fontFile.path;
    } catch (e) {
      debugPrint('[CustomFontService] 폰트 경로 가져오기 실패: $e');
      return null;
    }
  }
}
