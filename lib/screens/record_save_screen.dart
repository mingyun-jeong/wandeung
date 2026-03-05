import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:gal/gal.dart';
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
  final String videoPath;
  /// 편집된 영상인 경우 원본 파일 경로 (삭제 시 함께 정리)
  final String? originalVideoPath;
  const RecordSaveScreen({
    super.key,
    required this.videoPath,
    this.originalVideoPath,
  });

  @override
  ConsumerState<RecordSaveScreen> createState() => _RecordSaveScreenState();
}

class _RecordSaveScreenState extends ConsumerState<RecordSaveScreen> {
  late VideoPlayerController _videoController;
  double _displayAspectRatio = 16 / 9;
  ClimbingStatus _status = ClimbingStatus.completed;
  List<String> _tags = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        final size = _videoController.value.size;
        final rotation = _videoController.value.rotationCorrection;
        if (size.width > 0 && size.height > 0 && (rotation == 90 || rotation == 270)) {
          _displayAspectRatio = size.height / size.width;
        } else {
          _displayAspectRatio = _videoController.value.aspectRatio;
        }
        setState(() {});
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  void _deleteVideo() {
    File(widget.videoPath).deleteSync();
    // 편집본인 경우 원본 파일도 정리
    if (widget.originalVideoPath != null) {
      try {
        File(widget.originalVideoPath!).deleteSync();
      } catch (_) {}
    }
    Navigator.pop(context, false);
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
      // 갤러리에 저장
      await _saveToGallery();

      // 썸네일 생성 (실패해도 기록 저장은 계속)
      final thumbnailPath = await generateThumbnail(widget.videoPath);

      await RecordService.saveRecord(
        videoPath: widget.videoPath,
        grade: settings.grade!.name,
        difficultyColor: settings.color!.name,
        status:
            _status == ClimbingStatus.completed ? 'completed' : 'in_progress',
        gymId: settings.selectedGym?.id,
        gymName: settings.selectedGym?.name ?? settings.manualGymName,
        thumbnailPath: thumbnailPath,
        tags: _tags,
      );

      if (mounted) {
        // 기록 새로고침
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
      await Gal.putVideo(widget.videoPath, album: '완등');
    } catch (_) {
      // 갤러리 저장 실패해도 앱 내 기록은 유지
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(cameraSettingsProvider);
    final hasColor = settings.color != null;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
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
            if (_videoController.value.isInitialized)
              AspectRatio(
                aspectRatio: _displayAspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_videoController),
                    IconButton(
                      icon: Icon(
                        _videoController.value.isPlaying
                            ? Icons.pause_circle
                            : Icons.play_circle,
                        size: 48,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _videoController.value.isPlaying
                              ? _videoController.pause()
                              : _videoController.play();
                        });
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // 난이도 선택 (카메라에서 미선택 시 fallback)
            if (!hasColor) ...[
              DifficultySelector(
                selectedColor: settings.color,
                onColorChanged: (c) =>
                    ref.read(cameraSettingsProvider.notifier).setColor(c),
              ),
              const SizedBox(height: 24),
            ],

            // 암장
            const Text('암장',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            if (settings.selectedGym != null || settings.manualGymName != null)
              // 카메라에서 선택한 암장 표시
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 18, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      settings.selectedGym?.name ??
                          settings.manualGymName ??
                          '',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              )
            else
              // 암장 미선택 시 선택 가능
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
            const SizedBox(height: 24),

            // 완등 여부
            const Text('완등 여부',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            SegmentedButton<ClimbingStatus>(
              segments: ClimbingStatus.values
                  .map((s) => ButtonSegment(
                        value: s,
                        label: Text(s.label),
                        icon: s == ClimbingStatus.completed
                            ? const Icon(Icons.check_circle_outline)
                            : const Icon(Icons.sports_kabaddi),
                      ))
                  .toList(),
              selected: {_status},
              onSelectionChanged: (s) => setState(() => _status = s.first),
            ),
            const SizedBox(height: 24),

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
            const SizedBox(height: 32),

            // 하단 버튼: 삭제 + 저장하기
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    onPressed: _deleteVideo,
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
                        : const Icon(Icons.save_alt),
                    label: const Text('저장하기',
                        style: TextStyle(fontSize: 16)),
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
