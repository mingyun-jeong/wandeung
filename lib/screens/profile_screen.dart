import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/climbing_gym.dart';
import '../models/user_subscription.dart';
import '../providers/auth_provider.dart';
import '../providers/favorite_gym_provider.dart';
import '../providers/subscription_provider.dart';
import '../widgets/favorite_gym_sheet.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final colorScheme = Theme.of(context).colorScheme;
    final metadata = user?.userMetadata;
    final name = metadata?['full_name'] as String? ??
        metadata?['name'] as String? ??
        '사용자';
    final email = user?.email ?? '';
    final photoUrl = metadata?['picture'] as String? ??
        metadata?['avatar_url'] as String?;
    final tier = ref.watch(subscriptionTierProvider);
    final isPro = tier == SubscriptionTier.pro;
    final storageMode = ref.watch(storageModeProvider);
    final isCloudMode = storageMode == StorageMode.cloud;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '내 프로필',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 36),

          // ── 아바타 ──
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPro
                      ? Colors.amber
                      : colorScheme.outlineVariant,
                  width: isPro ? 3.5 : 2,
                ),
              ),
              child: CircleAvatar(
                radius: 46,
                backgroundImage:
                    photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? const Icon(Icons.person, size: 46)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── 이름 ──
          Center(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // ── 이메일 ──
          Center(
            child: Text(
              email,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withOpacity(0.45),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── 플랜 뱃지 (탭하면 설정 화면) ──
          Center(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SettingsScreen()),
              ),
              child: _PlanBadge(
                isPro: isPro,
                isCloudMode: isCloudMode,
              ),
            ),
          ),

          const SizedBox(height: 40),

          // ── 내 암장 섹션 ──
          const _FavoriteGymsSection(),

          const SizedBox(height: 24),

          // ── 계정 섹션 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    '계정',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withOpacity(0.3),
                    ),
                  ),
                  child: InkWell(
                    onTap: () => _showDeleteAccountDialog(context, ref),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded,
                              size: 20, color: colorScheme.error),
                          const SizedBox(width: 12),
                          Text(
                            '회원탈퇴',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.error,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded,
                              size: 20,
                              color:
                                  colorScheme.onSurface.withOpacity(0.25)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('회원탈퇴'),
        content: const Text(
          '탈퇴하면 모든 등반 기록과 영상이 삭제되며 복구할 수 없습니다.\n정말 탈퇴하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _deleteAccount(context, ref);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authProvider.notifier).deleteAccount();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원탈퇴가 완료되었습니다.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회원탈퇴 실패: $e')),
        );
      }
    }
  }
}

// ── 플랜 뱃지 ──
class _PlanBadge extends StatelessWidget {
  final bool isPro;
  final bool isCloudMode;

  const _PlanBadge({required this.isPro, required this.isCloudMode});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!isCloudMode) {
      // 로컬 모드
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_android_outlined,
                size: 16,
                color: colorScheme.onSurface.withOpacity(0.5)),
            const SizedBox(width: 6),
            Text(
              '로컬 모드',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 16,
                color: colorScheme.onSurface.withOpacity(0.25)),
          ],
        ),
      );
    }

    if (isPro) {
      // Pro
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.withOpacity(0.15),
              Colors.orange.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.amber.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded,
                size: 16, color: Colors.amber),
            const SizedBox(width: 6),
            const Text(
              'Pro',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.amber,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 16,
                color: Colors.amber.withOpacity(0.5)),
          ],
        ),
      );
    }

    // Free
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_outlined,
              size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            'Free',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded,
              size: 16,
              color: colorScheme.primary.withOpacity(0.4)),
        ],
      ),
    );
  }
}

class _FavoriteGymsSection extends ConsumerWidget {
  const _FavoriteGymsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final favoriteGyms = ref.watch(favoriteGymsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더: "내 암장" + 추가 버튼
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Text('내 암장',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withOpacity(0.4))),
                const Spacer(),
                GestureDetector(
                  onTap: () => FavoriteGymSheet.show(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 16,
                        color: colorScheme.onSurface.withOpacity(0.4)),
                      const SizedBox(width: 2),
                      Text('추가', style: TextStyle(fontSize: 13,
                        color: colorScheme.onSurface.withOpacity(0.4))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 즐겨찾기 목록 또는 빈 상태
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: favoriteGyms.when(
              data: (gyms) {
                if (gyms.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('자주 가는 암장을 추가해보세요',
                        style: TextStyle(fontSize: 13,
                          color: colorScheme.onSurface.withOpacity(0.3))),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < gyms.length; i++) ...[
                      _FavoriteGymTile(gym: gyms[i]),
                      if (i < gyms.length - 1)
                        Divider(height: 1, indent: 16, endIndent: 16,
                          color: colorScheme.outlineVariant.withOpacity(0.2)),
                    ],
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteGymTile extends ConsumerWidget {
  final ClimbingGym gym;
  const _FavoriteGymTile({required this.gym});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 18,
            color: colorScheme.onSurface.withOpacity(0.4)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gym.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
                if (gym.address != null)
                  Text(gym.address!, style: TextStyle(fontSize: 11,
                    color: colorScheme.onSurface.withOpacity(0.35)),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              if (gym.id == null) return;
              await FavoriteGymService.removeFavorite(gym.id!);
              ref.invalidate(favoriteGymsProvider);
              ref.invalidate(recommendedGymsProvider);
            },
            child: Icon(Icons.close_rounded, size: 16,
              color: colorScheme.onSurface.withOpacity(0.25)),
          ),
        ],
      ),
    );
  }
}
