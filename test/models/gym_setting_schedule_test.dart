import 'package:flutter_test/flutter_test.dart';
import 'package:cling/models/gym_setting_schedule.dart';

void main() {
  // ─── SettingSector ────────────────────────────────────────────────

  group('SettingSector', () {
    test('fromMap으로 정상 파싱된다', () {
      final map = {
        'name': 'A벽',
        'color': 'red',
        'dates': ['2026-03-01', '2026-03-15'],
        'start_time': '10:00',
        'end_time': '18:00',
      };

      final sector = SettingSector.fromMap(map);
      expect(sector.name, 'A벽');
      expect(sector.color, 'red');
      expect(sector.dates, ['2026-03-01', '2026-03-15']);
      expect(sector.startTime, '10:00');
      expect(sector.endTime, '18:00');
    });

    test('fromMap에서 optional 필드가 null이면 null로 파싱된다', () {
      final map = {
        'name': 'B벽',
        'dates': ['2026-03-10'],
      };

      final sector = SettingSector.fromMap(map);
      expect(sector.name, 'B벽');
      expect(sector.color, isNull);
      expect(sector.startTime, isNull);
      expect(sector.endTime, isNull);
    });

    test('toMap이 정상 직렬화된다', () {
      final sector = SettingSector(
        name: 'C벽',
        color: 'blue',
        dates: ['2026-04-01'],
        startTime: '09:00',
        endTime: '17:00',
      );

      final map = sector.toMap();
      expect(map['name'], 'C벽');
      expect(map['color'], 'blue');
      expect(map['dates'], ['2026-04-01']);
      expect(map['start_time'], '09:00');
      expect(map['end_time'], '17:00');
    });

    test('toMap에서 optional 필드가 null이면 키가 포함되지 않는다', () {
      final sector = SettingSector(
        name: 'D벽',
        dates: ['2026-04-01'],
      );

      final map = sector.toMap();
      expect(map.containsKey('color'), isFalse);
      expect(map.containsKey('start_time'), isFalse);
      expect(map.containsKey('end_time'), isFalse);
    });

    test('copyWith로 일부 필드만 변경할 수 있다', () {
      final original = SettingSector(
        name: 'A벽',
        color: 'red',
        dates: ['2026-03-01'],
        startTime: '10:00',
        endTime: '18:00',
      );

      final copied = original.copyWith(name: 'B벽', color: 'blue');
      expect(copied.name, 'B벽');
      expect(copied.color, 'blue');
      expect(copied.dates, ['2026-03-01']);
      expect(copied.startTime, '10:00');
      expect(copied.endTime, '18:00');
    });

    group('timeRangeLabel', () {
      test('startTime과 endTime 모두 있으면 "시작 ~ 종료" 형식이다', () {
        final sector = SettingSector(
          name: 'A', dates: [], startTime: '10:00', endTime: '18:00',
        );
        expect(sector.timeRangeLabel, '10:00 ~ 18:00');
      });

      test('startTime만 있으면 "시작 ~" 형식이다', () {
        final sector = SettingSector(
          name: 'A', dates: [], startTime: '10:00',
        );
        expect(sector.timeRangeLabel, '10:00 ~');
      });

      test('endTime만 있으면 "~ 종료" 형식이다', () {
        final sector = SettingSector(
          name: 'A', dates: [], endTime: '18:00',
        );
        expect(sector.timeRangeLabel, '~ 18:00');
      });

      test('둘 다 null이면 null을 반환한다', () {
        final sector = SettingSector(name: 'A', dates: []);
        expect(sector.timeRangeLabel, isNull);
      });
    });
  });

  // ─── GymSettingSchedule ──────────────────────────────────────────

  group('GymSettingSchedule', () {
    Map<String, dynamic> buildScheduleMap({
      String? gymName,
      Map<String, dynamic>? climbingGyms,
      String? submittedBy,
      String? submittedByEmail,
    }) {
      return {
        'id': 'schedule-1',
        'gym_id': 'gym-1',
        'year_month': '2026-03',
        'sectors': [
          {
            'name': 'A벽',
            'color': 'red',
            'dates': ['2026-03-01', '2026-03-15'],
            'start_time': '10:00',
            'end_time': '18:00',
          },
          {
            'name': 'B벽',
            'dates': ['2026-03-10'],
          },
        ],
        'source_image_url': 'https://example.com/image.jpg',
        'submitted_by': submittedBy,
        'submitted_by_email': submittedByEmail,
        'status': 'approved',
        'created_at': '2026-03-01T00:00:00Z',
        'updated_at': '2026-03-01T12:00:00Z',
        if (climbingGyms != null) 'climbing_gyms': climbingGyms,
        if (gymName != null) 'gym_name': gymName,
      };
    }

    test('fromMap으로 정상 파싱된다', () {
      final map = buildScheduleMap(
        climbingGyms: {'name': '더클라임 신사'},
      );

      final schedule = GymSettingSchedule.fromMap(map);
      expect(schedule.id, 'schedule-1');
      expect(schedule.gymId, 'gym-1');
      expect(schedule.gymName, '더클라임 신사');
      expect(schedule.yearMonth, '2026-03');
      expect(schedule.sectors.length, 2);
      expect(schedule.sectors[0].name, 'A벽');
      expect(schedule.sectors[1].name, 'B벽');
      expect(schedule.sourceImageUrl, 'https://example.com/image.jpg');
      expect(schedule.status, 'approved');
      expect(schedule.createdAt, isNotNull);
      expect(schedule.updatedAt, isNotNull);
    });

    test('fromMap에서 climbing_gyms JOIN 결과로 gymName을 추출한다', () {
      final map = buildScheduleMap(
        climbingGyms: {'name': '클라이밍파크'},
      );

      final schedule = GymSettingSchedule.fromMap(map);
      expect(schedule.gymName, '클라이밍파크');
    });

    test('fromMap에서 climbing_gyms가 없으면 gym_name 필드를 사용한다', () {
      final map = buildScheduleMap(gymName: '볼더프렌즈');

      final schedule = GymSettingSchedule.fromMap(map);
      expect(schedule.gymName, '볼더프렌즈');
    });

    test('fromMap에서 gymName 관련 필드가 모두 없으면 null이다', () {
      final map = buildScheduleMap();

      final schedule = GymSettingSchedule.fromMap(map);
      expect(schedule.gymName, isNull);
    });

    test('fromMap에서 sectors가 null이면 빈 리스트로 파싱된다', () {
      final map = {
        'id': 'schedule-1',
        'gym_id': 'gym-1',
        'year_month': '2026-03',
        'sectors': null,
        'status': 'approved',
        'created_at': '2026-03-01T00:00:00Z',
        'updated_at': '2026-03-01T00:00:00Z',
      };

      final schedule = GymSettingSchedule.fromMap(map);
      expect(schedule.sectors, isEmpty);
    });

    test('fromMap에서 status가 null이면 기본값 approved가 사용된다', () {
      final map = {
        'id': 'schedule-1',
        'gym_id': 'gym-1',
        'year_month': '2026-03',
        'sectors': [],
        'status': null,
        'created_at': '2026-03-01T00:00:00Z',
        'updated_at': '2026-03-01T00:00:00Z',
      };

      final schedule = GymSettingSchedule.fromMap(map);
      expect(schedule.status, 'approved');
    });

    test('toInsertMap이 올바르게 직렬화된다', () {
      final schedule = GymSettingSchedule(
        gymId: 'gym-1',
        yearMonth: '2026-03',
        sectors: [
          SettingSector(name: 'A벽', dates: ['2026-03-01']),
        ],
        submittedBy: 'user-1',
        sourceImageUrl: 'https://example.com/img.jpg',
        status: 'pending',
      );

      final map = schedule.toInsertMap();
      expect(map['gym_id'], 'gym-1');
      expect(map['year_month'], '2026-03');
      expect(map['sectors'], isList);
      expect((map['sectors'] as List).length, 1);
      expect(map['submitted_by'], 'user-1');
      expect(map['source_image_url'], 'https://example.com/img.jpg');
      expect(map['status'], 'pending');
      // id, created_at 등은 포함되지 않아야 함
      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('created_at'), isFalse);
    });

    group('submitterDisplayName', () {
      test('submittedBy가 null이면 "관리자"를 반환한다', () {
        final schedule = GymSettingSchedule(
          gymId: 'gym-1', yearMonth: '2026-03', sectors: [],
        );
        expect(schedule.submitterDisplayName, '관리자');
      });

      test('submitterEmail이 null이면 "관리자"를 반환한다', () {
        final schedule = GymSettingSchedule(
          gymId: 'gym-1', yearMonth: '2026-03', sectors: [],
          submittedBy: 'user-1',
        );
        expect(schedule.submitterDisplayName, '관리자');
      });

      test('이메일이 2글자 이상이면 앞 2글자 + "님"을 반환한다', () {
        final schedule = GymSettingSchedule(
          gymId: 'gym-1', yearMonth: '2026-03', sectors: [],
          submittedBy: 'user-1',
          submitterEmail: 'hello@example.com',
        );
        expect(schedule.submitterDisplayName, 'he님');
      });

      test('이메일 로컬부분이 1글자이면 그대로 + "님"을 반환한다', () {
        final schedule = GymSettingSchedule(
          gymId: 'gym-1', yearMonth: '2026-03', sectors: [],
          submittedBy: 'user-1',
          submitterEmail: 'a@example.com',
        );
        expect(schedule.submitterDisplayName, 'a님');
      });
    });

    group('sectorsForDate', () {
      test('해당 날짜에 매칭되는 섹터만 반환한다', () {
        final schedule = GymSettingSchedule(
          gymId: 'gym-1',
          yearMonth: '2026-03',
          sectors: [
            SettingSector(name: 'A벽', dates: ['2026-03-01', '2026-03-15']),
            SettingSector(name: 'B벽', dates: ['2026-03-01']),
            SettingSector(name: 'C벽', dates: ['2026-03-10']),
          ],
        );

        final result = schedule.sectorsForDate('2026-03-01');
        expect(result.length, 2);
        expect(result.map((s) => s.name).toList(), ['A벽', 'B벽']);
      });

      test('매칭되는 섹터가 없으면 빈 리스트를 반환한다', () {
        final schedule = GymSettingSchedule(
          gymId: 'gym-1',
          yearMonth: '2026-03',
          sectors: [
            SettingSector(name: 'A벽', dates: ['2026-03-01']),
          ],
        );

        final result = schedule.sectorsForDate('2026-03-20');
        expect(result, isEmpty);
      });
    });

    group('allDates', () {
      test('모든 섹터의 날짜를 중복 없이 반환한다', () {
        final schedule = GymSettingSchedule(
          gymId: 'gym-1',
          yearMonth: '2026-03',
          sectors: [
            SettingSector(name: 'A벽', dates: ['2026-03-01', '2026-03-15']),
            SettingSector(name: 'B벽', dates: ['2026-03-01', '2026-03-10']),
          ],
        );

        final dates = schedule.allDates;
        expect(dates.length, 3);
        expect(dates, containsAll(['2026-03-01', '2026-03-10', '2026-03-15']));
      });

      test('섹터가 없으면 빈 Set을 반환한다', () {
        final schedule = GymSettingSchedule(
          gymId: 'gym-1', yearMonth: '2026-03', sectors: [],
        );
        expect(schedule.allDates, isEmpty);
      });
    });
  });
}
