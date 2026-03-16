import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_subscription.dart';
import '../providers/connectivity_provider.dart';
import '../providers/record_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/upload_queue_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final storageMode = ref.watch(storageModeProvider);
    final isCloudMode = storageMode == StorageMode.cloud;
    final wifiOnly = ref.watch(wifiOnlyUploadProvider);
    final uploadQueue = ref.watch(uploadQueueProvider);
    final tier = ref.watch(subscriptionTierProvider);
    final isPro = tier == SubscriptionTier.pro;
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
          '환경설정',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // --- 섹션 헤더 ---
          _SectionHeader(label: '저장 모드'),
          const SizedBox(height: 10),

          // --- 클라우드 / 로컬 세그먼트 선택 ---
          Container(
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _ModeSegment(
                  icon: Icons.cloud_outlined,
                  label: '클라우드',
                  isSelected: isCloudMode,
                  onTap: () => ref
                      .read(storageModeProvider.notifier)
                      .setMode(StorageMode.cloud),
                ),
                const SizedBox(width: 4),
                _ModeSegment(
                  icon: Icons.phone_android_outlined,
                  label: '로컬',
                  isSelected: !isCloudMode,
                  onTap: () async {
                    if (!isCloudMode) return;
                    final confirmed = await showModalBottomSheet<bool>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20)),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                                24, 16, 24, 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 드래그 핸들
                                Container(
                                  width: 36,
                                  height: 4,
                                  margin:
                                      const EdgeInsets.only(bottom: 24),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius:
                                        BorderRadius.circular(2),
                                  ),
                                ),
                                // 아이콘
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.phone_android_outlined,
                                    size: 28,
                                    color: Colors.amber,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  '로컬 모드로 전환',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '새 영상이 서버에 저장되지 않습니다.\n'
                                  '원본 영상은 현재 기기에만 저장되며,\n'
                                  '기기 분실 시 영상을 복구할 수 없습니다.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.55),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // 버튼
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        style: OutlinedButton.styleFrom(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Text('취소'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        style: FilledButton.styleFrom(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 14),
                                          backgroundColor: Colors.amber,
                                          foregroundColor: Colors.black87,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Text(
                                          '그래도 전환',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                    if (confirmed == true) {
                      ref
                          .read(storageModeProvider.notifier)
                          .setMode(StorageMode.local);
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─── 클라우드 모드 세부 ───
          if (isCloudMode) ...[
            _CloudCard(
              isPro: isPro,
              wifiOnly: wifiOnly,
              totalPending: totalPending,
              failedCount: failedCount,
              ref: ref,
            ),
          ],

          // ─── 로컬 모드 안내 ───
          if (!isCloudMode)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 18, color: Colors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '원본 영상은 현재 기기에만 저장됩니다.\n기기 분실 시 영상을 복구할 수 없습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 28),

          // --- 로컬 영상 관리 ---
          if (isCloudMode) ...[
            _SectionHeader(label: '로컬 영상'),
            const SizedBox(height: 8),
            _LocalVideoSection(),
          ],
        ],
      ),
    );
  }
}

// ─── 섹션 헤더 ───────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
        letterSpacing: 0.3,
      ),
    );
  }
}

// ─── 세그먼트 버튼 ─────────────────────────────────────────────
class _ModeSegment extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeSegment({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 클라우드 카드 (하위 옵션 포함) ──────────────────────────────
class _CloudCard extends ConsumerWidget {
  final bool isPro;
  final bool wifiOnly;
  final int totalPending;
  final int failedCount;
  final WidgetRef ref;

  const _CloudCard({
    required this.isPro,
    required this.wifiOnly,
    required this.totalPending,
    required this.failedCount,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 플랜 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(
                  isPro ? Icons.star_rounded : Icons.cloud_outlined,
                  size: 18,
                  color: isPro ? Colors.amber : colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  isPro ? 'Pro (1080p 원본)' : 'Free (720p 압축)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          // 사용량 (Free만)
          if (!isPro) ...[
            const SizedBox(height: 10),
            _CloudUsageIndicator(),
          ],

          // 구분선
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Divider(
              height: 1,
              color: colorScheme.onSurface.withOpacity(0.08),
            ),
          ),

          // Wi-Fi 전용 업로드
          SwitchListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16),
            title: const Text(
              'Wi-Fi에서만 업로드',
              style: TextStyle(fontSize: 14),
            ),
            subtitle: const Text(
              '모바일 데이터 사용 시 업로드를 대기합니다',
              style: TextStyle(fontSize: 12),
            ),
            value: wifiOnly,
            onChanged: (_) {
              ref.read(wifiOnlyUploadProvider.notifier).toggle();
              if (wifiOnly) {
                ref.read(uploadQueueProvider.notifier).processQueue();
              }
            },
          ),

          // 업로드 상태
          if (totalPending > 0 || failedCount > 0) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    failedCount > 0
                        ? Icons.cloud_off
                        : Icons.cloud_upload_outlined,
                    size: 15,
                    color: failedCount > 0 ? Colors.red : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        if (totalPending > 0) '대기 중 $totalPending건',
                        if (failedCount > 0) '실패 $failedCount건',
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withOpacity(0.55),
                      ),
                    ),
                  ),
                  if (failedCount > 0)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => ref
                          .read(uploadQueueProvider.notifier)
                          .retryFailed(),
                      child: const Text('재시도',
                          style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
          ],

          // Pro 업그레이드 (Free만)
          if (!isPro)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(
                      color: colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('준비 중인 기능입니다')),
                    );
                  },
                  icon: const Icon(Icons.star_rounded, size: 16),
                  label: const Text('Pro로 업그레이드',
                      style: TextStyle(fontSize: 13)),
                ),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── 클라우드 사용량 프로그레스 바 ────────────────────────────────
class _CloudUsageIndicator extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(cloudUsageProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return usageAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (usedBytes) {
        const limitBytes = freeStorageLimitBytes;
        final usedGB = usedBytes / 1024 / 1024 / 1024;
        const limitGB = freeStorageLimitBytes / 1024 / 1024 / 1024;
        final ratio = (usedBytes / limitBytes).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '사용량',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  Text(
                    '${usedGB.toStringAsFixed(1)} GB / ${limitGB.toStringAsFixed(0)} GB',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ratio > 0.9
                          ? Colors.red
                          : colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  backgroundColor:
                      colorScheme.onSurface.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation(
                    ratio > 0.9 ? Colors.red : colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}

// ─── 로컬 영상 섹션 ─────────────────────────────────────────────
class _LocalVideoSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localRecordsAsync = ref.watch(localOnlyRecordsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return localRecordsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('오류: $e',
            style: TextStyle(color: colorScheme.error, fontSize: 13)),
      ),
      data: (records) {
        final queue = ref.watch(uploadQueueProvider);
        final queuedIds = queue.map((t) => t.recordId).toSet();
        final orphaned =
            records.where((r) => !queuedIds.contains(r.id)).toList();
        final uploadable = orphaned
            .where((r) =>
                r.videoPath != null && File(r.videoPath!).existsSync())
            .toList();
        final missingCount = orphaned.length - uploadable.length;

        if (orphaned.isEmpty) {
          return Row(
            children: [
              const Icon(Icons.cloud_done, size: 16, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                '모든 영상이 서버에 업로드되었습니다',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_off_outlined,
                    size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '업로드되지 않은 영상: ${orphaned.length}건',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
            if (missingCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 2),
                child: Text(
                  '${uploadable.length}건 업로드 가능 · $missingCount건 파일 없음',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ),
            if (uploadable.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final count = await ref
                          .read(uploadQueueProvider.notifier)
                          .enqueueLocalRecords(uploadable);
                      ref.invalidate(localOnlyRecordsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('$count건 업로드 대기열에 추가됨')),
                        );
                      }
                    },
                    icon: const Icon(Icons.cloud_upload, size: 18),
                    label: Text('모두 업로드 (${uploadable.length}건)'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
