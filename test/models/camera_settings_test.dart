import 'package:flutter_test/flutter_test.dart';
import 'package:cling/providers/camera_settings_provider.dart';
import 'package:cling/utils/constants.dart';
import 'package:cling/models/climbing_gym.dart';

void main() {
  group('CameraSettings', () {
    test('기본 생성자로 생성하면 모든 필드가 기본값이다', () {
      const settings = CameraSettings();
      expect(settings.grade, isNull);
      expect(settings.color, isNull);
      expect(settings.selectedGym, isNull);
      expect(settings.persistTags, isFalse);
      expect(settings.tags, isEmpty);
    });

    test('copyWith로 grade만 변경하면 나머지는 유지된다', () {
      const original = CameraSettings(
        grade: ClimbingGrade.v3,
        color: DifficultyColor.blue,
        persistTags: true,
        tags: ['태그1'],
      );

      final copied = original.copyWith(grade: ClimbingGrade.v5);
      expect(copied.grade, ClimbingGrade.v5);
      expect(copied.color, DifficultyColor.blue);
      expect(copied.persistTags, isTrue);
      expect(copied.tags, ['태그1']);
    });

    test('copyWith로 color만 변경할 수 있다', () {
      const original = CameraSettings(
        grade: ClimbingGrade.v1,
        color: DifficultyColor.green,
      );

      final copied = original.copyWith(color: DifficultyColor.red);
      expect(copied.color, DifficultyColor.red);
      expect(copied.grade, ClimbingGrade.v1);
    });

    test('copyWith로 gym을 설정할 수 있다', () {
      const original = CameraSettings();
      final gym = ClimbingGym(name: '더클라임 신사');

      final copied = original.copyWith(selectedGym: gym);
      expect(copied.selectedGym, isNotNull);
      expect(copied.selectedGym!.name, '더클라임 신사');
    });

    test('copyWith에서 clearGym=true이면 gym이 null이 된다', () {
      final original = CameraSettings(
        selectedGym: ClimbingGym(name: '더클라임'),
      );

      final copied = original.copyWith(clearGym: true);
      expect(copied.selectedGym, isNull);
    });

    test('copyWith에서 clearGym=true이면 새 gym보다 우선한다', () {
      final original = CameraSettings(
        selectedGym: ClimbingGym(name: '더클라임'),
      );

      final copied = original.copyWith(
        clearGym: true,
        selectedGym: ClimbingGym(name: '클라이밍파크'),
      );
      // clearGym이 true이면 null이 됨
      expect(copied.selectedGym, isNull);
    });

    test('copyWith로 tags를 변경할 수 있다', () {
      const original = CameraSettings(tags: ['A', 'B']);

      final copied = original.copyWith(tags: ['C']);
      expect(copied.tags, ['C']);
    });

    test('copyWith로 persistTags를 변경할 수 있다', () {
      const original = CameraSettings(persistTags: false);

      final copied = original.copyWith(persistTags: true);
      expect(copied.persistTags, isTrue);
    });
  });

  group('CameraSettingsNotifier', () {
    test('userGrade가 null이면 v1/yellow로 초기화된다', () {
      final notifier = CameraSettingsNotifier(null);
      expect(notifier.state.grade, ClimbingGrade.v1);
      expect(notifier.state.color, DifficultyColor.yellow);
    });

    test('userGrade를 전달하면 해당 등급과 기본 색상으로 초기화된다', () {
      final notifier = CameraSettingsNotifier(ClimbingGrade.v5);
      expect(notifier.state.grade, ClimbingGrade.v5);
      expect(notifier.state.color, ClimbingGrade.v5.defaultColor);
    });

    test('setGrade로 등급을 변경할 수 있다', () {
      final notifier = CameraSettingsNotifier(null);
      notifier.setGrade(ClimbingGrade.v7);
      expect(notifier.state.grade, ClimbingGrade.v7);
    });

    test('setColor로 색상을 변경할 수 있다', () {
      final notifier = CameraSettingsNotifier(null);
      notifier.setColor(DifficultyColor.purple);
      expect(notifier.state.color, DifficultyColor.purple);
    });

    test('setGym으로 암장을 설정할 수 있다', () {
      final notifier = CameraSettingsNotifier(null);
      notifier.setGym(ClimbingGym(name: '볼더프렌즈'));
      expect(notifier.state.selectedGym!.name, '볼더프렌즈');
    });

    test('clearGym으로 암장을 초기화할 수 있다', () {
      final notifier = CameraSettingsNotifier(null);
      notifier.setGym(ClimbingGym(name: '볼더프렌즈'));
      notifier.clearGym();
      expect(notifier.state.selectedGym, isNull);
    });

    test('setPersistTags로 태그 유지 설정을 변경할 수 있다', () {
      final notifier = CameraSettingsNotifier(null);
      notifier.setPersistTags(true);
      expect(notifier.state.persistTags, isTrue);
    });

    test('setTags로 태그 목록을 변경할 수 있다', () {
      final notifier = CameraSettingsNotifier(null);
      notifier.setTags(['실내', '볼더링']);
      expect(notifier.state.tags, ['실내', '볼더링']);
    });

    test('reset으로 모든 설정이 초기화된다', () {
      final notifier = CameraSettingsNotifier(ClimbingGrade.v5);
      notifier.setGrade(ClimbingGrade.v10);
      notifier.setColor(DifficultyColor.black);
      notifier.setGym(ClimbingGym(name: '더클라임'));
      notifier.setTags(['태그']);
      notifier.setPersistTags(true);

      notifier.reset();
      expect(notifier.state.grade, isNull);
      expect(notifier.state.color, isNull);
      expect(notifier.state.selectedGym, isNull);
      expect(notifier.state.tags, isEmpty);
      expect(notifier.state.persistTags, isFalse);
    });
  });
}
