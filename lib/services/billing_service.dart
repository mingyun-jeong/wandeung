import 'package:flutter/foundation.dart';

/// Google Play Billing 연동 서비스 (스텁)
///
/// 실제 구현은 google_play_billing 패키지 추가 후 진행.
/// 현재는 구독 상태를 DB(user_subscriptions)에서 읽어 판단하며,
/// 결제 흐름은 Google Play Console 설정 후 활성화.
class BillingService {
  BillingService._();

  /// 구독 상품 ID
  static const String proMonthlyId = 'pro_monthly';
  static const String proYearlyId = 'pro_yearly';

  /// 구독 구매 시작
  static Future<bool> purchaseSubscription(String productId) async {
    debugPrint('[Billing] purchaseSubscription($productId) — 아직 미구현');
    return false;
  }

  /// 구독 상태 복원
  static Future<void> restorePurchases() async {
    debugPrint('[Billing] restorePurchases — 아직 미구현');
  }
}
