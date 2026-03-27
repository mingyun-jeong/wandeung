import 'package:flutter_test/flutter_test.dart';
import 'package:cling/services/ad_service.dart';

void main() {
  group('AdService', () {
    test('bannerAdUnitId가 빈 문자열이 아니다', () {
      final id = AdService.bannerAdUnitId;
      expect(id, isNotEmpty);
      expect(id, startsWith('ca-app-pub-'));
    });

    test('interstitialAdUnitId가 빈 문자열이 아니다', () {
      final id = AdService.interstitialAdUnitId;
      expect(id, isNotEmpty);
      expect(id, startsWith('ca-app-pub-'));
    });

    test('rewardedAdUnitId가 빈 문자열이 아니다', () {
      final id = AdService.rewardedAdUnitId;
      expect(id, isNotEmpty);
      expect(id, startsWith('ca-app-pub-'));
    });

    test('초기 상태에서 전면 광고가 준비되지 않았다', () {
      expect(AdService.isInterstitialReady, isFalse);
    });

    test('초기 상태에서 보상형 광고가 준비되지 않았다', () {
      expect(AdService.isRewardedReady, isFalse);
    });

    test('전면 광고가 준비되지 않은 상태에서 showInterstitial 호출해도 에러 없다', () {
      expect(() => AdService.showInterstitial(), returnsNormally);
    });

    test('보상형 광고가 준비되지 않은 상태에서 showRewarded는 false를 반환한다', () {
      final result = AdService.showRewarded(onRewarded: () {});
      expect(result, isFalse);
    });

    test('dispose 호출 시 에러 없이 정상 실행된다', () {
      expect(() => AdService.dispose(), returnsNormally);
    });

    test('ENABLE_ADS 미설정 시 기본값은 true이다', () {
      // 테스트 환경에서는 --dart-define 없이 실행하므로 기본값 true
      expect(AdService.isAdEnabled, isTrue);
    });

    test('isAdEnabled는 ENABLE_ADS 환경변수로 제어된다', () {
      // 테스트 환경에서는 --dart-define 없이 실행하므로 기본값 true
      // --dart-define=ENABLE_ADS=false로 빌드 시 false
      expect(AdService.isAdEnabled, isTrue);
    });
  });
}
