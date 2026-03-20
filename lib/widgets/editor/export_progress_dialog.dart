import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/video_editor_provider.dart';
import '../../app.dart';

/// 내보내기 진행률을 예쁜 바텀시트로 표시한다.
class ExportProgressSheet extends ConsumerStatefulWidget {
  final VoidCallback? onCancel;
  final VoidCallback? onResume;
  final VoidCallback? onClose;

  const ExportProgressSheet({
    super.key,
    this.onCancel,
    this.onResume,
    this.onClose,
  });

  @override
  ConsumerState<ExportProgressSheet> createState() =>
      _ExportProgressSheetState();
}

class _ExportProgressSheetState extends ConsumerState<ExportProgressSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(exportProgressProvider);
    final status = ref.watch(exportStatusProvider);
    final percent = progress != null ? (progress * 100).round() : 0;
    final colorScheme = Theme.of(context).colorScheme;
    const teal = ClimpickColors.accent;

    return PopScope(
      canPop: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 드래그 핸들
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outline.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // 아이콘
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildStatusIcon(status, teal),
                ),
                const SizedBox(height: 16),

                // 상태 텍스트
                Text(
                  switch (status) {
                    ExportStatus.exporting => '내보내기 중...',
                    ExportStatus.completed => '내보내기 완료!',
                    ExportStatus.cancelled => '내보내기가 취소되었습니다',
                    ExportStatus.error => '내보내기에 실패했습니다',
                  },
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 20),

                // 프로그레스 바 (진행 중 또는 완료 시에만)
                if (status == ExportStatus.exporting ||
                    status == ExportStatus.completed) ...[
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: teal.withOpacity(0.1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          final isComplete =
                              status == ExportStatus.completed;
                          return LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isComplete
                                  ? teal
                                  : Color.lerp(
                                      teal,
                                      teal.withOpacity(0.7),
                                      _pulseController.value,
                                    )!,
                            ),
                            minHeight: 8,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$percent%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: teal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 액션 버튼
                _buildActionButtons(status, colorScheme, teal),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(ExportStatus status, Color teal) {
    return switch (status) {
      ExportStatus.exporting => Container(
          key: const ValueKey('exporting'),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: teal.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.movie_creation_rounded,
            color: teal,
            size: 28,
          ),
        ),
      ExportStatus.completed => Container(
          key: const ValueKey('completed'),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: teal.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_rounded,
            color: teal,
            size: 32,
          ),
        ),
      ExportStatus.cancelled => Container(
          key: const ValueKey('cancelled'),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.pause_circle_rounded,
            color: Colors.orange,
            size: 32,
          ),
        ),
      ExportStatus.error => Container(
          key: const ValueKey('error'),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_rounded,
            color: Colors.red,
            size: 32,
          ),
        ),
    };
  }

  Widget _buildActionButtons(
    ExportStatus status,
    ColorScheme colorScheme,
    Color teal,
  ) {
    return switch (status) {
      ExportStatus.exporting => SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: widget.onCancel,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('취소'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.onSurface.withOpacity(0.6),
              side: BorderSide(
                color: colorScheme.outline.withOpacity(0.2),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ExportStatus.cancelled || ExportStatus.error => Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: widget.onClose,
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        colorScheme.onSurface.withOpacity(0.6),
                    side: BorderSide(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('닫기'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: widget.onResume,
                  icon: Icon(
                    status == ExportStatus.cancelled
                        ? Icons.play_arrow_rounded
                        : Icons.refresh_rounded,
                    size: 20,
                  ),
                  label: Text(
                    status == ExportStatus.cancelled
                        ? '다시 내보내기'
                        : '다시 시도',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ExportStatus.completed => const SizedBox.shrink(),
    };
  }
}
