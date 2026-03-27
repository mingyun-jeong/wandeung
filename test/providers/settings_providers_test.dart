import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cling/providers/camera_settings_provider.dart';
import 'package:cling/providers/connectivity_provider.dart';
import 'package:cling/providers/gallery_save_path_provider.dart';
import 'package:cling/models/user_subscription.dart';
import 'package:cling/providers/subscription_provider.dart';

void main() {
  // ─── EntryModeCameraNotifier ─────────────────────────────────────

  group('EntryModeCameraNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('초기 상태는 true이다', () {
      final notifier = EntryModeCameraNotifier();
      expect(notifier.state, isTrue);
    });

    test('toggle하면 상태가 반전된다', () async {
      final notifier = EntryModeCameraNotifier();
      await notifier.toggle();
      expect(notifier.state, isFalse);
    });

    test('두 번 toggle하면 원래 상태로 돌아온다', () async {
      final notifier = EntryModeCameraNotifier();
      await notifier.toggle();
      await notifier.toggle();
      expect(notifier.state, isTrue);
    });

    test('SharedPreferences에서 저장된 값을 로드한다', () async {
      SharedPreferences.setMockInitialValues({'entry_mode_camera': true});
      final notifier = EntryModeCameraNotifier();
      // _load()가 비동기이므로 약간의 대기 필요
      await Future.delayed(Duration.zero);
      expect(notifier.state, isTrue);
    });

    test('toggle 후 SharedPreferences에 값이 저장된다', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = EntryModeCameraNotifier();
      await notifier.toggle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('entry_mode_camera'), isFalse);
    });
  });

  // ─── GallerySavePathNotifier ─────────────────────────────────────

  group('GallerySavePathNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('초기 상태는 defaultAlbum이다', () {
      final notifier = GallerySavePathNotifier();
      expect(notifier.state, GallerySavePath.defaultAlbum);
    });

    test('set으로 byGym으로 변경할 수 있다', () async {
      final notifier = GallerySavePathNotifier();
      await notifier.set(GallerySavePath.byGym);
      expect(notifier.state, GallerySavePath.byGym);
    });

    test('set 후 SharedPreferences에 값이 저장된다', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = GallerySavePathNotifier();
      await notifier.set(GallerySavePath.byGym);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('gallery_save_path'), 'byGym');
    });

    test('SharedPreferences에서 저장된 값을 로드한다', () async {
      SharedPreferences.setMockInitialValues({'gallery_save_path': 'byGym'});
      final notifier = GallerySavePathNotifier();
      await Future.delayed(Duration.zero);
      expect(notifier.state, GallerySavePath.byGym);
    });

    test('잘못된 값이 저장되어 있으면 defaultAlbum으로 폴백한다', () async {
      SharedPreferences.setMockInitialValues(
          {'gallery_save_path': 'invalidValue'});
      final notifier = GallerySavePathNotifier();
      await Future.delayed(Duration.zero);
      expect(notifier.state, GallerySavePath.defaultAlbum);
    });
  });

  // ─── StorageModeNotifier ─────────────────────────────────────────

  group('StorageModeNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('초기 상태는 cloud이다', () {
      final notifier = StorageModeNotifier();
      expect(notifier.state, StorageMode.cloud);
    });

    test('setMode로 local로 변경할 수 있다', () async {
      final notifier = StorageModeNotifier();
      await notifier.setMode(StorageMode.local);
      expect(notifier.state, StorageMode.local);
    });

    test('setMode로 cloud로 다시 변경할 수 있다', () async {
      final notifier = StorageModeNotifier();
      await notifier.setMode(StorageMode.local);
      await notifier.setMode(StorageMode.cloud);
      expect(notifier.state, StorageMode.cloud);
    });

    test('setMode 후 SharedPreferences에 값이 저장된다', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = StorageModeNotifier();
      await notifier.setMode(StorageMode.local);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('storage_mode'), 'local');
    });

    test('SharedPreferences에서 local 값을 로드한다', () async {
      SharedPreferences.setMockInitialValues({'storage_mode': 'local'});
      final notifier = StorageModeNotifier();
      await Future.delayed(Duration.zero);
      expect(notifier.state, StorageMode.local);
    });

    test('SharedPreferences에 알 수 없는 값이 있으면 cloud를 유지한다', () async {
      SharedPreferences.setMockInitialValues({'storage_mode': 'unknown'});
      final notifier = StorageModeNotifier();
      await Future.delayed(Duration.zero);
      expect(notifier.state, StorageMode.cloud);
    });

    test('getValue는 로딩 전에도 정확한 값을 반환한다', () async {
      SharedPreferences.setMockInitialValues({'storage_mode': 'local'});
      final notifier = StorageModeNotifier();
      // _load가 완료되기 전 호출
      final value = await notifier.getValue();
      expect(value, StorageMode.local);
    });
  });

  // ─── WifiOnlyUploadNotifier ──────────────────────────────────────

  group('WifiOnlyUploadNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('초기 상태는 true이다 (Wi-Fi 전용 업로드 기본 활성화)', () {
      final notifier = WifiOnlyUploadNotifier();
      expect(notifier.state, isTrue);
    });

    test('toggle하면 false로 변경된다', () async {
      final notifier = WifiOnlyUploadNotifier();
      await notifier.toggle();
      expect(notifier.state, isFalse);
    });

    test('두 번 toggle하면 원래 상태로 돌아온다', () async {
      final notifier = WifiOnlyUploadNotifier();
      await notifier.toggle();
      await notifier.toggle();
      expect(notifier.state, isTrue);
    });

    test('toggle 후 SharedPreferences에 값이 저장된다', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = WifiOnlyUploadNotifier();
      await notifier.toggle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('wifi_only_upload'), isFalse);
    });

    test('SharedPreferences에서 저장된 값을 로드한다', () async {
      SharedPreferences.setMockInitialValues({'wifi_only_upload': false});
      final notifier = WifiOnlyUploadNotifier();
      await Future.delayed(Duration.zero);
      expect(notifier.state, isFalse);
    });
  });

  // ─── Enum 기본 검증 ──────────────────────────────────────────────

  group('StorageMode enum', () {
    test('cloud와 local 두 가지 값이 존재한다', () {
      expect(StorageMode.values.length, 2);
      expect(StorageMode.cloud.name, 'cloud');
      expect(StorageMode.local.name, 'local');
    });
  });

  group('SubscriptionTier enum', () {
    test('free와 pro 두 가지 값이 존재한다', () {
      expect(SubscriptionTier.values.length, 2);
      expect(SubscriptionTier.free.name, 'free');
      expect(SubscriptionTier.pro.name, 'pro');
    });
  });
}
