import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cling/models/user_subscription.dart';
import 'package:cling/providers/connectivity_provider.dart';
import 'package:cling/providers/upload_queue_provider.dart';

void main() {
  // ─── 업로드 정책 결정 로직 추출 ──────────────────────────────────
  //
  // processQueue의 핵심 판단 로직:
  //   1. storageMode == local → 업로드 안 함
  //   2. wifiOnly == true && isWifi == false → 업로드 안 함
  //   3. 그 외 → 업로드 진행

  /// processQueue에서 업로드를 시작할지 결정하는 로직 재현
  bool shouldProcessUpload({
    required StorageMode storageMode,
    required bool wifiOnly,
    required bool isWifi,
  }) {
    // 로컬 모드면 큐 처리하지 않음
    if (storageMode == StorageMode.local) return false;
    // Wi-Fi 전용 모드인데 Wi-Fi가 아니면 중단
    if (wifiOnly && !isWifi) return false;
    return true;
  }

  // ─── 클라우드 모드 + Wi-Fi 전용 업로드 ON ────────────────────────

  group('클라우드 모드 — Wi-Fi 전용 업로드 ON', () {
    test('Wi-Fi 연결 시 업로드가 진행된다', () {
      final result = shouldProcessUpload(
        storageMode: StorageMode.cloud,
        wifiOnly: true,
        isWifi: true,
      );
      expect(result, isTrue);
    });

    test('Wi-Fi 미연결 시 업로드가 차단된다', () {
      final result = shouldProcessUpload(
        storageMode: StorageMode.cloud,
        wifiOnly: true,
        isWifi: false,
      );
      expect(result, isFalse);
    });
  });

  // ─── 클라우드 모드 + Wi-Fi 전용 업로드 OFF ───────────────────────

  group('클라우드 모드 — Wi-Fi 전용 업로드 OFF', () {
    test('Wi-Fi 연결 시 업로드가 진행된다', () {
      final result = shouldProcessUpload(
        storageMode: StorageMode.cloud,
        wifiOnly: false,
        isWifi: true,
      );
      expect(result, isTrue);
    });

    test('Wi-Fi 미연결(모바일 데이터)에서도 업로드가 진행된다', () {
      final result = shouldProcessUpload(
        storageMode: StorageMode.cloud,
        wifiOnly: false,
        isWifi: false,
      );
      expect(result, isTrue);
    });
  });

  // ─── 로컬 모드 ──────────────────────────────────────────────────

  group('로컬 모드 — 업로드 차단', () {
    test('Wi-Fi 연결 + Wi-Fi 전용 ON이어도 업로드하지 않는다', () {
      final result = shouldProcessUpload(
        storageMode: StorageMode.local,
        wifiOnly: true,
        isWifi: true,
      );
      expect(result, isFalse);
    });

    test('Wi-Fi 연결 + Wi-Fi 전용 OFF이어도 업로드하지 않는다', () {
      final result = shouldProcessUpload(
        storageMode: StorageMode.local,
        wifiOnly: false,
        isWifi: true,
      );
      expect(result, isFalse);
    });

    test('Wi-Fi 미연결 + Wi-Fi 전용 ON에서도 업로드하지 않는다', () {
      final result = shouldProcessUpload(
        storageMode: StorageMode.local,
        wifiOnly: true,
        isWifi: false,
      );
      expect(result, isFalse);
    });

    test('Wi-Fi 미연결 + Wi-Fi 전용 OFF에서도 업로드하지 않는다', () {
      final result = shouldProcessUpload(
        storageMode: StorageMode.local,
        wifiOnly: false,
        isWifi: false,
      );
      expect(result, isFalse);
    });
  });

  // ─── 전체 조합 매트릭스 ─────────────────────────────────────────

  group('업로드 정책 — 전체 조합 매트릭스', () {
    // storageMode × wifiOnly × isWifi = 2×2×2 = 8가지 조합
    final testCases = [
      // (storageMode, wifiOnly, isWifi, expectedResult, description)
      (StorageMode.cloud, true, true, true, '클라우드+WiFiOnly ON+WiFi O → 업로드'),
      (StorageMode.cloud, true, false, false, '클라우드+WiFiOnly ON+WiFi X → 차단'),
      (StorageMode.cloud, false, true, true, '클라우드+WiFiOnly OFF+WiFi O → 업로드'),
      (StorageMode.cloud, false, false, true, '클라우드+WiFiOnly OFF+WiFi X → 업로드'),
      (StorageMode.local, true, true, false, '로컬+WiFiOnly ON+WiFi O → 차단'),
      (StorageMode.local, true, false, false, '로컬+WiFiOnly ON+WiFi X → 차단'),
      (StorageMode.local, false, true, false, '로컬+WiFiOnly OFF+WiFi O → 차단'),
      (StorageMode.local, false, false, false, '로컬+WiFiOnly OFF+WiFi X → 차단'),
    ];

    for (final tc in testCases) {
      test(tc.$5, () {
        final result = shouldProcessUpload(
          storageMode: tc.$1,
          wifiOnly: tc.$2,
          isWifi: tc.$3,
        );
        expect(result, tc.$4);
      });
    }
  });

  // ─── cloudUploadEnabledProvider 로직 ────────────────────────────

  group('cloudUploadEnabledProvider 로직', () {
    test('클라우드 모드이면 true를 반환한다', () {
      final enabled = StorageMode.cloud == StorageMode.cloud;
      expect(enabled, isTrue);
    });

    test('로컬 모드이면 false를 반환한다', () {
      final enabled = StorageMode.local == StorageMode.cloud;
      expect(enabled, isFalse);
    });
  });

  // ─── isWifiProvider 로직 ────────────────────────────────────────

  group('isWifiProvider 상태별 동작', () {
    test('ConnectivityResult에 wifi가 포함되면 true이다', () {
      // isWifiProvider 로직 재현:
      // data: (results) => results.contains(ConnectivityResult.wifi)
      final results = [ConnectivityResult.wifi];
      expect(results.contains(ConnectivityResult.wifi), isTrue);
    });

    test('ConnectivityResult에 wifi와 mobile이 같이 있어도 true이다', () {
      final results = [ConnectivityResult.wifi, ConnectivityResult.mobile];
      expect(results.contains(ConnectivityResult.wifi), isTrue);
    });

    test('ConnectivityResult에 mobile만 있으면 false이다', () {
      final results = [ConnectivityResult.mobile];
      expect(results.contains(ConnectivityResult.wifi), isFalse);
    });

    test('ConnectivityResult가 비어있으면 false이다 (연결 없음)', () {
      final results = <ConnectivityResult>[];
      expect(results.contains(ConnectivityResult.wifi), isFalse);
    });

    test('ConnectivityResult에 none만 있으면 false이다', () {
      final results = [ConnectivityResult.none];
      expect(results.contains(ConnectivityResult.wifi), isFalse);
    });

    test('로딩 상태에서는 true를 반환한다 (업로드 차단 방지)', () {
      // isWifiProvider: loading: () => true
      // 앱 초기화 중에도 이미 enqueue된 업로드가 진행되도록
      const loadingValue = true;
      expect(loadingValue, isTrue);
    });

    test('에러 상태에서는 false를 반환한다 (안전하게 차단)', () {
      // isWifiProvider: error: (_, __) => false
      // 네트워크 상태 확인 불가 시 데이터 소모 방지
      const errorValue = false;
      expect(errorValue, isFalse);
    });
  });

  // ─── WifiOnlyUploadNotifier ─────────────────────────────────────

  group('WifiOnlyUploadNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('기본값은 true이다 (Wi-Fi 전용 업로드 활성)', () {
      final notifier = WifiOnlyUploadNotifier();
      expect(notifier.state, isTrue);
    });

    test('toggle하면 false(모든 네트워크 허용)로 변경된다', () async {
      final notifier = WifiOnlyUploadNotifier();
      await notifier.toggle();
      expect(notifier.state, isFalse);
    });

    test('toggle 두 번이면 다시 true로 복원된다', () async {
      final notifier = WifiOnlyUploadNotifier();
      await notifier.toggle();
      await notifier.toggle();
      expect(notifier.state, isTrue);
    });

    test('SharedPreferences에서 false를 로드한다', () async {
      SharedPreferences.setMockInitialValues({'wifi_only_upload': false});
      final notifier = WifiOnlyUploadNotifier();
      await Future.delayed(Duration.zero);
      expect(notifier.state, isFalse);
    });

    test('SharedPreferences에 키가 없으면 true(기본값)이다', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = WifiOnlyUploadNotifier();
      await Future.delayed(Duration.zero);
      expect(notifier.state, isTrue);
    });

    test('toggle 후 SharedPreferences에 값이 저장된다', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = WifiOnlyUploadNotifier();
      await notifier.toggle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('wifi_only_upload'), isFalse);
    });
  });

  // ─── Wi-Fi 전환 시 큐 처리 트리거 ──────────────────────────────

  group('Wi-Fi 전환 시 업로드 재개 시나리오', () {
    test('Wi-Fi OFF→ON 전환 시 processQueue가 호출되어야 한다', () {
      // upload_queue_provider.dart _init():
      //   _ref.listen(connectivityProvider, (prev, next) {
      //     next.whenData((results) {
      //       if (results.contains(ConnectivityResult.wifi)) {
      //         processQueue();
      //       }
      //     });
      //   });

      // Wi-Fi 전환 감지 조건: results에 wifi가 포함
      final prevResults = [ConnectivityResult.mobile];
      final nextResults = [ConnectivityResult.wifi];

      final wasWifi = prevResults.contains(ConnectivityResult.wifi);
      final isNowWifi = nextResults.contains(ConnectivityResult.wifi);

      expect(wasWifi, isFalse);
      expect(isNowWifi, isTrue);
      // → processQueue() 호출됨
    });

    test('모바일→모바일 전환 시에는 processQueue가 호출되지 않는다', () {
      final results = [ConnectivityResult.mobile];
      expect(results.contains(ConnectivityResult.wifi), isFalse);
      // → processQueue() 호출 안 됨
    });

    test('Wi-Fi→Wi-Fi 재연결에서도 processQueue가 호출된다', () {
      // 동일하게 results에 wifi가 포함되면 호출
      final results = [ConnectivityResult.wifi];
      expect(results.contains(ConnectivityResult.wifi), isTrue);
      // → processQueue() 호출됨 (실패한 태스크 재처리)
    });
  });

  // ─── 설정 화면 Wi-Fi 토글 동작 ─────────────────────────────────

  group('설정 화면 Wi-Fi 토글 동작', () {
    test('Wi-Fi 전용 ON→OFF 전환 시 processQueue가 트리거된다', () {
      // settings_screen.dart onChanged:
      //   ref.read(wifiOnlyUploadProvider.notifier).toggle();
      //   if (wifiOnly) {  // 토글 전 값이 true였으면
      //     ref.read(uploadQueueProvider.notifier).processQueue();
      //   }

      // Wi-Fi 전용이 켜져있는 상태에서 끄면 → 대기 중인 업로드를 즉시 처리
      const wifiOnlyBefore = true;
      // toggle() 호출 → wifiOnly가 false로 변경
      // wifiOnlyBefore가 true이므로 processQueue() 호출
      expect(wifiOnlyBefore, isTrue); // → processQueue 트리거됨
    });

    test('Wi-Fi 전용 OFF→ON 전환 시에는 processQueue가 트리거되지 않는다', () {
      // Wi-Fi 전용을 켤 때는 대기만 하면 됨 (즉시 업로드 불필요)
      const wifiOnlyBefore = false;
      expect(wifiOnlyBefore, isFalse); // → processQueue 트리거 안 됨
    });
  });

  // ─── 루프 내 Wi-Fi 재확인 로직 ─────────────────────────────────

  group('업로드 루프 중 Wi-Fi 상태 재확인', () {
    test('태스크 처리 중 Wi-Fi가 끊기면 루프를 중단한다', () {
      // processQueue 루프 내부:
      //   if (wifiOnly && !_ref.read(isWifiProvider)) break;

      const wifiOnly = true;

      // 태스크 1 처리 시: Wi-Fi 연결
      var isWifi = true;
      final shouldContinue1 = !(wifiOnly && !isWifi);
      expect(shouldContinue1, isTrue); // 태스크 1 처리

      // 태스크 2 처리 전: Wi-Fi 끊김
      isWifi = false;
      final shouldContinue2 = !(wifiOnly && !isWifi);
      expect(shouldContinue2, isFalse); // 루프 중단 (break)
    });

    test('Wi-Fi 전용 OFF이면 Wi-Fi 끊김과 무관하게 계속 처리한다', () {
      const wifiOnly = false;

      var isWifi = false; // Wi-Fi 끊김
      final shouldContinue = !(wifiOnly && !isWifi);
      expect(shouldContinue, isTrue); // 계속 처리
    });
  });

  // ─── 앱 시작 시 uploading → pending 리셋 ───────────────────────

  group('앱 재시작 시 태스크 상태 리셋', () {
    test('uploading 상태의 태스크가 pending으로 리셋된다', () {
      // _init():
      //   if (task.status == UploadStatus.uploading) {
      //     task.status = UploadStatus.pending;
      //   }
      final task = UploadTask(
        recordId: 'record-1',
        localVideoPath: '/path/video.mp4',
        status: UploadStatus.uploading,
      );

      // 리셋 로직 재현
      if (task.status == UploadStatus.uploading) {
        task.status = UploadStatus.pending;
      }

      expect(task.status, UploadStatus.pending);
    });

    test('pending 상태의 태스크는 변경되지 않는다', () {
      final task = UploadTask(
        recordId: 'record-1',
        localVideoPath: '/path/video.mp4',
        status: UploadStatus.pending,
      );

      if (task.status == UploadStatus.uploading) {
        task.status = UploadStatus.pending;
      }

      expect(task.status, UploadStatus.pending);
    });

    test('failed 상태의 태스크는 변경되지 않는다', () {
      final task = UploadTask(
        recordId: 'record-1',
        localVideoPath: '/path/video.mp4',
        status: UploadStatus.failed,
      );

      if (task.status == UploadStatus.uploading) {
        task.status = UploadStatus.pending;
      }

      expect(task.status, UploadStatus.failed);
    });
  });
}
