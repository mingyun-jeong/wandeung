import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/upload_queue_provider.dart';
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

    final wifiOnly = ref.watch(wifiOnlyUploadProvider);
    final uploadQueue = ref.watch(uploadQueueProvider);
    final pendingCount =
        uploadQueue.where((t) => t.status == UploadStatus.pending).length;
    final uploadingCount =
        uploadQueue.where((t) => t.status == UploadStatus.uploading).length;
    final failedCount =
        uploadQueue.where((t) => t.status == UploadStatus.failed).length;
    final totalPending = pendingCount + uploadingCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '내 프로필',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 32),
          // 프로필 아바타
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundImage:
                  photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? const Icon(Icons.person, size: 48)
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          // 이름
          Center(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // 이메일
          Center(
            child: Text(
              email,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // --- 설정 섹션 ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '설정',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withOpacity(0.4),
                letterSpacing: 0.5,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Wi-Fi에서만 업로드'),
            subtitle: const Text('모바일 데이터 사용 시 영상 업로드를 대기합니다'),
            value: wifiOnly,
            onChanged: (_) {
              ref.read(wifiOnlyUploadProvider.notifier).toggle();
              // Wi-Fi 전용 해제 시 대기 중 업로드 즉시 시작
              if (wifiOnly) {
                ref.read(uploadQueueProvider.notifier).processQueue();
              }
            },
          ),

          // 업로드 상태 표시
          if (totalPending > 0 || failedCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    failedCount > 0 ? Icons.cloud_off : Icons.cloud_upload,
                    size: 16,
                    color: failedCount > 0 ? Colors.red : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        if (totalPending > 0) '대기 중: ${totalPending}건',
                        if (failedCount > 0) '실패: ${failedCount}건',
                      ].join(' / '),
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                  if (failedCount > 0)
                    TextButton(
                      onPressed: () =>
                          ref.read(uploadQueueProvider.notifier).retryFailed(),
                      child: const Text('모두 재시도'),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              height: 1,
              color: colorScheme.outline.withOpacity(0.15),
            ),
          ),
          const SizedBox(height: 8),

          // 회원탈퇴
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextButton(
              onPressed: () => _showDeleteAccountDialog(context, ref),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
              child: const Text('회원탈퇴'),
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
