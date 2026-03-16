/// 사용자 구독 정보
class UserSubscription {
  final String id;
  final String userId;
  final String plan; // 'free' | 'pro'
  final String status; // 'active' | 'cancelled' | 'expired'
  final String platform;
  final String? storeTransactionId;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserSubscription({
    required this.id,
    required this.userId,
    this.plan = 'free',
    this.status = 'active',
    this.platform = 'android',
    this.storeTransactionId,
    this.startedAt,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Pro 플랜이 현재 유효한지 판별
  bool get isPro =>
      plan == 'pro' &&
      status == 'active' &&
      expiresAt != null &&
      expiresAt!.isAfter(DateTime.now());

  factory UserSubscription.fromMap(Map<String, dynamic> map) =>
      UserSubscription(
        id: map['id'],
        userId: map['user_id'],
        plan: map['plan'] ?? 'free',
        status: map['status'] ?? 'active',
        platform: map['platform'] ?? 'android',
        storeTransactionId: map['store_transaction_id'],
        startedAt: map['started_at'] != null
            ? DateTime.parse(map['started_at'])
            : null,
        expiresAt: map['expires_at'] != null
            ? DateTime.parse(map['expires_at'])
            : null,
        createdAt: DateTime.parse(map['created_at']),
        updatedAt: DateTime.parse(map['updated_at']),
      );
}

/// 저장 모드
enum StorageMode {
  cloud, // 클라우드 (기본)
  local, // 로컬
}

/// 구독 티어
enum SubscriptionTier {
  free, // 720p, 3GB
  pro, // 1080p, 무제한
}
