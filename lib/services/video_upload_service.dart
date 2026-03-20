import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/r2_config.dart';
import '../providers/subscription_provider.dart';

/// 클라우드 용량 초과 예외
class StorageQuotaExceededException implements Exception {
  final int usedBytes;
  final int limitBytes;
  const StorageQuotaExceededException(this.usedBytes, this.limitBytes);

  @override
  String toString() =>
      '저장 공간이 가득 찼습니다 (${(usedBytes / 1024 / 1024).toStringAsFixed(1)} MB / '
      '${(limitBytes / 1024 / 1024).toStringAsFixed(0)} MB)';
}

class VideoUploadService {
  static final _supabase = Supabase.instance.client;

  /// 사용자의 클라우드 사용량 조회 (바이트)
  static Future<int> getCloudUsage(String userId) async {
    final response = await _supabase
        .from('climbing_records')
        .select('file_size_bytes')
        .eq('user_id', userId)
        .eq('local_only', false)
        .not('video_path', 'like', '/%');

    int total = 0;
    for (final row in response as List) {
      final size = row['file_size_bytes'];
      if (size != null) total += (size as num).toInt();
    }
    return total;
  }

  /// Free 티어 용량 체크 — 초과 시 예외 발생
  static Future<void> checkQuota({
    required String userId,
    required int fileSizeBytes,
    required bool isPro,
  }) async {
    if (isPro) return; // Pro는 무제한

    final currentUsage = await getCloudUsage(userId);
    if (currentUsage + fileSizeBytes > freeStorageLimitBytes) {
      throw StorageQuotaExceededException(
          currentUsage, freeStorageLimitBytes);
    }
  }

  /// 영상을 R2에 업로드하고 DB 경로를 업데이트
  static Future<void> uploadVideoAndUpdateRecord({
    required String recordId,
    required String localVideoPath,
    required String userId,
    bool isExport = false,
  }) async {
    final file = File(localVideoPath);
    if (!file.existsSync()) {
      throw FileSystemException('영상 파일을 찾을 수 없습니다', localVideoPath);
    }

    final prefix = isExport ? 'export_' : '';
    final objectKey = 'video/$userId/$prefix$recordId.mp4';
    await R2Config.uploadFile(
      objectKey: objectKey,
      file: file,
      contentType: 'video/mp4',
      cacheControl: 'public, max-age=31536000, immutable',
    );

    // 파일 크기도 함께 업데이트
    final fileSize = await file.length();
    await _supabase.from('climbing_records').update({
      'video_path': objectKey,
      'file_size_bytes': fileSize,
    }).eq('id', recordId);
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
      await R2Config.deleteAllFiles('video/$userId/');
      await R2Config.deleteAllFiles('thumbnail/$userId/');
    } catch (e) {
      debugPrint('R2 전체 삭제 실패: $e');
    }
  }
}
