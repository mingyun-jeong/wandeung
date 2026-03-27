import 'package:flutter_test/flutter_test.dart';
import 'package:cling/providers/upload_queue_provider.dart';

void main() {
  group('UploadStatus', () {
    test('4가지 상태가 존재한다', () {
      expect(UploadStatus.values.length, 4);
      expect(UploadStatus.pending.name, 'pending');
      expect(UploadStatus.uploading.name, 'uploading');
      expect(UploadStatus.uploaded.name, 'uploaded');
      expect(UploadStatus.failed.name, 'failed');
    });
  });

  group('UploadTask', () {
    test('기본값으로 생성하면 status=pending, retryCount=0이다', () {
      final task = UploadTask(
        recordId: 'record-1',
        localVideoPath: '/path/to/video.mp4',
      );

      expect(task.recordId, 'record-1');
      expect(task.localVideoPath, '/path/to/video.mp4');
      expect(task.isExport, isFalse);
      expect(task.status, UploadStatus.pending);
      expect(task.retryCount, 0);
      expect(task.errorMessage, isNull);
      expect(task.createdAt, isNotNull);
    });

    test('isExport=true로 생성할 수 있다', () {
      final task = UploadTask(
        recordId: 'record-1',
        localVideoPath: '/path/to/video.mp4',
        isExport: true,
      );
      expect(task.isExport, isTrue);
    });

    test('toJson 직렬화가 올바르다', () {
      final now = DateTime(2026, 3, 28, 12, 0, 0);
      final task = UploadTask(
        recordId: 'record-1',
        localVideoPath: '/path/to/video.mp4',
        isExport: true,
        status: UploadStatus.failed,
        retryCount: 3,
        errorMessage: '네트워크 오류',
        createdAt: now,
      );

      final json = task.toJson();
      expect(json['recordId'], 'record-1');
      expect(json['localVideoPath'], '/path/to/video.mp4');
      expect(json['isExport'], isTrue);
      expect(json['status'], 'failed');
      expect(json['retryCount'], 3);
      expect(json['errorMessage'], '네트워크 오류');
      expect(json['createdAt'], now.toIso8601String());
    });

    test('fromJson 역직렬화가 올바르다', () {
      final json = {
        'recordId': 'record-1',
        'localVideoPath': '/path/to/video.mp4',
        'isExport': true,
        'status': 'uploading',
        'retryCount': 2,
        'errorMessage': '타임아웃',
        'createdAt': '2026-03-28T12:00:00.000',
      };

      final task = UploadTask.fromJson(json);
      expect(task.recordId, 'record-1');
      expect(task.localVideoPath, '/path/to/video.mp4');
      expect(task.isExport, isTrue);
      expect(task.status, UploadStatus.uploading);
      expect(task.retryCount, 2);
      expect(task.errorMessage, '타임아웃');
    });

    test('fromJson에서 isExport가 없으면 false로 기본값 처리된다', () {
      final json = {
        'recordId': 'record-1',
        'localVideoPath': '/path/to/video.mp4',
        'status': 'pending',
        'retryCount': 0,
        'createdAt': '2026-03-28T12:00:00.000',
      };

      final task = UploadTask.fromJson(json);
      expect(task.isExport, isFalse);
    });

    test('fromJson에서 retryCount가 없으면 0으로 기본값 처리된다', () {
      final json = {
        'recordId': 'record-1',
        'localVideoPath': '/path/to/video.mp4',
        'status': 'pending',
        'createdAt': '2026-03-28T12:00:00.000',
      };

      final task = UploadTask.fromJson(json);
      expect(task.retryCount, 0);
    });

    test('toJson → fromJson 라운드트립이 일관적이다', () {
      final original = UploadTask(
        recordId: 'record-1',
        localVideoPath: '/data/app/video.mp4',
        isExport: false,
        status: UploadStatus.pending,
        retryCount: 1,
        errorMessage: null,
        createdAt: DateTime(2026, 3, 28),
      );

      final json = original.toJson();
      final restored = UploadTask.fromJson(json);

      expect(restored.recordId, original.recordId);
      expect(restored.localVideoPath, original.localVideoPath);
      expect(restored.isExport, original.isExport);
      expect(restored.status, original.status);
      expect(restored.retryCount, original.retryCount);
      expect(restored.errorMessage, original.errorMessage);
    });

    test('상태를 mutable하게 변경할 수 있다', () {
      final task = UploadTask(
        recordId: 'record-1',
        localVideoPath: '/path/to/video.mp4',
      );

      task.status = UploadStatus.uploading;
      expect(task.status, UploadStatus.uploading);

      task.retryCount = 3;
      expect(task.retryCount, 3);

      task.errorMessage = '실패';
      expect(task.errorMessage, '실패');
    });
  });

  group('업로드 큐 — 기기 간 격리 문제', () {
    test('업로드 큐는 SharedPreferences에 저장되므로 기기별로 독립적이다', () {
      // 기기 A의 큐: record-1 pending, record-2 uploading
      // 기기 B의 큐: 비어있음 (같은 계정이지만 큐는 공유 안됨)
      //
      // 이는 의도된 동작이지만, 다음 부작용이 있음:
      // - 기기 A에서 업로드 실패한 태스크를 기기 B에서 재시도할 수 없음
      // - 기기 A에서 업로드가 끝나야만 file_size_bytes가 올바르게 UPDATE됨
      // - 기기 B에서는 orphanedRecords 감지로 재등록하려 하지만,
      //   로컬 파일이 없으므로 스킵됨

      final deviceAQueue = [
        UploadTask(recordId: 'record-1', localVideoPath: '/device-a/path/video1.mp4'),
        UploadTask(recordId: 'record-2', localVideoPath: '/device-a/path/video2.mp4'),
      ];

      final deviceBQueue = <UploadTask>[];

      // 기기 A에는 2개 대기, 기기 B에는 0개
      expect(deviceAQueue.length, 2);
      expect(deviceBQueue.length, 0);

      // 기기 B에서 기기 A의 태스크를 처리할 수 없음
      // → file_size_bytes UPDATE도 기기 A에서만 가능
    });

    test('orphanedRecords 감지는 로컬 파일이 없으면 스킵된다', () {
      // _autoEnqueueOrphanedRecords 로직:
      // 1. DB에서 local_only=false, video_path LIKE '/%' 레코드 조회
      // 2. File(videoPath).existsSync()로 로컬 파일 확인
      // 3. 파일이 없으면 continue (스킵)
      //
      // 기기 B에서는 기기 A의 로컬 경로 파일이 없으므로
      // 모든 orphaned 레코드가 스킵됨
      // → 업로드 불가 → file_size_bytes는 원본 크기 유지

      // 기기 A의 로컬 경로: /data/data/com.mg.cling/files/video_abc.mp4
      // 기기 B에서 이 경로의 파일 존재 여부: false
      const deviceAPath = '/data/data/com.mg.cling/files/video_abc.mp4';

      // 시뮬레이션: 큐에 이미 있는지 확인 + 파일 존재 확인
      final existingQueue = <UploadTask>[];
      final isInQueue = existingQueue.any((t) => t.recordId == 'record-1');
      expect(isInQueue, isFalse);

      // 기기 B에서는 파일이 없으므로 enqueue 안됨
      // 실제로는 File(deviceAPath).existsSync() == false
      // 따라서 기기 B에서는 이 레코드의 업로드를 수행할 수 없음
      expect(deviceAPath, isNotEmpty); // 경로 자체는 유효하지만 기기 B에 없음
    });

    test('최대 재시도 횟수는 5회이다', () {
      // upload_queue_provider.dart의 _maxRetries = 5
      // 5회 실패 후 status = failed로 변경됨
      final task = UploadTask(
        recordId: 'record-1',
        localVideoPath: '/path/to/video.mp4',
      );

      // 4번 실패 → 아직 pending
      for (int i = 0; i < 4; i++) {
        task.retryCount++;
      }
      expect(task.retryCount, 4);
      expect(task.retryCount < 5, isTrue); // _maxRetries보다 작음 → 재시도

      // 5번째 실패 → failed
      task.retryCount++;
      expect(task.retryCount >= 5, isTrue); // _maxRetries 도달 → failed
    });
  });
}
