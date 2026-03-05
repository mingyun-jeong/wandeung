import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/video_editor_provider.dart';

/// 내보내기 진행률 표시 다이얼로그
class ExportProgressDialog extends ConsumerWidget {
  final VoidCallback? onCancel;

  const ExportProgressDialog({super.key, this.onCancel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(exportProgressProvider);
    final percent = progress != null ? (progress * 100).round() : 0;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '내보내기 중... $percent%',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: onCancel != null
            ? [
                TextButton(
                  onPressed: onCancel,
                  child: const Text('취소'),
                ),
              ]
            : null,
      ),
    );
  }
}
