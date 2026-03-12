import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/upload_queue_provider.dart';

class UploadStatusIndicator extends ConsumerWidget {
  final String recordId;

  const UploadStatusIndicator({super.key, required this.recordId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(uploadStatusProvider(recordId));

    if (status == null || status == UploadStatus.uploaded) {
      return const SizedBox.shrink();
    }

    final (IconData icon, Color color, bool showProgress) = switch (status) {
      UploadStatus.pending => (Icons.cloud_queue, Colors.grey, false),
      UploadStatus.uploading => (Icons.cloud_upload, Colors.blue, true),
      UploadStatus.failed => (Icons.cloud_off, Colors.red, false),
      UploadStatus.uploaded => (Icons.cloud_done, Colors.green, false),
    };

    return GestureDetector(
      onTap: status == UploadStatus.failed
          ? () => ref.read(uploadQueueProvider.notifier).retryFailed()
          : null,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
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
