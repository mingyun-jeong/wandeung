import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/video_editor_provider.dart';

/// 배속 선택 바텀시트
class SpeedPickerSheet extends ConsumerWidget {
  /// 현재 선택된 구간 인덱스 (null이면 전체 영상에 적용)
  final int? segmentIndex;

  const SpeedPickerSheet({super.key, this.segmentIndex});

  static const _speedOptions = [
    (0.5, '0.5배속'),
    (1.0, '1배속'),
    (2.0, '2배속'),
    (4.0, '4배속'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segments = ref.watch(speedSegmentsProvider);
    final currentSpeed = segmentIndex != null && segmentIndex! < segments.length
        ? segments[segmentIndex!].speed
        : (segments.isNotEmpty ? segments.first.speed : 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '속도',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _speedOptions.map((option) {
              final (speed, label) = option;
              final isSelected = (currentSpeed - speed).abs() < 0.01;

              return GestureDetector(
                onTap: () {
                  if (segmentIndex != null) {
                    ref
                        .read(speedSegmentsProvider.notifier)
                        .updateSpeed(segmentIndex!, speed);
                  } else {
                    ref
                        .read(speedSegmentsProvider.notifier)
                        .setUniformSpeed(speed);
                  }
                  Navigator.pop(context);
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected
                        ? null
                        : Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
