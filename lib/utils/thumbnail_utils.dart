import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:video_thumbnail/video_thumbnail.dart';

/// 영상 파일에서 JPEG 썸네일을 생성하여 로컬에 저장한다.
/// 실패 시 null 반환 (기록 저장에 영향 없음).
Future<String?> generateThumbnail(String videoPath) async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final thumbDir = Directory(p.join(appDir.path, 'thumbnails'));
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final thumbPath = p.join(thumbDir.path, '$timestamp.jpg');

    final result = await VideoThumbnail.thumbnailFile(
      video: videoPath,
      thumbnailPath: thumbDir.path,
      imageFormat: ImageFormat.JPEG,
      maxHeight: 200,
      quality: 75,
    );

    if (result != null && result.isNotEmpty) {
      final generatedFile = File(result);
      if (await generatedFile.exists()) {
        final finalFile = await generatedFile.rename(thumbPath);
        return finalFile.path;
      }
    }
    return null;
  } catch (_) {
    return null;
  }
}
