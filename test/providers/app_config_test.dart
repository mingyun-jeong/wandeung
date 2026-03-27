import 'package:flutter_test/flutter_test.dart';

void main() {
  // freeStorageLimitBytesProvider의 파싱 로직을 추출하여 테스트
  const defaultLimit = 500 * 1024 * 1024; // 524288000

  int parseStorageLimit(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    final str = value.toString().replaceAll('"', '').trim();
    return int.tryParse(str) ?? defaultLimit;
  }

  group('freeStorageLimitBytes 파싱', () {
    test('int 값이면 그대로 반환한다', () {
      expect(parseStorageLimit(52428800), 52428800);
    });

    test('double 값이면 int로 변환한다', () {
      expect(parseStorageLimit(52428800.0), 52428800);
    });

    test('문자열 숫자면 파싱한다', () {
      expect(parseStorageLimit('52428800'), 52428800);
    });

    test('따옴표가 포함된 문자열이면 제거 후 파싱한다', () {
      // jsonb 컬럼에 문자열로 저장된 경우: '"52428800"'
      expect(parseStorageLimit('"52428800"'), 52428800);
    });

    test('앞뒤 공백이 있는 문자열이면 trim 후 파싱한다', () {
      expect(parseStorageLimit(' 52428800 '), 52428800);
    });

    test('파싱 불가능한 값이면 기본값(500MB)을 반환한다', () {
      expect(parseStorageLimit('invalid'), defaultLimit);
      expect(parseStorageLimit(''), defaultLimit);
    });

    test('null이면 기본값을 반환한다', () {
      expect(parseStorageLimit(null), defaultLimit);
    });

    test('기본값은 500MB(524288000 바이트)이다', () {
      expect(defaultLimit, 524288000);
      expect(defaultLimit, 500 * 1024 * 1024);
    });
  });

  group('용량 표시 변환', () {
    test('52428800 바이트는 50 MB로 표시된다', () {
      const bytes = 52428800;
      final mb = bytes / 1024 / 1024;
      expect(mb.toStringAsFixed(0), '50');
    });

    test('524288000 바이트(기본값)는 500 MB로 표시된다', () {
      const bytes = 524288000;
      final mb = bytes / 1024 / 1024;
      expect(mb.toStringAsFixed(0), '500');
    });

    test('5242880000 바이트는 5000 MB로 표시된다', () {
      // DB에 0이 하나 더 들어간 경우
      const bytes = 5242880000;
      final mb = bytes / 1024 / 1024;
      expect(mb.toStringAsFixed(0), '5000');
    });
  });
}
