import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/r2_config.dart';

/// R2 원격 영상을 로컬 임시 디렉토리에 다운로드·캐시한다.
class VideoDownloadCache {
  VideoDownloadCache._();

  static const _cacheDir = 'r2_video_cache';

  /// [objectKey]에 해당하는 로컬 캐시 경로를 반환한다.
  /// 이미 캐시되어 있으면 즉시 반환, 아니면 다운로드 후 반환.
  /// [onProgress]는 0.0~1.0 범위의 진행률을 콜백한다.
  static Future<String> getLocalPath(
    String objectKey, {
    void Function(double progress)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory('${tempDir.path}/$_cacheDir');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final fileName = objectKey.replaceAll('/', '_');
    final file = File('${dir.path}/$fileName');

    if (file.existsSync() && file.lengthSync() > 0) {
      return file.path;
    }

    final url = R2Config.getPresignedUrl(objectKey);
    final request = http.Request('GET', Uri.parse(url));
    final client = http.Client();

    try {
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw HttpException(
          '영상 다운로드 실패 (${response.statusCode})',
          uri: Uri.parse(url),
        );
      }

      final totalBytes = response.contentLength ?? -1;
      int receivedBytes = 0;
      final chunks = <List<int>>[];

      await for (final chunk in response.stream) {
        chunks.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(receivedBytes / totalBytes);
        }
      }

      final bytes = BytesBuilder(copy: false);
      for (final chunk in chunks) {
        bytes.add(chunk);
      }
      await file.writeAsBytes(bytes.takeBytes());
      return file.path;
    } finally {
      client.close();
    }
  }

  /// 다운로드 실패 시 부분 파일을 삭제한다.
  static Future<void> cleanupPartialFile(String objectKey) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = objectKey.replaceAll('/', '_');
      final file = File('${tempDir.path}/$_cacheDir/$fileName');
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }
}

/// R2 영상을 다운로드하면서 진행률 다이얼로그를 표시한다.
/// 성공 시 로컬 경로, 실패 시 null 반환.
Future<String?> downloadRemoteVideoWithDialog(
  BuildContext context,
  String objectKey,
) async {
  final progress = ValueNotifier<double>(0.0);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: progress,
                  builder: (_, value, __) => CircularProgressIndicator(
                    value: value > 0 ? value : null,
                  ),
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<double>(
                  valueListenable: progress,
                  builder: (_, value, __) => Text(
                    value > 0
                        ? '영상 다운로드 중... ${(value * 100).toInt()}%'
                        : '영상 다운로드 중...',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  try {
    final localPath = await VideoDownloadCache.getLocalPath(
      objectKey,
      onProgress: (v) => progress.value = v,
    );
    if (context.mounted) Navigator.of(context).pop();
    progress.dispose();
    return localPath;
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('네트워크 오류로 영상을 다운로드할 수 없습니다')),
      );
    }
    progress.dispose();
    await VideoDownloadCache.cleanupPartialFile(objectKey);
    return null;
  }
}
