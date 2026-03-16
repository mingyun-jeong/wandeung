import 'package:flutter_test/flutter_test.dart';
import 'package:wandeung/models/climbing_record.dart';

void main() {
  group('ClimbingRecord', () {
    test('fileSize is not included in toInsertMap (updated via upload service)', () {
      final record = ClimbingRecord(
        userId: 'user1',
        grade: 'v3',
        difficultyColor: 'red',
        status: 'completed',
        recordedAt: DateTime(2026, 3, 16),
        fileSize: 25000000,
      );

      final map = record.toInsertMap();
      expect(map.containsKey('file_size_bytes'), isFalse);
    });

    test('fromMap parses fileSize', () {
      final map = {
        'id': 'abc',
        'user_id': 'user1',
        'gym_id': null,
        'grade': 'v3',
        'difficulty_color': 'red',
        'status': 'completed',
        'video_path': 'video/user1/abc.mp4',
        'thumbnail_path': null,
        'tags': <String>[],
        'memo': null,
        'recorded_at': '2026-03-16',
        'created_at': '2026-03-16T00:00:00Z',
        'parent_record_id': null,
        'video_duration_seconds': 90,
        'video_quality': '720p',
        'local_only': false,
        'file_size_bytes': 25000000,
      };

      final record = ClimbingRecord.fromMap(map);
      expect(record.fileSize, 25000000);
    });

    test('fromMap handles null fileSize', () {
      final map = {
        'id': 'abc',
        'user_id': 'user1',
        'gym_id': null,
        'grade': 'v3',
        'difficulty_color': 'red',
        'status': 'completed',
        'video_path': null,
        'thumbnail_path': null,
        'tags': null,
        'memo': null,
        'recorded_at': '2026-03-16',
        'created_at': null,
        'parent_record_id': null,
        'video_duration_seconds': null,
        'video_quality': null,
        'local_only': null,
        'file_size_bytes': null,
      };

      final record = ClimbingRecord.fromMap(map);
      expect(record.fileSize, isNull);
    });

    test('isLocalVideo works correctly', () {
      final localRecord = ClimbingRecord(
        userId: 'user1',
        grade: 'v3',
        difficultyColor: 'red',
        status: 'completed',
        recordedAt: DateTime(2026, 3, 16),
        videoPath: '/data/user/0/com.wandeung/files/video.mp4',
      );
      expect(localRecord.isLocalVideo, isTrue);

      final cloudRecord = ClimbingRecord(
        userId: 'user1',
        grade: 'v3',
        difficultyColor: 'red',
        status: 'completed',
        recordedAt: DateTime(2026, 3, 16),
        videoPath: 'video/user1/abc.mp4',
      );
      expect(cloudRecord.isLocalVideo, isFalse);
    });
  });
}
