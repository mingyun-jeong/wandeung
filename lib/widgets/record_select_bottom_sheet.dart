import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../config/r2_config.dart';
import '../models/climbing_record.dart';
import '../providers/record_provider.dart';
import '../utils/constants.dart';
import '../app.dart';

Future<ClimbingRecord?> showRecordSelectBottomSheet(
  BuildContext context, {
  String? excludeRecordId,
}) {
  return showModalBottomSheet<ClimbingRecord>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    backgroundColor: Colors.white,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) => _RecordSelectSheet(
        excludeRecordId: excludeRecordId,
        scrollController: scrollController,
      ),
    ),
  );
}

class _RecordSelectSheet extends ConsumerStatefulWidget {
  final String? excludeRecordId;
  final ScrollController scrollController;

  const _RecordSelectSheet({
    this.excludeRecordId,
    required this.scrollController,
  });

  @override
  ConsumerState<_RecordSelectSheet> createState() => _RecordSelectSheetState();
}

class _RecordSelectSheetState extends ConsumerState<_RecordSelectSheet> {
  String? _filterGym;
  String? _filterColor;
  String? _filterStatus;
  String? _filterTag;

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  List<ClimbingRecord> _applyFilters(List<ClimbingRecord> records) {
    return records.where((r) {
      if (_filterGym != null && r.gymName != _filterGym) return false;
      if (_filterColor != null && r.difficultyColor != _filterColor) return false;
      if (_filterStatus != null && r.status != _filterStatus) return false;
      if (_filterTag != null && !r.tags.contains(_filterTag)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(recordsWithVideoProvider(widget.excludeRecordId));
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.outline.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '비교할 영상 선택',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        // 필터 바
        recordsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (records) => _buildFilterBar(context, records),
        ),
        Divider(height: 1, color: colorScheme.outline.withOpacity(0.15)),
        Expanded(
          child: recordsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류가 발생했습니다: $e')),
            data: (records) {
              final filtered = _applyFilters(records);
              if (records.isEmpty) {
                return _buildEmpty(colorScheme, '비교할 영상이 없습니다');
              }
              if (filtered.isEmpty) {
                return _buildEmpty(colorScheme, '필터 조건에 맞는 영상이 없습니다');
              }
              return ListView.separated(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: colorScheme.outline.withOpacity(0.1),
                ),
                itemBuilder: (context, index) {
                  final record = filtered[index];
                  return _RecordSelectItem(
                    record: record,
                    onTap: () => Navigator.pop(context, record),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off_rounded,
              size: 48, color: colorScheme.onSurface.withOpacity(0.25)),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, List<ClimbingRecord> records) {
    // 기록에서 필터 옵션 추출
    final gyms = records
        .map((r) => r.gymName)
        .where((n) => n != null)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();

    final tags = records
        .expand((r) => r.tags)
        .toSet()
        .toList()
      ..sort();

    final activeDc = _filterColor != null
        ? DifficultyColor.values.firstWhere((c) => c.name == _filterColor)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildSelectBox(
              context: context,
              label: '암장',
              selectedValue: _filterGym,
              selectedDisplay: _filterGym,
              items: gyms.map((g) => _SelectItem(value: g, label: g)).toList(),
              onChanged: (v) => setState(() => _filterGym = v),
            ),
            const SizedBox(width: 8),
            _buildSelectBox(
              context: context,
              label: '상태',
              selectedValue: _filterStatus,
              selectedDisplay: _filterStatus != null
                  ? ClimbingStatus.values
                      .firstWhere((s) => s.name == _filterStatus)
                      .label
                  : null,
              items: ClimbingStatus.values
                  .map((s) => _SelectItem(value: s.name, label: s.label))
                  .toList(),
              onChanged: (v) => setState(() => _filterStatus = v),
            ),
            const SizedBox(width: 8),
            _buildSelectBox(
              context: context,
              label: '난이도',
              selectedValue: _filterColor,
              selectedDisplay: activeDc?.korean,
              selectedLeading: activeDc != null
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Color(activeDc.colorValue),
                        shape: BoxShape.circle,
                        border: activeDc.needsDarkIcon
                            ? Border.all(
                                color: Colors.black.withOpacity(0.15),
                                width: 0.5)
                            : null,
                      ),
                    )
                  : null,
              items: DifficultyColor.values
                  .map((dc) => _SelectItem(
                        value: dc.name,
                        label: dc.korean,
                        leading: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Color(dc.colorValue),
                            shape: BoxShape.circle,
                            border: dc.needsDarkIcon
                                ? Border.all(
                                    color: Colors.black.withOpacity(0.15),
                                    width: 0.5)
                                : null,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _filterColor = v),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(width: 8),
              _buildSelectBox(
                context: context,
                label: '태그',
                selectedValue: _filterTag,
                selectedDisplay: _filterTag,
                items:
                    tags.map((t) => _SelectItem(value: t, label: t)).toList(),
                onChanged: (v) => setState(() => _filterTag = v),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectBox({
    required BuildContext context,
    required String label,
    required String? selectedValue,
    required String? selectedDisplay,
    Widget? selectedLeading,
    required List<_SelectItem> items,
    required ValueChanged<String?> onChanged,
  }) {
    final isActive = selectedValue != null;
    final colorScheme = Theme.of(context).colorScheme;
    const clearSentinel = '__clear__';

    return PopupMenuButton<String>(
      onSelected: (v) => onChanged(v == clearSentinel ? null : v),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: clearSentinel,
          child: Row(children: [
            SizedBox(
              width: 20,
              child: !isActive
                  ? Icon(Icons.check_rounded,
                      size: 16, color: colorScheme.primary)
                  : null,
            ),
            const SizedBox(width: 4),
            Text('전체',
                style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7))),
          ]),
        ),
        const PopupMenuDivider(height: 1),
        ...items.map((item) => PopupMenuItem<String>(
              value: item.value,
              child: Row(children: [
                SizedBox(
                  width: 20,
                  child: item.value == selectedValue
                      ? Icon(Icons.check_rounded,
                          size: 16, color: colorScheme.primary)
                      : null,
                ),
                const SizedBox(width: 4),
                if (item.leading != null) ...[
                  item.leading!,
                  const SizedBox(width: 8),
                ],
                Text(item.label),
              ]),
            )),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:
              isActive ? colorScheme.primaryContainer : Colors.transparent,
          border: Border.all(
            color: isActive
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.4),
            width: isActive ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive && selectedLeading != null) ...[
              selectedLeading,
              const SizedBox(width: 6),
            ],
            Text(
              _truncate(isActive ? selectedDisplay! : label, 7),
              style: TextStyle(
                fontSize: 13,
                color: isActive
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface.withOpacity(0.75),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isActive
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectItem {
  final String value;
  final String label;
  final Widget? leading;
  const _SelectItem({required this.value, required this.label, this.leading});
}

class _RecordSelectItem extends StatelessWidget {
  final ClimbingRecord record;
  final VoidCallback onTap;

  const _RecordSelectItem({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = DifficultyColor.values.firstWhere(
      (c) => c.name == record.difficultyColor,
      orElse: () => DifficultyColor.white,
    );
    final isCompleted = record.status == 'completed';
    final dateStr = DateFormat('yyyy.MM.dd').format(record.recordedAt);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _buildThumbnail(color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.gymName ?? '암장 미지정',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? ReclimColors.success.withOpacity(0.1)
                              : const Color(0xFFFF6B35).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isCompleted ? '완등' : '도전중',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isCompleted
                                ? ReclimColors.success
                                : const Color(0xFFE65100),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Color(color.colorValue),
                          shape: BoxShape.circle,
                          border: (color == DifficultyColor.white ||
                                  color == DifficultyColor.yellow)
                              ? Border.all(
                                  color: Colors.black.withOpacity(0.15),
                                  width: 0.5)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        color.korean,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  if (record.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: record.tags
                            .map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest
                                        .withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colorScheme.onSurface
                                          .withOpacity(0.55),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              dateStr,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(DifficultyColor color) {
    final path = record.thumbnailPath;
    Widget thumbnail;
    if (path != null) {
      final isLocal = path.startsWith('/');
      final hasLocal = isLocal && File(path).existsSync();
      if (hasLocal) {
        thumbnail = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(path),
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _colorBadge(color),
          ),
        );
      } else if (!isLocal) {
        thumbnail = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FutureBuilder<String>(
            future: R2Config.getPresignedUrl(path),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return _colorBadge(color);
              return Image.network(
                snapshot.data!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _colorBadge(color),
              );
            },
          ),
        );
      } else {
        thumbnail = _colorBadge(color);
      }
    } else {
      thumbnail = _colorBadge(color);
    }

    final duration = record.videoDurationSeconds;
    if (duration == null) return thumbnail;

    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    final durationText = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          thumbnail,
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              padding: const EdgeInsets.only(bottom: 2, top: 6),
              alignment: Alignment.bottomCenter,
              child: Text(
                durationText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorBadge(DifficultyColor color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(color.colorValue),
            Color(color.colorValue).withOpacity(0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
