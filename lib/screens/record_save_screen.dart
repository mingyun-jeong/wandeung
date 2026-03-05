import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:gal/gal.dart';
import '../config/supabase_config.dart';
import '../models/climbing_record.dart';
import '../providers/camera_settings_provider.dart';
import '../providers/record_provider.dart';
import '../utils/constants.dart';
import '../widgets/difficulty_selector.dart';
import '../widgets/gym_selector.dart';
import '../widgets/tag_input.dart';
import '../widgets/recommended_tags.dart';
import '../utils/thumbnail_utils.dart';
import 'records_tab_screen.dart';

class RecordSaveScreen extends ConsumerStatefulWidget {
  final String? videoPath;
  /// 편집된 영상인 경우 원본 파일 경로 (삭제 시 함께 정리)
  final String? originalVideoPath;
  /// 기존 기록 편집 모드
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

      // 편집 모드: cameraSettings에 기존 기록 값 세팅
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier = ref.read(cameraSettingsProvider.notifier);
        final grade = ClimbingGrade.values.firstWhere(
          (g) => g.name == record.grade,
          orElse: () => ClimbingGrade.v1,
        );
        final color = DifficultyColor.values.firstWhere(
          (c) => c.name == record.difficultyColor,
          orElse: () => DifficultyColor.white,
        );
        notifier.setGrade(grade);
        notifier.setColor(color);
        if (record.gymName != null) {
          notifier.setManualGymName(record.gymName!);
        }
      });
    }

    _initVideo();
  }

  Future<void> _initVideo() async {
    final path = _isEditMode
        ? widget.existingRecord!.videoPath
        : widget.videoPath;
    if (path == null) return;

    if (path.startsWith('/')) {
      if (!File(path).existsSync()) return;
      _videoController = VideoPlayerController.file(File(path));
    } else {
      // Supabase Storage 경로
      final url = await SupabaseConfig.client.storage
          .from('climbing-videos')
          .createSignedUrl(path, 3600);
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    }

    await _videoController!.initialize();
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
    final settings = ref.read(cameraSettingsProvider);

    if (settings.color == null) {
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
          grade: settings.grade!.name,
          difficultyColor: settings.color!.name,
          status: _status == ClimbingStatus.completed
              ? 'completed'
              : 'in_progress',
          gymId: settings.selectedGym?.id,
          gymName: settings.selectedGym?.name ?? settings.manualGymName,
          tags: _tags,
        );
      } else {
        await _saveToGallery();
        final thumbnailPath = await generateThumbnail(widget.videoPath!);
        await RecordService.saveRecord(
          videoPath: widget.videoPath!,
          grade: settings.grade!.name,
          difficultyColor: settings.color!.name,
          status: _status == ClimbingStatus.completed
              ? 'completed'
              : 'in_progress',
          gymId: settings.selectedGym?.id,
          gymName: settings.selectedGym?.name ?? settings.manualGymName,
          thumbnailPath: thumbnailPath,
          tags: _tags,
        );
      }

      if (mounted) {
        final selectedDate = ref.read(selectedDateProvider);
        final focusedMonth = ref.read(focusedMonthProvider);
        ref.invalidate(recordsByDateProvider(selectedDate));
        ref.invalidate(recordCountsByDateProvider(focusedMonth));
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

  Future<void> _saveToGallery() async {
    try {
      await Gal.putVideo(widget.videoPath!, album: '완등');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(cameraSettingsProvider);
    final hasColor = settings.color != null;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: _isEditMode
            ? const Text('기록 편집',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18))
            : null,
        actions: [
          if (hasColor)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Color(settings.color!.colorValue),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 영상 프리뷰
            if (_videoController != null &&
                _videoController!.value.isInitialized)
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
            if (!hasColor) ...[
              DifficultySelector(
                selectedColor: settings.color,
                onColorChanged: (c) =>
                    ref.read(cameraSettingsProvider.notifier).setColor(c),
              ),
              const SizedBox(height: 16),
            ],

            // 암장
            const Text('암장',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            if (settings.selectedGym != null || settings.manualGymName != null)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 18, color: Colors.green.shade600),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        settings.selectedGym?.name ??
                            settings.manualGymName ??
                            '',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => ref
                          .read(cameraSettingsProvider.notifier)
                          .clearGym(),
                      child: Icon(Icons.close,
                          size: 18, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              )
            else
              GymSelector(
                selectedGym: null,
                manualGymName: null,
                onGymSelected: (gym) {
                  if (gym != null) {
                    ref.read(cameraSettingsProvider.notifier).setGym(gym);
                  }
                },
                onManualInput: (name) => ref
                    .read(cameraSettingsProvider.notifier)
                    .setManualGymName(name),
              ),
            const SizedBox(height: 16),

            // 완등 여부
            const Text('완등 여부',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Row(
              children: ClimbingStatus.values.map((s) {
                final isSelected = _status == s;
                final isCompleted = s == ClimbingStatus.completed;
                return Padding(
                  padding: EdgeInsets.only(right: isCompleted ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _status = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isCompleted
                                ? const Color(0xFFEAF5EC)
                                : const Color(0xFFFFF3E0))
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? (isCompleted
                                  ? const Color(0xFFA5D6A7)
                                  : const Color(0xFFFFCC80))
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCompleted
                                ? Icons.check_circle
                                : Icons.sports_kabaddi,
                            color: isSelected
                                ? (isCompleted
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFE65100))
                                : Colors.grey.shade400,
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
                                  ? (isCompleted
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFE65100))
                                  : Colors.grey.shade500,
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
            const SizedBox(height: 8),

            // 추천 태그
            RecommendedTags(
              currentTags: _tags,
              onTagsChanged: (tags) => setState(() => _tags = tags),
            ),
            const SizedBox(height: 24),

            // 하단 버튼
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _deleteVideo,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label:
                        const Text('삭제', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
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
                        : Icon(_isEditMode ? Icons.check : Icons.save_alt),
                    label: Text(_isEditMode ? '수정하기' : '저장하기',
                        style: const TextStyle(fontSize: 16)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
