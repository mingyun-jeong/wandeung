import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 보상형 광고 관리 서비스
class AdService {
  static RewardedAd? _rewardedAd;
  static bool _isLoading = false;

  static String get _rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-6951210541539723/5815532757';
    } else {
      return 'ca-app-pub-6951210541539723/8837281918';
    }
  }

  /// SDK 초기화
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    loadRewardedAd();
  }

  /// 보상형 광고 미리 로드
  static void loadRewardedAd() {
    if (_rewardedAd != null || _isLoading) return;
    _isLoading = true;

    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
          debugPrint('[AdService] 보상형 광고 로드 완료');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoading = false;
          debugPrint('[AdService] 보상형 광고 로드 실패: ${error.message}');
        },
      ),
    );
  }

  /// 광고가 준비되었는지 확인
  static bool get isRewardedAdReady => _rewardedAd != null;

  /// 보상형 광고 표시
  /// [onRewarded] 사용자가 광고를 끝까지 시청하면 호출
  /// [onDismissed] 광고 닫힌 후 호출 (보상 여부 무관)
  static void showRewardedAd({
    required VoidCallback onRewarded,
    VoidCallback? onDismissed,
  }) {
    final ad = _rewardedAd;
    if (ad == null) {
      debugPrint('[AdService] 광고가 준비되지 않음');
      onDismissed?.call();
      return;
    }

    bool rewarded = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // 다음 광고 미리 로드
        if (rewarded) {
          onRewarded();
        }
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdService] 광고 표시 실패: ${error.message}');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onDismissed?.call();
      },
    );

    ad.show(onUserEarnedReward: (_, reward) {
      rewarded = true;
    });
  }
}
