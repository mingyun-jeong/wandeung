import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:gal/gal.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import '../config/r2_config.dart';
import '../config/supabase_config.dart';
import '../providers/upload_queue_provider.dart';
import '../services/video_upload_service.dart';
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
import '../utils/cache_cleanup.dart';
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
  ChewieController? _chewieController;
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
      final url = R2Config.getPresignedUrl(path);
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

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      aspectRatio: _displayAspectRatio,
      autoPlay: false,
      looping: false,
      allowFullScreen: true,
      allowedScreenSleep: false,
      deviceOrientationsOnEnterFullScreen: [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
      ],
      deviceOrientationsAfterFullScreen: [
        DeviceOrientation.portraitUp,
      ],
    );

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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

  Future<void> _deleteVideo() async {
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
    // 촬영 취소 시에도 캐시 정리
    await CacheCleanup.clearAppCache();
    if (mounted) Navigator.pop(context, false);
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

        // 캐시 → 영구 저장소로 이동 (저장 확정 시에만)
        final persistentPath = await _moveToPersistentStorage(widget.videoPath!);

        final thumbnailPath = await generateThumbnail(persistentPath);
        final durationSeconds = await _getVideoDuration(persistentPath);
        final savedRecord = await RecordService.saveRecord(
          videoPath: persistentPath,
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

        // 썸네일 즉시 R2 업로드 (작은 파일이므로 네트워크 종류 무관)
        if (thumbnailPath != null) {
          try {
            await VideoUploadService.uploadThumbnailAndUpdateRecord(
              recordId: savedRecord.id!,
              localThumbnailPath: thumbnailPath,
              userId: savedRecord.userId,
            );
          } catch (e) {
            debugPrint('썸네일 업로드 실패: $e');
          }
        }

        // 영상은 큐에 등록 (Wi-Fi 설정에 따라 처리)
        ref.read(uploadQueueProvider.notifier).enqueue(
          recordId: savedRecord.id!,
          localVideoPath: persistentPath,
        );
      }

      // 편집 원본 파일 정리 (편집 후 저장 시 원본은 더 이상 불필요)
      if (widget.originalVideoPath != null) {
        try {
          final originalFile = File(widget.originalVideoPath!);
          if (await originalFile.exists()) {
            await originalFile.delete();
          }
        } catch (_) {}
      }

      // 캐시 정리 (camera, FFmpeg, video_player 등이 남긴 임시 파일)
      await CacheCleanup.clearAppCache();

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

  /// 캐시의 영상 파일을 영구 저장소로 이동 (저장 확정 시에만 호출)
  Future<String> _moveToPersistentStorage(String cachePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final videosDir = Directory(p.join(appDir.path, 'videos'));
    if (!videosDir.existsSync()) {
      videosDir.createSync(recursive: true);
    }
    final persistentPath = p.join(videosDir.path, p.basename(cachePath));
    final sourceFile = File(cachePath);
    try {
      await sourceFile.rename(persistentPath);
    } catch (_) {
      await sourceFile.copy(persistentPath);
      await sourceFile.delete();
    }
    return persistentPath;
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
      // FFprobe 세션 캐시 즉시 정리
      await FFmpegKitConfig.clearSessions();
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
                  // 영상 플레이어
                  if (_chewieController != null)
                    Stack(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final maxHeight =
                                MediaQuery.of(context).size.height * 0.25;
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
                                    child: Chewie(controller: _chewieController!),
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
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.file(File(widget.videoPath));
    try {
      await _videoController!.initialize();
    } catch (e) {
      debugPrint('편집 영상 초기화 실패: $e');
      _videoController?.dispose();
      _videoController = null;
      if (mounted) setState(() => _initialized = true);
      return;
    }

    final size = _videoController!.value.size;
    final rotation = _videoController!.value.rotationCorrection;
    double aspectRatio;
    if (size.width > 0 && size.height > 0 && (rotation == 90 || rotation == 270)) {
      aspectRatio = size.height / size.width;
    } else {
      aspectRatio = _videoController!.value.aspectRatio;
    }

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      aspectRatio: aspectRatio,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowedScreenSleep: false,
      deviceOrientationsOnEnterFullScreen: [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
      ],
      deviceOrientationsAfterFullScreen: [
        DeviceOrientation.portraitUp,
      ],
    );

    if (mounted) setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
        child: _chewieController != null && _initialized
            ? Chewie(controller: _chewieController!)
            : _initialized
                ? const Text('영상을 재생할 수 없습니다',
                    style: TextStyle(color: Colors.white70))
                : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
