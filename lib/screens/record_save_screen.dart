import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:gal/gal.dart';
import '../config/supabase_config.dart';
import '../models/climbing_record.dart';
import '../providers/auth_provider.dart';
import '../providers/camera_settings_provider.dart';
import '../providers/record_provider.dart';
import '../utils/constants.dart';
import '../widgets/difficulty_selector.dart';
import '../widgets/gym_selector.dart';
import '../widgets/tag_input.dart';
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

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: _isEditMode
            ? const Text('기록 편집',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18))
            : null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: () {
              final user = ref.watch(authProvider).valueOrNull;
              final photoUrl = user?.userMetadata?['picture'] as String?;
              return CircleAvatar(
                radius: 16,
                backgroundImage:
                    photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? const Icon(Icons.person, size: 18)
                    : null,
              );
            }(),
          ),
        ],
      ),
      body: SingleChildScrollView(
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
              selectedColor: settings.color,
              onColorChanged: (c) =>
                  ref.read(cameraSettingsProvider.notifier).setColor(c),
            ),
            const SizedBox(height: 16),

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

            // 내보내기 영상 목록 (편집 모드에서만)
            if (_isEditMode && widget.existingRecord!.id != null) ...[
              const SizedBox(height: 28),
              _ExportedVideosList(
                  parentRecordId: widget.existingRecord!.id!),
            ],
          ],
        ),
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
                Icon(Icons.video_library,
                    size: 18, color: Colors.grey.shade600),
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
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
                  child: hasThumbnail
                      ? Image.file(
                          File(record.thumbnailPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.movie,
                                color: Colors.white, size: 20),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.movie,
                              color: Colors.white, size: 20),
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
                          fontSize: 12, color: Colors.grey.shade500),
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
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) onDelete();
                },
                icon: Icon(Icons.delete_outline,
                    size: 20, color: Colors.grey.shade400),
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
