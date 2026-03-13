import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/gym_color_scale.dart';
import '../providers/gym_color_scale_provider.dart';
import '../utils/constants.dart';
import '../widgets/wandeung_app_bar.dart';

class GymGradesTabScreen extends ConsumerStatefulWidget {
  const GymGradesTabScreen({super.key});

  @override
  ConsumerState<GymGradesTabScreen> createState() =>
      _GymGradesTabScreenState();
}

class _GymGradesTabScreenState extends ConsumerState<GymGradesTabScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scalesAsync = ref.watch(allColorScalesProvider);

    return Scaffold(
      appBar: WandeungAppBar(
        extraActions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '새로고침',
            onPressed: () => ref.invalidate(allColorScalesProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색바
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: '암장 브랜드 검색',
                hintStyle: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.4),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: colorScheme.onSurface.withOpacity(0.4),
                ),
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // 브랜드 색상표 목록
          Expanded(
            child: scalesAsync.when(
              data: (scales) {
                final filtered = _searchQuery.isEmpty
                    ? scales
                    : scales
                        .where((s) => s.brandName
                            .replaceAll(' ', '')
                            .contains(_searchQuery.replaceAll(' ', '')))
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '검색 결과가 없습니다',
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _BrandCard(scale: filtered[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '데이터를 불러오지 못했습니다',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(allColorScalesProvider),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandCard extends StatefulWidget {
  final GymColorScale scale;
  final bool initiallyExpanded;

  const _BrandCard({required this.scale, this.initiallyExpanded = false});

  @override
  State<_BrandCard> createState() => _BrandCardState();
}

class _BrandCardState extends State<_BrandCard>
    with SingleTickerProviderStateMixin {
  late bool _expanded = widget.initiallyExpanded;
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 250),
    vsync: this,
    value: _expanded ? 1.0 : 0.0,
  );
  late final Animation<double> _expandAnimation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );
  late final Animation<double> _rotationAnimation = Tween<double>(
    begin: 0.0,
    end: 0.5,
  ).animate(_expandAnimation);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scale = widget.scale;

    // 색상 미리보기 (접혀있을 때 표시)
    final previewColors = scale.levels.map((l) => l.color).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _expanded ? colorScheme.primary.withOpacity(0.3) : const Color(0xFFE8ECF0),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 헤더 (항상 보임, 탭하면 토글)
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 첫 번째 줄: 브랜드명 + 단계 + 화살표
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          scale.brandName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${scale.levels.length}단계',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      RotationTransition(
                        turns: _rotationAnimation,
                        child: Icon(
                          Icons.expand_more_rounded,
                          size: 22,
                          color: colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                  // 두 번째 줄: 접혀있을 때 색상 미리보기
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: _expanded
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(left: 28, top: 8),
                            child: Wrap(
                              spacing: 5,
                              runSpacing: 5,
                              children: previewColors.map((dc) {
                                if (dc == DifficultyColor.star) {
                                  return const Icon(Icons.star_rounded,
                                      color: Color(0xFFFFD700), size: 18);
                                }
                                return Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: dc == DifficultyColor.rainbow
                                        ? null
                                        : Color(dc.colorValue),
                                    gradient: dc == DifficultyColor.rainbow
                                        ? const LinearGradient(colors: [
                                            Colors.red, Colors.orange,
                                            Colors.yellow, Colors.green,
                                            Colors.blue, Colors.purple,
                                          ])
                                        : null,
                                    shape: BoxShape.circle,
                                    border: dc.needsDarkIcon
                                        ? Border.all(
                                            color: const Color(0xFFE0E0E0),
                                            width: 0.5)
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          // 난이도 레벨 목록 (펼쳐질 때만)
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  ...scale.levels
                      .map((level) => _ColorLevelRow(level: level)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorLevelRow extends StatelessWidget {
  final ColorLevel level;

  const _ColorLevelRow({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = Color(level.color.colorValue);
    final isLight = level.color.needsDarkIcon;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          // 색상 원
          if (level.color == DifficultyColor.star)
            const SizedBox(
              width: 28,
              height: 28,
              child: Center(
                child: Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 26),
              ),
            )
          else
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: level.color == DifficultyColor.rainbow
                    ? null
                    : color,
                gradient: level.color == DifficultyColor.rainbow
                    ? const LinearGradient(
                        colors: [
                          Colors.red,
                          Colors.orange,
                          Colors.yellow,
                          Colors.green,
                          Colors.blue,
                          Colors.purple,
                        ],
                      )
                    : null,
                shape: BoxShape.circle,
                border: isLight
                    ? Border.all(color: const Color(0xFFE0E0E0))
                    : null,
              ),
            ),
          const SizedBox(width: 12),
          // 색상 이름
          SizedBox(
            width: 40,
            child: Text(
              level.color.korean,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // V-grade 범위
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              level.vRangeLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isLight
                    ? Colors.black87
                    : Color(level.color.colorValue),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
