import 'package:flutter_test/flutter_test.dart';
import 'package:wandeung/models/video_edit_models.dart';

void main() {
  group('ExportQuality', () {
    test('only has fullHd option (4K removed)', () {
      expect(ExportQuality.values.length, 1);
      expect(ExportQuality.fullHd.targetHeight, 1080);
      expect(ExportQuality.fullHd.crf, 20);
      expect(ExportQuality.fullHd.label, '1080p');
    });
  });

  group('UploadCompression', () {
    test('Free tier settings', () {
      expect(UploadCompression.freeTargetHeight, 720);
      expect(UploadCompression.freeCrf, 28);
    });

    test('Pro tier settings', () {
      expect(UploadCompression.proTargetHeight, 1080);
      expect(UploadCompression.proCrf, 20);
    });

    test('backward-compatible defaults match Free tier', () {
      expect(UploadCompression.targetHeight, UploadCompression.freeTargetHeight);
      expect(UploadCompression.crf, UploadCompression.freeCrf);
    });

    test('preset is fast', () {
      expect(UploadCompression.preset, 'fast');
    });
  });

  group('SpeedSegment', () {
    test('adjustedDuration accounts for speed', () {
      final seg = SpeedSegment(
        start: Duration.zero,
        end: const Duration(seconds: 10),
        speed: 2.0,
      );
      expect(seg.adjustedDuration.inSeconds, 5);
    });

    test('originalDuration is correct', () {
      final seg = SpeedSegment(
        start: const Duration(seconds: 5),
        end: const Duration(seconds: 15),
      );
      expect(seg.originalDuration.inSeconds, 10);
    });
  });
}
