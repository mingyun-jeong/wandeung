import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 타임라인용 썸네일 프레임을 일괄 추출한다.
///
/// [count]개의 프레임을 영상 전체에 균등하게 분포시켜 추출.
/// 추출된 JPEG 파일 경로 리스트를 반환한다.
Future<List<String>> generateTimelineThumbnails({
  required String videoPath,
  required Duration totalDuration,
  int count = 15,
}) async {
  if (totalDuration.inMilliseconds <= 0) return [];

  try {
    final tempDir = await getTemporaryDirectory();
    final thumbDir = Directory(
      p.join(tempDir.path, 'timeline_thumbs_${DateTime.now().millisecondsSinceEpoch}'),
    );
    await thumbDir.create(recursive: true);

    final totalSec = totalDuration.inMilliseconds / 1000.0;
    final fps = count / totalSec;

    final outputPattern = p.join(thumbDir.path, 'thumb_%03d.jpg');
    final command =
        '-i "$videoPath" -vf "fps=$fps,scale=60:-1" -q:v 8 "$outputPattern"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      debugPrint('타임라인 썸네일 생성 실패: returnCode=$returnCode');
      return [];
    }

    final files = thumbDir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    return files.map((f) => f.path).toList();
  } catch (e) {
    debugPrint('타임라인 썸네일 생성 오류: $e');
    return [];
  }
}
