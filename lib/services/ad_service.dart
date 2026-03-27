import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob 광고 서비스
///
/// 테스트 광고 ID를 사용 중. 프로덕션 배포 전 실제 광고 단위 ID로 교체 필요.
class AdService {
  AdService._();

  static bool _initialized = false;

  /// `--dart-define=ENABLE_ADS=false`로 광고 비활성화 (기본값: true)
  ///
  /// 사용법:
  ///   flutter run --dart-define=ENABLE_ADS=false   # 광고 끔
  ///   flutter run                                  # 광고 켬 (기본)
  static const _enableAds =
      bool.fromEnvironment('ENABLE_ADS', defaultValue: true);
  static bool get isAdEnabled => _enableAds;

  /// SDK 초기화 (main에서 1회 호출)
  static Future<void> initialize() async {
    if (_initialized || !isAdEnabled) return;
    await MobileAds.instance.initialize();
    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // 광고 단위 ID (테스트용)
  // TODO: 프로덕션 배포 전 실제 광고 단위 ID로 교체
  // ---------------------------------------------------------------------------

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-6951210541539723/1592516015';
    } else {
      return 'ca-app-pub-6951210541539723/1381533530';
    }
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-6951210541539723/2383757468';
    } else {
      return 'ca-app-pub-6951210541539723/1541449083';
    }
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-6951210541539723/5815532757';
    } else {
      return 'ca-app-pub-6951210541539723/8837281918';
    }
  }

  // ---------------------------------------------------------------------------
  // 배너 광고
  // ---------------------------------------------------------------------------

  /// 배너 광고 로드. 성공 시 BannerAd 반환, 실패 시 null.
  static Future<BannerAd?> loadBanner({
    AdSize size = AdSize.banner,
    Function(Ad)? onAdLoaded,
    Function(Ad, LoadAdError)? onAdFailedToLoad,
  }) async {
    if (!isAdEnabled) return null;
    final banner = BannerAd(
      adUnitId: bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          onAdLoaded?.call(ad);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('배너 광고 로드 실패: ${error.message}');
          ad.dispose();
          onAdFailedToLoad?.call(ad, error);
        },
      ),
    );
    await banner.load();
    return banner;
  }

  // ---------------------------------------------------------------------------
  // 전면 광고 (Interstitial)
  // ---------------------------------------------------------------------------

  static InterstitialAd? _interstitialAd;

  /// 전면 광고 미리 로드
  static void preloadInterstitial() {
    if (!isAdEnabled) return;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              preloadInterstitial(); // 다음 전면 광고 미리 로드
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('전면 광고 표시 실패: ${error.message}');
              ad.dispose();
              _interstitialAd = null;
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('전면 광고 로드 실패: ${error.message}');
          _interstitialAd = null;
        },
      ),
    );
  }

  /// 전면 광고 표시. 로드된 광고가 없으면 무시.
  static void showInterstitial() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
    }
  }

  /// 전면 광고가 준비되어 있는지 확인
  static bool get isInterstitialReady => _interstitialAd != null;

  // ---------------------------------------------------------------------------
  // 보상형 광고 (Rewarded)
  // ---------------------------------------------------------------------------

  static RewardedAd? _rewardedAd;

  /// 보상형 광고 미리 로드
  static void preloadRewarded() {
    if (!isAdEnabled) return;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              preloadRewarded(); // 다음 보상형 광고 미리 로드
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('보상형 광고 표시 실패: ${error.message}');
              ad.dispose();
              _rewardedAd = null;
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('보상형 광고 로드 실패: ${error.message}');
          _rewardedAd = null;
        },
      ),
    );
  }

  /// 보상형 광고 표시. [onRewarded] 콜백으로 보상 지급.
  /// 광고가 준비되지 않았으면 false 반환.
  static bool showRewarded({required void Function() onRewarded}) {
    if (_rewardedAd == null) return false;
    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        onRewarded();
      },
    );
    _rewardedAd = null;
    return true;
  }

  /// 보상형 광고가 준비되어 있는지 확인
  static bool get isRewardedReady => _rewardedAd != null;

  /// 모든 광고 리소스 해제
  static void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
