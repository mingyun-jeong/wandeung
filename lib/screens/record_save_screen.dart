import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:gal/gal.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import '../config/supabase_config.dart';
import '../models/climbing_gym.dart';
import '../models/climbing_record.dart';
import '../providers/camera_settings_provider.dart';
import '../providers/record_provider.dart';
import '../utils/constants.dart';
import '../widgets/difficulty_selector.dart';
import '../widgets/gym_selection_sheet.dart';
import '../widgets/gym_map_sheet.dart';
import '../widgets/tag_input.dart';
import '../widgets/wandeung_app_bar.dart';
import '../utils/thumbnail_utils.dart';
import 'records_tab_screen.dart';
import 'video_editor_screen.dart';

class RecordSaveScreen extends ConsumerStatefulWidget {
  final String? videoPath;
  final String? originalVideoPath;
  final ClimbingRecord? existingRecord;

  const RecordSaveScreen({
    super.key,
    this.videoPath,
    this.originalVideoPath,
    this.existingRecord,
  });

  @override
  ConsumerState<RecordSaveScreen> createState() => _RecordSaveScreenState();
}

class _RecordSaveScreenState extends ConsumerState<RecordSaveScreen> {
  VideoPlayerController? _videoController;
  double _displayAspectRatio = 16 / 9;
  ClimbingStatus _status = ClimbingStatus.completed;
  List<String> _tags = [];
  bool _isSaving = false;
  bool _videoFileMissing = false;

  // 편집 모드 전용 로컬 gym 상태 (카메라 탭의 자동 선택과 분리)
  ClimbingGym? _editGym;
  DifficultyColor? _editColor;
  ClimbingGrade? _editGrade;

  bool get _isEditMode => widget.existingRecord != null;

  @override
  void initState() {
    super.initState();

    if (_isEditMode) {
      final record = widget.existingRecord!;
      _status = record.status == 'completed'
          ? ClimbingStatus.completed
          : ClimbingStatus.inProgress;
      _tags = List<String>.from(record.tags);
      _editGrade = ClimbingGrade.values.firstWhere(
        (g) => g.name == record.grade,
        orElse: () => ClimbingGrade.v1,
      );
      _editColor = DifficultyColor.values.firstWhere(
        (c) => c.name == record.difficultyColor,
        orElse: () => DifficultyColor.white,
      );
      if (record.gymId != null) {
        _loadGymFromRecord(record.gymId!);
      }
    }

    _initVideo();
  }

  Future<void> _loadGymFromRecord(String gymId) async {
    try {
      final response = await SupabaseConfig.client
          .from('climbing_gyms')
          .select()
          .eq('id', gymId)
          .maybeSingle();
      if (response != null && mounted) {
        setState(() => _editGym = ClimbingGym.fromMap(response));
      }
    } catch (_) {}
  }

  Future<void> _initVideo() async {
    final path = _isEditMode
        ? widget.existingRecord!.videoPath
        : widget.videoPath;
    if (path == null) return;

    if (path.startsWith('/')) {
      if (!File(path).existsSync()) {
        if (mounted) setState(() => _videoFileMissing = true);
        return;
      }
      _videoController = VideoPlayerController.file(File(path));
    } else {
      final url = await SupabaseConfig.client.storage
          .from('climbing-videos')
          .createSignedUrl(path, 3600);
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    }

    try {
      await _videoController!.initialize().timeout(
        const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('영상 초기화 실패: $e');
      _videoController?.dispose();
      _videoController = null;
      if (mounted) setState(() {});
      return;
    }
    final size = _videoController!.value.size;
    final rotation = _videoController!.value.rotationCorrection;
    if (size.width > 0 &&
        size.height > 0 &&
        (rotation == 90 || rotation == 270)) {
      _displayAspectRatio = size.height / size.width;
    } else {
      _displayAspectRatio = _videoController!.value.aspectRatio;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _openVideoEditor() {
    final videoPath = widget.existingRecord!.videoPath;
    if (videoPath == null) return;

    if (!videoPath.startsWith('/') || !File(videoPath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로컬 영상 파일이 없어 편집할 수 없습니다')),
      );
      return;
    }

    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VideoEditorScreen(
          videoPath: videoPath,
          existingRecord: widget.existingRecord,
        ),
      ),
    ).then((exported) {
      if (exported == true && mounted) {
        ref.invalidate(exportedRecordsProvider(widget.existingRecord!.id!));
      }
    });
  }

  void _deleteVideo() {
    if (_isEditMode) {
      _deleteRecord();
      return;
    }
    File(widget.videoPath!).deleteSync();
    if (widget.originalVideoPath != null) {
      try {
        File(widget.originalVideoPath!).deleteSync();
      } catch (_) {}
    }
    Navigator.pop(context, false);
  }

  Future<void> _deleteRecord() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await RecordService.deleteRecord(widget.existingRecord!.id!);
      if (mounted) {
        final selectedDate = ref.read(selectedDateProvider);
        final focusedMonth = ref.read(focusedMonthProvider);
        ref.invalidate(recordsByDateProvider(selectedDate));
        ref.invalidate(recordCountsByDateProvider(focusedMonth));
        ref.invalidate(userStatsProvider);
        ref.invalidate(recentRecordsProvider);
        ref.invalidate(recentGymsProvider);
        ref.invalidate(userVisitedGymsProvider);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveRecord() async {
    final color = _isEditMode ? _editColor : ref.read(cameraSettingsProvider).color;
    final grade = _isEditMode ? _editGrade : ref.read(cameraSettingsProvider).grade;

    if (color == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('난이도 색상을 선택해주세요')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_isEditMode) {
        await RecordService.updateRecord(
          recordId: widget.existingRecord!.id!,
          grade: grade!.name,
          difficultyColor: color.name,
          status: _status == ClimbingStatus.completed
              ? 'completed'
              : 'in_progress',
          gym: _editGym,
          tags: _tags,
        );
      } else {
        final settings = ref.read(cameraSettingsProvider);
        await _saveToGallery();
        final thumbnailPath = await generateThumbnail(widget.videoPath!);
        final durationSeconds = await _getVideoDuration(widget.videoPath!);
        await RecordService.saveRecord(
          videoPath: widget.videoPath!,
          grade: settings.grade!.name,
          difficultyColor: settings.color!.name,
          status: _status == ClimbingStatus.completed
              ? 'completed'
              : 'in_progress',
          gym: settings.selectedGym,
          thumbnailPath: thumbnailPath,
          tags: _tags,
          videoDurationSeconds: durationSeconds,
        );
      }

      if (mounted) {
        final selectedDate = ref.read(selectedDateProvider);
        final focusedMonth = ref.read(focusedMonthProvider);
        ref.invalidate(recordsByDateProvider(selectedDate));
        ref.invalidate(recordCountsByDateProvider(focusedMonth));
        ref.invalidate(userStatsProvider);
        ref.invalidate(recentRecordsProvider);
        ref.invalidate(recentGymsProvider);
        ref.invalidate(userVisitedGymsProvider);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showGymSelection(BuildContext context, WidgetRef ref) {
    if (_isEditMode) {
      GymSelectionSheet.show(
        context,
        currentGym: _editGym,
        onGymSelected: (gym) {
          setState(() {
            _editGym = gym;
          });
        },
      );
    } else {
      final settings = ref.read(cameraSettingsProvider);
      GymSelectionSheet.show(
        context,
        currentGym: settings.selectedGym,
        onGymSelected: (gym) {
          ref.read(cameraSettingsProvider.notifier).setGym(gym);
        },
      );
    }
  }

  Future<void> _saveToGallery() async {
    try {
      await Gal.putVideo(widget.videoPath!, album: '완등');
    } catch (_) {}
  }

  Future<int?> _getVideoDuration(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final info = session.getMediaInformation();
      if (info != null) {
        final durationStr = info.getDuration();
        if (durationStr != null) {
          final durationMs = (double.parse(durationStr) * 1000).round();
          return (durationMs / 1000).round();
        }
      }
    } catch (e) {
      debugPrint('FFprobe duration 조회 실패: $e');
    }
    // fallback to VideoPlayerController
    if (_videoController?.value.isInitialized == true) {
      return _videoController!.value.duration.inSeconds;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(cameraSettingsProvider);

    // 편집 모드에서는 로컬 상태, 신규 저장에서는 cameraSettingsProvider 사용
    final displayGym = _isEditMode ? _editGym : settings.selectedGym;
    final displayColor = _isEditMode ? _editColor : settings.color;

    return Scaffold(
      appBar: WandeungAppBar(
        title: _isEditMode ? '기록 편집' : '기록 저장',
        showBackButton: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 영상 프리뷰 (원본)
                  if (_videoController != null &&
                      _videoController!.value.isInitialized)
                    Stack(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final maxHeight =
                                MediaQuery.of(context).size.height * 0.22;
                            final naturalHeight =
                                constraints.maxWidth / _displayAspectRatio;
                            final playerHeight =
                                naturalHeight > maxHeight ? maxHeight : naturalHeight;

                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: double.infinity,
                                height: playerHeight,
                                child: Container(
                                  color: Colors.black,
                                  alignment: Alignment.center,
                                  child: AspectRatio(
                                    aspectRatio: _displayAspectRatio,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        VideoPlayer(_videoController!),
                                        IconButton(
                                          icon: Icon(
                                            _videoController!.value.isPlaying
                                                ? Icons.pause_circle
                                                : Icons.play_circle,
                                            size: 48,
                                            color: Colors.white,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _videoController!.value.isPlaying
                                                  ? _videoController!.pause()
                                                  : _videoController!.play();
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        // 편집 버튼 (편집 모드에서만)
                        if (_isEditMode && widget.existingRecord!.videoPath != null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: _openVideoEditor,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.movie_edit,
                                          color: Colors.white, size: 16),
                                      SizedBox(width: 4),
                                      Text('편집',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  else if (_videoFileMissing)
                    Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8ECF0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam_off_rounded, size: 36,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.25)),
                            const SizedBox(height: 6),
                            Text('영상 파일을 찾을 수 없습니다.\n촬영 영상은 기기에만 저장되므로,\n파일 삭제·이동 또는 다른 기기에서\n로그인한 경우 재생할 수 없습니다.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
                          ],
                        ),
                      ),
                    )
                  else if (_videoController == null &&
                      _isEditMode &&
                      widget.existingRecord!.videoPath != null)
                    const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  const SizedBox(height: 16),

                  // 난이도 선택
                  DifficultySelector(
                    selectedColor: displayColor,
                    onColorChanged: (c) {
                      if (_isEditMode) {
                        setState(() => _editColor = c);
                      } else {
                        ref.read(cameraSettingsProvider.notifier).setColor(c);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  Text('암장',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface,
                      )),
                  const SizedBox(height: 8),
                  if (displayGym != null)
                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
                        border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _showGymSelection(context, ref),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayGym?.name ?? '',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                  if (displayGym?.address != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        displayGym!.address!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.45),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (displayGym?.latitude != null &&
                              displayGym?.longitude != null)
                            GestureDetector(
                              onTap: () => GymMapSheet.show(
                                context,
                                selectedGym: displayGym!,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Icon(Icons.map_outlined,
                                    size: 20,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.7)),
                              ),
                            ),
                          GestureDetector(
                            onTap: () {
                              if (_isEditMode) {
                                setState(() {
                                  _editGym = null;
                                });
                              } else {
                                ref.read(cameraSettingsProvider.notifier).clearGym();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(Icons.close_rounded,
                                  size: 18,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.35)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () => _showGymSelection(context, ref),
                      child: Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.add_location_alt_outlined,
                                size: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.35)),
                            const SizedBox(width: 10),
                            Text(
                              '암장을 선택해주세요',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  Text('완등 여부',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface,
                      )),
                  const SizedBox(height: 8),
                  Row(
                    children: ClimbingStatus.values.map((s) {
                      final isSelected = _status == s;
                      final isCompleted = s == ClimbingStatus.completed;
                      final activeColor = isCompleted
                          ? const Color(0xFF0D9488)
                          : const Color(0xFFFF6B35);
                      return Padding(
                        padding: EdgeInsets.only(right: isCompleted ? 8 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() => _status = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 9),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? activeColor.withOpacity(0.1)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isSelected
                                    ? activeColor.withOpacity(0.4)
                                    : const Color(0xFFE2E8F0),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isCompleted
                                      ? Icons.check_circle_rounded
                                      : Icons.sports_kabaddi_rounded,
                                  color: isSelected
                                      ? activeColor
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.3),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  s.label,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    fontSize: 13,
                                    color: isSelected
                                        ? activeColor
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 태그 입력
                  TagInput(
                    tags: _tags,
                    onTagsChanged: (tags) => setState(() => _tags = tags),
                  ),

                  // 내보내기 영상 목록 (편집 모드에서만)
                  if (_isEditMode && widget.existingRecord!.id != null) ...[
                    const SizedBox(height: 28),
                    _ExportedVideosList(
                        parentRecordId: widget.existingRecord!.id!),
                  ],
                ],
              ),
            ),
          ),
          // 하단 고정 버튼
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : _deleteVideo,
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFEF4444)),
                      label: const Text('삭제',
                          style: TextStyle(color: Color(0xFFEF4444))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveRecord,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(_isEditMode
                              ? Icons.check_rounded
                              : Icons.save_alt_rounded),
                      label: Text(_isEditMode ? '수정하기' : '저장하기',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
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

/// 내보내기 영상 목록 위젯
class _ExportedVideosList extends ConsumerWidget {
  final String parentRecordId;
  const _ExportedVideosList({required this.parentRecordId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exportsAsync = ref.watch(exportedRecordsProvider(parentRecordId));

    return exportsAsync.when(
      data: (exports) {
        if (exports.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.video_library_rounded,
                    size: 18,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5)),
                const SizedBox(width: 6),
                Text(
                  '내보내기 영상 (${exports.length})',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...exports.map((export) => _ExportedVideoCard(
                  record: export,
                  onDelete: () async {
                    await RecordService.deleteRecord(export.id!);
                    ref.invalidate(exportedRecordsProvider(parentRecordId));
                  },
                )),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// 내보내기 영상 카드
class _ExportedVideoCard extends StatelessWidget {
  final ClimbingRecord record;
  final VoidCallback onDelete;
  const _ExportedVideoCard({required this.record, required this.onDelete});

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hasThumbnail = record.thumbnailPath != null &&
        File(record.thumbnailPath!).existsSync();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (record.videoPath != null &&
              record.videoPath!.startsWith('/') &&
              File(record.videoPath!).existsSync()) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    _FullScreenVideoPlayer(videoPath: record.videoPath!),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // 썸네일
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 42,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      hasThumbnail
                          ? Image.file(
                              File(record.thumbnailPath!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFE2E8F0),
                                child: const Icon(Icons.movie_rounded,
                                    color: Colors.white, size: 20),
                              ),
                            )
                          : Container(
                              color: const Color(0xFFE2E8F0),
                              child: const Icon(Icons.movie_rounded,
                                  color: Colors.white, size: 20),
                            ),
                      if (record.videoDurationSeconds != null)
                        Positioned(
                          right: 3,
                          bottom: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 3, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '${record.videoDurationSeconds! ~/ 60}:${(record.videoDurationSeconds! % 60).toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '편집 영상',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(record.createdAt),
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.4)),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('삭제'),
                      content:
                          const Text('이 내보내기 영상을 삭제하시겠습니까?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('삭제',
                              style: TextStyle(color: Color(0xFFEF4444))),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) onDelete();
                },
                icon: Icon(Icons.delete_outline_rounded,
                    size: 20,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.3)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 전체화면 영상 플레이어
class _FullScreenVideoPlayer extends StatefulWidget {
  final String videoPath;
  const _FullScreenVideoPlayer({required this.videoPath});

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('편집 영상'),
      ),
      body: Center(
        child: _initialized
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  });
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                    if (!_controller.value.isPlaying)
                      const Icon(Icons.play_circle,
                          size: 64, color: Colors.white70),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
