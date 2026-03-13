import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/r2_config.dart';

class VideoUploadService {
  static final _supabase = Supabase.instance.client;

  /// 영상을 R2에 업로드하고 DB 경로를 업데이트
  static Future<void> uploadVideoAndUpdateRecord({
    required String recordId,
    required String localVideoPath,
    required String userId,
  }) async {
    final file = File(localVideoPath);
    if (!file.existsSync()) {
      throw FileSystemException('영상 파일을 찾을 수 없습니다', localVideoPath);
    }

    final objectKey = 'video/$userId/$recordId.mp4';
    await R2Config.uploadFile(
      objectKey: objectKey,
      file: file,
      contentType: 'video/mp4',
      cacheControl: 'public, max-age=31536000, immutable',
    );

    await _supabase
        .from('climbing_records')
        .update({'video_path': objectKey}).eq('id', recordId);
  }

  /// 썸네일을 R2에 업로드하고 DB 경로를 업데이트
  static Future<void> uploadThumbnailAndUpdateRecord({
    required String recordId,
    required String localThumbnailPath,
    required String userId,
  }) async {
    final file = File(localThumbnailPath);
    if (!file.existsSync()) {
      throw FileSystemException('썸네일 파일을 찾을 수 없습니다', localThumbnailPath);
    }

    final objectKey = 'thumbnail/$userId/$recordId.jpg';
    await R2Config.uploadFile(
      objectKey: objectKey,
      file: file,
      contentType: 'image/jpeg',
      cacheControl: 'public, max-age=31536000, immutable',
    );

    await _supabase
        .from('climbing_records')
        .update({'thumbnail_path': objectKey}).eq('id', recordId);
  }

  /// 특정 기록의 리모트 파일 삭제 (영상 + 썸네일)
  static Future<void> deleteRemoteFiles({
    required String userId,
    required String recordId,
  }) async {
    try {
      await R2Config.deleteFile('video/$userId/$recordId.mp4');
    } catch (e) {
      debugPrint('R2 영상 삭제 실패: $e');
    }
    try {
      await R2Config.deleteFile('thumbnail/$userId/$recordId.jpg');
    } catch (e) {
      debugPrint('R2 썸네일 삭제 실패: $e');
    }
  }

  /// 사용자의 모든 리모트 파일 삭제 (회원탈퇴)
  static Future<void> deleteAllUserFiles(String userId) async {
    try {
      // 영상 삭제
      final videoKeys = await R2Config.listObjects('video/$userId/');
      for (final key in videoKeys) {
        await R2Config.deleteFile(key);
      }
      // 썸네일 삭제
      final thumbnailKeys = await R2Config.listObjects('thumbnail/$userId/');
      for (final key in thumbnailKeys) {
        await R2Config.deleteFile(key);
      }
    } catch (e) {
      debugPrint('R2 전체 삭제 실패: $e');
    }
  }
}
