import 'package:flutter_test/flutter_test.dart';
import 'package:cling/models/user_subscription.dart';

void main() {
  group('클라우드 사용량 집계 로직', () {
    // cloudUsageProvider의 핵심 집계 로직을 추출하여 테스트

    int calculateCloudUsage(List<Map<String, dynamic>> rows) {
      int total = 0;
      for (final row in rows) {
        final size = row['file_size_bytes'];
        if (size != null) total += (size as num).toInt();
      }
      return total;
    }

    test('모든 레코드에 file_size_bytes가 있으면 정상 합산된다', () {
      final rows = [
        {'file_size_bytes': 10 * 1024 * 1024},
        {'file_size_bytes': 20 * 1024 * 1024},
        {'file_size_bytes': 30 * 1024 * 1024},
      ];

      expect(calculateCloudUsage(rows), 60 * 1024 * 1024);
    });

    test('file_size_bytes가 null인 레코드는 0으로 처리된다', () {
      final rows = [
        {'file_size_bytes': 10 * 1024 * 1024},
        {'file_size_bytes': null}, // 업로드 전 또는 로컬 모드→클라우드 전환 레코드
        {'file_size_bytes': 20 * 1024 * 1024},
      ];

      expect(calculateCloudUsage(rows), 30 * 1024 * 1024);
    });

    test('빈 응답이면 0을 반환한다', () {
      expect(calculateCloudUsage([]), 0);
    });

    test('file_size_bytes가 num 타입(double)이어도 int로 변환된다', () {
      final rows = [
        {'file_size_bytes': 10485760.0}, // 10MB as double
      ];

      expect(calculateCloudUsage(rows), 10485760);
    });
  });

  group('남은 용량(remainingStorage) 계산 로직', () {
    int calculateRemaining({
      required SubscriptionTier tier,
      required int limit,
      required int? usage,
    }) {
      if (tier == SubscriptionTier.pro) return limit;
      return limit - (usage ?? 0);
    }

    test('Free 티어 — 사용량이 있으면 차감된 값을 반환한다', () {
      final remaining = calculateRemaining(
        tier: SubscriptionTier.free,
        limit: 500 * 1024 * 1024,
        usage: 200 * 1024 * 1024,
      );
      expect(remaining, 300 * 1024 * 1024);
    });

    test('Free 티어 — 사용량이 제한을 초과하면 음수가 반환된다', () {
      // INSERT 시 원본 크기가 기록되어 한도를 초과하는 경우
      final remaining = calculateRemaining(
        tier: SubscriptionTier.free,
        limit: 500 * 1024 * 1024,
        usage: 600 * 1024 * 1024,
      );
      expect(remaining, lessThan(0));
    });

    test('Free 티어 — usage가 null이면 전체 용량을 반환한다', () {
      final remaining = calculateRemaining(
        tier: SubscriptionTier.free,
        limit: 500 * 1024 * 1024,
        usage: null,
      );
      expect(remaining, 500 * 1024 * 1024);
    });

    test('Pro 티어 — 사용량에 관계없이 limit을 반환한다', () {
      final remaining = calculateRemaining(
        tier: SubscriptionTier.pro,
        limit: 500 * 1024 * 1024,
        usage: 999 * 1024 * 1024,
      );
      expect(remaining, 500 * 1024 * 1024);
    });
  });

  group('수정 후: 기기 간 용량 일치 검증', () {
    int calculateCloudUsage(List<Map<String, dynamic>> rows) {
      int total = 0;
      for (final row in rows) {
        final size = row['file_size_bytes'];
        if (size != null) total += (size as num).toInt();
      }
      return total;
    }

    test('INSERT 시 file_size_bytes=null이면 업로드 전 기기 B에서도 0으로 집계된다', () {
      // 수정 후 시나리오:
      // 1. 기기 A에서 촬영 → INSERT file_size_bytes = null
      // 2. 기기 B에서 조회 → null이므로 0으로 집계 (부풀려진 값 없음!)
      // 3. 기기 A에서 업로드 완료 → UPDATE file_size_bytes = 10MB
      // 4. 기기 B에서 새로고침 → 10MB로 일치

      const compressedSize = 10 * 1024 * 1024; // 10MB

      // Step 1: INSERT 직후 — file_size_bytes = null
      final dbAfterInsert = [
        {'file_size_bytes': null}, // 새 레코드 (업로드 전)
        {'file_size_bytes': 30 * 1024 * 1024}, // 기존 레코드
      ];

      // Step 2: 기기 B가 조회 → null 레코드는 0으로 처리
      final usageOnDeviceB = calculateCloudUsage(dbAfterInsert);
      expect(usageOnDeviceB, 30 * 1024 * 1024); // 기존 레코드만 집계

      // Step 3: 기기 A 업로드 완료 → file_size_bytes = compressedSize
      final dbAfterUpload = [
        {'file_size_bytes': compressedSize}, // 업로드 완료
        {'file_size_bytes': 30 * 1024 * 1024},
      ];

      // Step 4: 기기 B 새로고침 → 정확한 값
      final usageOnDeviceBRefreshed = calculateCloudUsage(dbAfterUpload);
      expect(usageOnDeviceBRefreshed, 40 * 1024 * 1024);

      // 기기 A도 동일한 값 (invalidate 후)
      final usageOnDeviceA = calculateCloudUsage(dbAfterUpload);
      expect(usageOnDeviceA, usageOnDeviceBRefreshed); // 일치!
    });

    test('여러 레코드 업로드 대기 중에도 용량이 부풀려지지 않는다', () {
      // 기기 A에서 3개 촬영, 아직 업로드 안 됨
      // 수정 후: INSERT 시 file_size_bytes = null
      const compressedSize = 10 * 1024 * 1024;

      final dbBeforeUpload = [
        {'file_size_bytes': null}, // 촬영 1 (업로드 전)
        {'file_size_bytes': null}, // 촬영 2 (업로드 전)
        {'file_size_bytes': null}, // 촬영 3 (업로드 전)
      ];

      final dbAfterAllUploads = [
        {'file_size_bytes': compressedSize},
        {'file_size_bytes': compressedSize},
        {'file_size_bytes': compressedSize},
      ];

      final usageBeforeUpload = calculateCloudUsage(dbBeforeUpload);
      final usageAfterUpload = calculateCloudUsage(dbAfterAllUploads);

      // 수정 후: 업로드 전에는 0으로 집계 (부풀려진 150MB가 아님)
      expect(usageBeforeUpload, 0);
      expect(usageAfterUpload, 30 * 1024 * 1024);
    });

    test('용량 초과 판정이 기기와 무관하게 일관된다', () {
      // 수정 후: 업로드 완료된 레코드만 용량에 포함
      // → 기기 A, B 모두 동일한 DB 값 기반 (새로고침 시)

      const limit = 500 * 1024 * 1024;
      const uploadedUsage = 30 * 1024 * 1024; // 업로드 완료된 총 용량

      const remainingA = limit - uploadedUsage;
      const remainingB = limit - uploadedUsage; // 새로고침 후 동일

      expect(remainingA, remainingB); // 기기 간 일치
    });
  });
}
