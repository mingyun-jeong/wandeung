import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';
import '../providers/upload_queue_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
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
          '환경설정',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),

          // --- 업로드 설정 ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '업로드',
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
                        if (totalPending > 0) '대기 중: $totalPending건',
                        if (failedCount > 0) '실패: $failedCount건',
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
        ],
      ),
    );
  }
}
