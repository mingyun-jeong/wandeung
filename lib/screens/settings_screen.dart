import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app.dart';
import '../models/user_subscription.dart';
import '../providers/camera_settings_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/gallery_save_path_provider.dart';
import '../providers/app_config_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/upload_queue_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        actions: [
          if (isCloudMode)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 22),
              tooltip: '사용량 새로고침',
              onPressed: () {
                ref.invalidate(cloudUsageProvider);
              },
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // --- 저장 모드 ---
          const _SectionHeader(label: '저장 모드'),
          const SizedBox(height: 10),

          // --- 클라우드 / 로컬 세그먼트 선택 ---
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
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
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
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
                                const Text(
                                  '새 영상이 서버에 저장되지 않습니다.\n'
                                  '원본 영상은 현재 기기에만 저장되며,\n'
                                  '기기 분실 시 영상을 복구할 수 없습니다.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: ReclimColors.textSecondary,
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
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: Colors.amber),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '원본 영상은 현재 기기에만 저장됩니다.\n기기 분실 시 영상을 복구할 수 없습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: ReclimColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 28),

          // --- 갤러리 저장 경로 ---
          const _SectionHeader(label: '갤러리 저장 경로'),
          const SizedBox(height: 10),
          _GallerySavePathCard(),

          const SizedBox(height: 28),

          // --- 진입 모드 ---
          const _SectionHeader(label: '진입 모드'),
          const SizedBox(height: 10),
          _EntryModeCard(),
        ],
      ),
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
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: ReclimColors.textTertiary,
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
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? ReclimColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : ReclimColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : ReclimColors.textSecondary,
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

  const _CloudCard({
    required this.isPro,
    required this.wifiOnly,
    required this.totalPending,
    required this.failedCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ReclimColors.border,
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
                  color: isPro ? Colors.amber : ReclimColors.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  isPro ? 'Pro' : 'Free',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ReclimColors.textPrimary,
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Divider(
              height: 1,
              color: ReclimColors.border,
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
                      style: const TextStyle(
                        fontSize: 13,
                        color: ReclimColors.textSecondary,
                      ),
                    ),
                  ),
                  if (failedCount > 0)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
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

          // Pro 업그레이드 — 히든 (추후 활성화)
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

String _formatStorageSize(int bytes) {
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (bytes >= gb) {
    return '${(bytes / gb).toStringAsFixed(1)} GB';
  }
  return '${(bytes / mb).toStringAsFixed(1)} MB';
}

// ─── 클라우드 사용량 프로그레스 바 ────────────────────────────────
class _CloudUsageIndicator extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(cloudUsageProvider);

    return usageAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text('사용량 확인 실패',
          style: TextStyle(fontSize: 12, color: ReclimColors.textTertiary)),
      ),
      data: (usedBytes) {
        final limitAsync = ref.watch(freeStorageLimitBytesProvider);
        final limitBytes = limitAsync.valueOrNull ?? (500 * 1024 * 1024);
        final usedLabel = _formatStorageSize(usedBytes);
        final ratio = (usedBytes / limitBytes).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '사용량',
                    style: TextStyle(
                      fontSize: 12,
                      color: ReclimColors.textSecondary,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$usedLabel / ',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ReclimColors.textSecondary,
                        ),
                      ),
                      Text(
                        _formatStorageSize(limitBytes.toInt()),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ReclimColors.textTertiary,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: ReclimColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '무제한',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: ReclimColors.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  backgroundColor: ReclimColors.border,
                  valueColor: AlwaysStoppedAnimation(
                    ratio > 0.9 ? Colors.red : ReclimColors.accent,
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

// ─── 진입 모드 카드 ─────────────────────────────────────────────
class _EntryModeCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCameraEntry = ref.watch(entryModeCameraProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ReclimColors.border),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: const Text(
          '촬영 모드로 시작',
          style: TextStyle(fontSize: 14),
        ),
        subtitle: const Text(
          '앱 실행 시 바로 촬영 화면으로 진입합니다',
          style: TextStyle(fontSize: 12),
        ),
        secondary: Icon(
          Icons.videocam_rounded,
          size: 22,
          color: isCameraEntry
              ? ReclimColors.accent
              : ReclimColors.textTertiary,
        ),
        value: isCameraEntry,
        onChanged: (_) =>
            ref.read(entryModeCameraProvider.notifier).toggle(),
      ),
    );
  }
}

// ─── 갤러리 저장 경로 카드 ──────────────────────────────────────
class _GallerySavePathCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(gallerySavePathProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ReclimColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GallerySavePathOption(
            icon: Icons.photo_library_outlined,
            label: '모든 영상을 "리클림" 앨범에 저장',
            example: '리클림/',
            value: GallerySavePath.defaultAlbum,
            groupValue: current,
            isFirst: true,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Divider(height: 1, color: ReclimColors.border),
          ),
          _GallerySavePathOption(
            icon: Icons.store_outlined,
            label: '암장 이름으로 앨범을 분리하여 저장',
            example: '더클라임 신사/',
            value: GallerySavePath.byGym,
            groupValue: current,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _GallerySavePathOption extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String example;
  final GallerySavePath value;
  final GallerySavePath groupValue;
  final bool isFirst;
  final bool isLast;

  const _GallerySavePathOption({
    required this.icon,
    required this.label,
    required this.example,
    required this.value,
    required this.groupValue,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = value == groupValue;

    return InkWell(
      onTap: () => ref.read(gallerySavePathProvider.notifier).set(value),
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(14) : Radius.zero,
        bottom: isLast ? const Radius.circular(14) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? ReclimColors.accent
                  : ReclimColors.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? ReclimColors.textPrimary
                          : ReclimColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      example,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: ReclimColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? ReclimColors.accent
                      : ReclimColors.textTertiary,
                  width: isSelected ? 6 : 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
