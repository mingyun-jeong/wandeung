import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/upload_queue_provider.dart';

class UploadStatusIndicator extends ConsumerWidget {
  final String recordId;
  final bool isLocalVideo;
  final bool localOnly;

  const UploadStatusIndicator({
    super.key,
    required this.recordId,
    this.isLocalVideo = false,
    this.localOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(uploadStatusProvider(recordId));

    // 클라우드 완료: 업로드 완료 아이콘 표시
    if (status == null && !isLocalVideo) {
      return const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(Icons.cloud_done, size: 16, color: Colors.blue),
      );
    }

    if (status == UploadStatus.uploaded) {
      return const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(Icons.cloud_done, size: 16, color: Colors.blue),
      );
    }

    // 로컬 전용 모드: 로컬 아이콘
    if (status == null && isLocalVideo && localOnly) {
      return const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(Icons.phone_android, size: 16, color: Colors.white),
      );
    }

    // 클라우드 모드인데 아직 업로드 큐에 없음 (백그라운드 준비 중)
    if (status == null && isLocalVideo && !localOnly) {
      return const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(Icons.cloud_queue, size: 16, color: Colors.grey),
      );
    }

    final (IconData icon, Color color, bool showProgress) = switch (status!) {
      UploadStatus.pending => (Icons.cloud_queue, Colors.grey, false),
      UploadStatus.uploading => (Icons.cloud_upload, Colors.blue, true),
      UploadStatus.failed => (Icons.cloud_off, Colors.red, false),
      UploadStatus.uploaded => (Icons.cloud_done, Colors.green, false),
    };

    return GestureDetector(
      onTap: status == UploadStatus.failed
          ? () => ref.read(uploadQueueProvider.notifier).retryFailed()
          : null,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: showProgress
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            : Icon(icon, size: 16, color: color),
      ),
    );
  }
}
