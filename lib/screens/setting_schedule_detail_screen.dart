import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../app.dart';
import '../models/gym_setting_schedule.dart';
import '../utils/constants.dart';
import '../widgets/banner_ad_widget.dart';

class SettingScheduleDetailScreen extends StatelessWidget {
  final GymSettingSchedule schedule;
  final String? selectedDate; // "YYYY-MM-DD" — 진입 시 선택된 날짜

  const SettingScheduleDetailScreen({
    super.key,
    required this.schedule,
    this.selectedDate,
  });

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  String _formatDateWithDay(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    final dt = DateTime(y, m, d);
    final day = _weekdays[dt.weekday - 1];
    return '$m/$d($day)';
  }

  bool _isPastDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return false;
    final dt = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final today = DateTime.now();
    return dt.isBefore(DateTime(today.year, today.month, today.day));
  }

  @override
  Widget build(BuildContext context) {
    final ym = schedule.yearMonth.split('-');
    final yearMonthLabel =
        ym.length == 2 ? '${ym[0]}년 ${int.parse(ym[1])}월' : schedule.yearMonth;
    final hasImage = schedule.sourceImageUrl != null &&
        schedule.sourceImageUrl!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          schedule.gymName ?? '세팅일정',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // ─── 헤더 카드: 암장 정보 ───
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ReclimColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ReclimColors.accent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on,
                        size: 20, color: ReclimColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schedule.gymName ?? '',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: ReclimColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$yearMonthLabel 세팅일정',
                          style: const TextStyle(
                            fontSize: 13,
                            color: ReclimColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 섹터 개수 뱃지
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${schedule.sectors.length}개 섹터',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ReclimColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── 원본 이미지 (있을 때만) ───
            if (hasImage) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => _showFullImage(context, schedule.sourceImageUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: schedule.sourceImageUrl!,
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                      placeholder: (_, __) => Container(
                        height: 200,
                        color: const Color(0xFFF0F0F0),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ReclimColors.accent,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 120,
                        color: const Color(0xFFF0F0F0),
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined,
                              size: 32, color: ReclimColors.textTertiary),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 20),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '탭하여 확대',
                    style: TextStyle(
                      fontSize: 11,
                      color: ReclimColors.textTertiary.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
            ],

            // ─── 섹터별 세팅일정 ───
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                '섹터별 세팅일정',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ReclimColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),

            ...schedule.sectors.map((sector) => _SectorCard(
                  sector: sector,
                  selectedDate: selectedDate,
                  formatDate: _formatDateWithDay,
                  isPastDate: _isPastDate,
                )),

            const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          const SafeArea(
            top: false,
            child: BannerAdWidget(),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullImageScreen(imageUrl: imageUrl),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 섹터 카드 — 좌측 컬러 바 + 날짜 칩 (요일 포함)
// ═════════════════════════════════════════════════════════════════════════════

class _SectorCard extends StatelessWidget {
  final SettingSector sector;
  final String? selectedDate;
  final String Function(String) formatDate;
  final bool Function(String) isPastDate;

  const _SectorCard({
    required this.sector,
    this.selectedDate,
    required this.formatDate,
    required this.isPastDate,
  });

  @override
  Widget build(BuildContext context) {
    Color sectorColor = ReclimColors.accent;
    String? colorLabel;
    if (sector.color != null) {
      final dc = DifficultyColor.values
          .where((c) => c.name == sector.color)
          .firstOrNull;
      if (dc != null) {
        sectorColor = Color(dc.colorValue);
        colorLabel = dc.korean;
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ReclimColors.border),
      ),
      child: Row(
        children: [
          // 좌측 컬러 바
          Container(
            width: 5,
            height: 80,
            decoration: BoxDecoration(
              color: sectorColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          // 콘텐츠
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 섹터명 + 색상 라벨
                  Row(
                    children: [
                      Text(
                        sector.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ReclimColors.textPrimary,
                        ),
                      ),
                      if (colorLabel != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: sectorColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            colorLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: sectorColor == const Color(0xFFFFFFFF) ||
                                      sectorColor == const Color(0xFFFFEB3B) ||
                                      sectorColor == const Color(0xFFFFD700)
                                  ? ReclimColors.textSecondary
                                  : sectorColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // 세팅 시간
                  if (sector.timeRangeLabel != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule,
                            size: 14, color: ReclimColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          sector.timeRangeLabel!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ReclimColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  // 날짜 칩 (요일 포함, 지난 날짜 흐리게)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: sector.dates.map((dateStr) {
                      final isSelected = dateStr == selectedDate;
                      final isPast = isPastDate(dateStr);
                      final label = formatDate(dateStr);

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? sectorColor.withOpacity(0.12)
                              : const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: sectorColor, width: 1.5)
                              : null,
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? (sectorColor == const Color(0xFFFFFFFF) ||
                                        sectorColor ==
                                            const Color(0xFFFFEB3B) ||
                                        sectorColor == const Color(0xFFFFD700)
                                    ? ReclimColors.textPrimary
                                    : sectorColor)
                                : isPast
                                    ? ReclimColors.textTertiary
                                    : ReclimColors.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 이미지 전체화면 뷰어
// ═════════════════════════════════════════════════════════════════════════════

class _FullImageScreen extends StatelessWidget {
  final String imageUrl;
  const _FullImageScreen({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            errorWidget: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image_outlined,
                  size: 48, color: Colors.white54),
            ),
          ),
        ),
      ),
    );
  }
}
