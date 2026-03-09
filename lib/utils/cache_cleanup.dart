import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 앱 캐시 디렉토리의 불필요한 파일을 정리한다.
///
/// 촬영/편집/저장 과정에서 camera, FFmpeg, video_player,
/// get_thumbnail_video 등이 캐시에 남기는 임시 파일을 삭제.
class CacheCleanup {
  CacheCleanup._();

  /// 보존할 파일 (FFmpeg 한글 폰트)
  static const _preserveFiles = {'NanumGothic-Bold.ttf'};

  /// 캐시 디렉토리 내용을 로그로 출력 (디버그용)
  static Future<void> logCacheContents() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final appDir = await getApplicationDocumentsDirectory();
      debugPrint('========== [CacheCleanup] 캐시 진단 ==========');
      debugPrint('[Cache] 경로: ${cacheDir.path}');
      await _logDirectoryContents(cacheDir, depth: 0);
      debugPrint('---------- [AppData] 경로: ${appDir.path} ----------');
      await _logDirectoryContents(appDir, depth: 0);
      debugPrint('========== [CacheCleanup] 진단 끝 ==========');
    } catch (e) {
      debugPrint('[CacheCleanup] 진단 실패: $e');
    }
  }

  static Future<void> _logDirectoryContents(Directory dir, {int depth = 0}) async {
    final indent = '  ' * depth;
    try {
      final entries = dir.listSync();
      for (final entry in entries) {
        final name = p.basename(entry.path);
        if (entry is File) {
          final size = await entry.length();
          final sizeStr = _formatSize(size);
          debugPrint('$indent  📄 $name ($sizeStr)');
        } else if (entry is Directory) {
          final dirSize = await _getDirectorySize(entry);
          final sizeStr = _formatSize(dirSize);
          debugPrint('$indent  📁 $name/ ($sizeStr)');
          if (depth < 2) {
            await _logDirectoryContents(entry, depth: depth + 1);
          }
        }
      }
    } catch (e) {
      debugPrint('$indent  ⚠️ 읽기 실패: $e');
    }
  }

  static Future<int> _getDirectorySize(Directory dir) async {
    int size = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          size += await entity.length();
        }
      }
    } catch (_) {}
    return size;
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 캐시 디렉토리 전체 정리
  static Future<void> clearAppCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final entries = cacheDir.listSync();
      for (final entry in entries) {
        final name = p.basename(entry.path);
        if (_preserveFiles.contains(name)) continue;
        try {
          if (entry is Directory) {
            await entry.delete(recursive: true);
          } else if (entry is File) {
            await entry.delete();
          }
        } catch (e) {
          debugPrint('[CacheCleanup] 삭제 실패: ${entry.path} ($e)');
        }
      }
    } catch (e) {
      debugPrint('[CacheCleanup] 캐시 정리 실패: $e');
    }
  }
}
