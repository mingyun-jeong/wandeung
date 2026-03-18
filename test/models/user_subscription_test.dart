import 'package:flutter_test/flutter_test.dart';
import 'package:cling/models/user_subscription.dart';

void main() {
  group('UserSubscription', () {
    test('isPro returns true for active pro with future expiry', () {
      final sub = UserSubscription(
        id: '1',
        userId: 'user1',
        plan: 'pro',
        status: 'active',
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(sub.isPro, isTrue);
    });

    test('isPro returns false for expired pro', () {
      final sub = UserSubscription(
        id: '1',
        userId: 'user1',
        plan: 'pro',
        status: 'active',
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(sub.isPro, isFalse);
    });

    test('isPro returns false for cancelled pro', () {
      final sub = UserSubscription(
        id: '1',
        userId: 'user1',
        plan: 'pro',
        status: 'cancelled',
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(sub.isPro, isFalse);
    });

    test('isPro returns false for free plan', () {
      final sub = UserSubscription(
        id: '1',
        userId: 'user1',
        plan: 'free',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(sub.isPro, isFalse);
    });

    test('isPro returns false when expiresAt is null', () {
      final sub = UserSubscription(
        id: '1',
        userId: 'user1',
        plan: 'pro',
        status: 'active',
        expiresAt: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(sub.isPro, isFalse);
    });

    test('fromMap correctly deserializes', () {
      final map = {
        'id': 'abc',
        'user_id': 'user1',
        'plan': 'pro',
        'status': 'active',
        'platform': 'android',
        'store_transaction_id': 'txn123',
        'started_at': '2026-03-01T00:00:00Z',
        'expires_at': '2026-04-01T00:00:00Z',
        'created_at': '2026-03-01T00:00:00Z',
        'updated_at': '2026-03-01T00:00:00Z',
      };

      final sub = UserSubscription.fromMap(map);
      expect(sub.id, 'abc');
      expect(sub.userId, 'user1');
      expect(sub.plan, 'pro');
      expect(sub.status, 'active');
      expect(sub.platform, 'android');
      expect(sub.storeTransactionId, 'txn123');
      expect(sub.startedAt, isNotNull);
      expect(sub.expiresAt, isNotNull);
    });

    test('fromMap handles null optional fields', () {
      final map = {
        'id': 'abc',
        'user_id': 'user1',
        'plan': null,
        'status': null,
        'platform': null,
        'store_transaction_id': null,
        'started_at': null,
        'expires_at': null,
        'created_at': '2026-03-01T00:00:00Z',
        'updated_at': '2026-03-01T00:00:00Z',
      };

      final sub = UserSubscription.fromMap(map);
      expect(sub.plan, 'free');
      expect(sub.status, 'active');
      expect(sub.platform, 'android');
      expect(sub.storeTransactionId, isNull);
      expect(sub.startedAt, isNull);
      expect(sub.expiresAt, isNull);
    });
  });

  group('StorageMode', () {
    test('has cloud and local values', () {
      expect(StorageMode.values.length, 2);
      expect(StorageMode.cloud.name, 'cloud');
      expect(StorageMode.local.name, 'local');
    });
  });

  group('SubscriptionTier', () {
    test('has free and pro values', () {
      expect(SubscriptionTier.values.length, 2);
      expect(SubscriptionTier.free.name, 'free');
      expect(SubscriptionTier.pro.name, 'pro');
    });
  });
}
