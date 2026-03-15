import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/climbing_gym.dart';
import '../providers/auth_provider.dart';
import '../providers/favorite_gym_provider.dart';
import '../providers/user_grade_provider.dart';
import '../utils/constants.dart';
import '../widgets/favorite_gym_sheet.dart';
import 'login_screen.dart';

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
    final userGrade = ref.watch(userGradeProvider);
    final gradeColor = userGrade != null
        ? Color(userGrade.defaultColor.colorValue)
        : null;

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

          // ── 아바타 + 등급 색상 링 ──
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: gradeColor ?? colorScheme.outlineVariant,
                  width: gradeColor != null ? 3.5 : 2,
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

          // ── 등급 뱃지 (탭하면 바텀시트) ──
          Center(
            child: GestureDetector(
              onTap: () => _showGradeSheet(context, ref),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: gradeColor != null
                      ? gradeColor.withOpacity(0.1)
                      : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: gradeColor != null
                        ? gradeColor.withOpacity(0.3)
                        : colorScheme.outlineVariant.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: gradeColor ?? Colors.grey[300],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black.withOpacity(0.08),
                          width: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      userGrade != null ? userGrade.label : '등급 선택',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: userGrade != null
                            ? colorScheme.onSurface
                            : colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                    if (userGrade != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        userGrade.defaultColor.korean,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    Icon(
                      Icons.edit_rounded,
                      size: 14,
                      color: colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ],
                ),
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

  // ── 등급 선택 바텀시트 (그리드) ──
  void _showGradeSheet(BuildContext context, WidgetRef ref) {
    final grades =
        ClimbingGrade.values.where((g) => g.sortIndex <= 10).toList();
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final selected = ref.read(userGradeProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 드래그 핸들
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 헤더
                Row(
                  children: [
                    const Text(
                      '내 등급 설정',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '촬영 시 자동 적용',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 선택 안함 칩
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () {
                      ref.read(userGradeProvider.notifier).setGrade(null);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected == null
                            ? colorScheme.primary.withOpacity(0.1)
                            : colorScheme.surfaceContainerHighest
                                .withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected == null
                              ? colorScheme.primary.withOpacity(0.4)
                              : colorScheme.outlineVariant.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        '선택 안함',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected == null
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected == null
                              ? colorScheme.primary
                              : colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 등급 그리드
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: grades.map((grade) {
                    final isSelected = grade == selected;
                    final color = Color(grade.defaultColor.colorValue);
                    final needsDark = grade.defaultColor.needsDarkIcon;

                    return GestureDetector(
                      onTap: () {
                        ref
                            .read(userGradeProvider.notifier)
                            .setGrade(grade);
                        Navigator.pop(context);
                      },
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? colorScheme.primary
                                    : Colors.black.withOpacity(0.08),
                                width: isSelected ? 3 : 1.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? Icon(Icons.check_rounded,
                                    color: needsDark
                                        ? Colors.black87
                                        : Colors.white,
                                    size: 22)
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            grade.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
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
