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
import '../models/user_subscription.dart';
// import '../providers/app_config_provider.dart'; // 오픈 프로모션: 비활성화
// import '../providers/bonus_save_provider.dart'; // 오픈 프로모션: 비활성화
import '../providers/subscription_provider.dart';
import '../providers/upload_queue_provider.dart';
import '../services/video_upload_service.dart';
import '../models/climbing_gym.dart';
import '../models/climbing_record.dart';
import '../providers/camera_settings_provider.dart';
import '../providers/favorite_gym_provider.dart';
import '../providers/gallery_save_path_provider.dart';
import '../providers/record_provider.dart';
import '../utils/constants.dart';
import '../models/gym_color_scale.dart';
import '../providers/gym_color_scale_provider.dart';
import '../widgets/difficulty_selector.dart';
import '../widgets/gym_selection_sheet.dart';
import '../widgets/gym_map_sheet.dart';
import '../widgets/tag_input.dart';
import '../widgets/reclim_app_bar.dart';
import '../utils/cache_cleanup.dart';
import '../utils/video_download_cache.dart';
import '../utils/thumbnail_utils.dart';
import 'records_tab_screen.dart';
import 'video_compare_screen.dart';
import 'video_editor_screen.dart';
import '../widgets/record_select_bottom_sheet.dart';
import '../app.dart';

class RecordSaveScreen extends ConsumerStatefulWidget {
  final String? videoPath;
  final String? originalVideoPath;
  final ClimbingRecord? existingRecord;
  final String? videoQuality;

  const RecordSaveScreen({
    super.key,
    this.videoPath,
    this.originalVideoPath,
    this.existingRecord,
    this.videoQuality,
  });

  @override
  ConsumerState<RecordSaveScreen> createState() => _RecordSaveScreenState();
}

class _RecordSaveScreenState extends ConsumerState<RecordSaveScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  double _displayAspectRatio = 9 / 16;
  ClimbingStatus _status = ClimbingStatus.inProgress;
  List<String> _tags = [];
  bool _isSaving = false;
  bool _videoFileMissing = false;
  bool _savingToGallery = false;

  // 편집 모드 전용 로컬 gym 상태 (카메라 탭의 자동 선택과 분리)
  ClimbingGym? _editGym;
  DifficultyColor? _editColor;
  ClimbingGrade? _editGrade;

  bool get _isEditMode => widget.existingRecord != null;
  bool get _hasVideo =>
      widget.videoPath != null ||
      (_isEditMode && widget.existingRecord!.videoPath != null);
  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}.${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
  }

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
    } else {
      // 태그 유지 옵션이 켜져있으면 이전 태그를 초기값으로 사용
      final settings = ref.read(cameraSettingsProvider);
      if (settings.persistTags) {
        _tags = List<String>.from(settings.tags);
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
      final url = await R2Config.getPresignedUrl(path);
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

  Future<void> _openVideoEditor() async {
    final videoPath = widget.existingRecord!.videoPath;
    if (videoPath == null) return;

    String localPath;
    if (videoPath.startsWith('/')) {
      if (!File(videoPath).existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로컬 영상 파일이 없어 편집할 수 없습니다'), backgroundColor: Color(0xFFEF4444)),
        );
        return;
      }
      localPath = videoPath;
    } else {
      final downloaded = await downloadRemoteVideoWithDialog(context, videoPath);
      if (downloaded == null) return;
      localPath = downloaded;
    }

    if (!mounted) return;
    final exported = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VideoEditorScreen(
          videoPath: localPath,
          existingRecord: widget.existingRecord,
        ),
      ),
    );
    if (exported == true && mounted) {
      ref.invalidate(exportedRecordsProvider(widget.existingRecord!.id!));
    }
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
          SnackBar(content: Text('삭제 실패: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


  // bool _skipQuotaCheck = false; // 오픈 프로모션: 비활성화

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
          scales: ref.read(allColorScalesProvider).valueOrNull,
        );
      } else {
        final settings = ref.read(cameraSettingsProvider);
        final storageMode = await ref.read(storageModeProvider.notifier).getValue();
        final isCloudMode = storageMode == StorageMode.cloud;
        final tier = ref.read(subscriptionTierProvider);
        final isPro = tier == SubscriptionTier.pro;

        // 오픈 프로모션: 용량 제한 비활성화 (무제한)
        // Free 티어 클라우드 용량 체크
        // if (isCloudMode && !isPro && !_skipQuotaCheck) {
        //   final storageLimit = await ref.read(freeStorageLimitBytesProvider.future);
        //   final fileSize = await File(widget.videoPath!).length();
        //   final userId = SupabaseConfig.client.auth.currentUser!.id;
        //   final currentUsage = await VideoUploadService.getCloudUsage(userId);
        //   debugPrint('[QuotaCheck] usage=${currentUsage ~/ 1024 ~/ 1024}MB + file=${fileSize ~/ 1024 ~/ 1024}MB / limit=${storageLimit ~/ 1024 ~/ 1024}MB');
        //   if (currentUsage + fileSize > storageLimit) {
        //     final bonusNotifier = ref.read(bonusSaveProvider.notifier);
        //     if (bonusNotifier.hasBonus) {
        //       await bonusNotifier.consume();
        //     } else {
        //       if (mounted) {
        //         setState(() => _isSaving = false);
        //         _showStorageFullSheet(currentUsage, storageLimit);
        //       }
        //       return;
        //     }
        //   }
        // }
        // _skipQuotaCheck = false;

        // 캐시 → 영구 저장소로 이동 (rename은 거의 즉시)
        final persistentPath = await _moveToPersistentStorage(widget.videoPath!);

        // DB insert (썸네일·길이·화질은 백그라운드에서 패치)
        final savedRecord = await RecordService.saveRecord(
          videoPath: persistentPath,
          grade: settings.grade!.name,
          difficultyColor: settings.color!.name,
          status: _status == ClimbingStatus.completed
              ? 'completed'
              : 'in_progress',
          gym: settings.selectedGym,
          tags: _tags,
          scales: ref.read(allColorScalesProvider).valueOrNull,
          localOnly: !isCloudMode,
          // file_size_bytes는 업로드 완료 후 실제 압축 크기로 기록됨
          // INSERT 시점에 원본 크기를 기록하면 다른 기기에서 부풀려진 용량이 보이는 문제가 있음
          fileSizeBytes: null,
        );

        // 백그라운드 작업에 필요한 값을 pop 전에 캡처
        final capturedVideoPath = persistentPath;
        final capturedVideoQuality = widget.videoQuality;
        final capturedRecordId = savedRecord.id!;
        final capturedUserId = savedRecord.userId;
        final capturedIsCloudMode = isCloudMode;
        final capturedIsPro = isPro;
        final capturedOriginalVideoPath = widget.originalVideoPath;
        final capturedGym = settings.selectedGym;
        final capturedScales = ref.read(allColorScalesProvider).valueOrNull;
        final uploadQueueNotifier = ref.read(uploadQueueProvider.notifier);
        final galleryAlbum = resolveGalleryAlbum(
          ref.read(gallerySavePathProvider),
          gymName: capturedGym?.name,
        );

        // 무거운 작업은 백그라운드에서 (pop 이후에도 계속 실행)
        _runPostSaveWork(
          videoPath: capturedVideoPath,
          videoQualityHint: capturedVideoQuality,
          recordId: capturedRecordId,
          userId: capturedUserId,
          isCloudMode: capturedIsCloudMode,
          isPro: capturedIsPro,
          originalVideoPath: capturedOriginalVideoPath,
          gym: capturedGym,
          scales: capturedScales,
          uploadQueueNotifier: uploadQueueNotifier,
          galleryAlbum: galleryAlbum,
        );
      }

      // 편집 모드: 원본 파일 정리
      if (_isEditMode && widget.originalVideoPath != null) {
        try {
          final originalFile = File(widget.originalVideoPath!);
          if (await originalFile.exists()) {
            await originalFile.delete();
          }
        } catch (_) {}
      }

      // 암장이 있으면 자동으로 내 암장(즐겨찾기)에 등록
      final autoFavoriteGym = _isEditMode ? _editGym : ref.read(cameraSettingsProvider).selectedGym;
      if (autoFavoriteGym != null) {
        try {
          final scales = ref.read(allColorScalesProvider).valueOrNull;
          final gymId = await RecordService.findOrCreateGym(autoFavoriteGym, scales: scales);
          await FavoriteGymService.addFavorite(gymId);
        } catch (_) {}
      }

      // 태그 유지 옵션이 켜져있으면 다음 촬영을 위해 태그 저장
      if (!_isEditMode && ref.read(cameraSettingsProvider).persistTags) {
        ref.read(cameraSettingsProvider.notifier).setTags(_tags);
      }

      if (mounted) {
        _invalidateAndPop();
      }
    } on PathAccessException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('저장 경로에 접근할 수 없습니다. 저장소 권한을 확인해주세요.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      debugPrint('PathAccessException: $e');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // 오픈 프로모션: 용량 초과 팝업 비활성화
  // void _showStorageFullSheet(int currentUsage, int storageLimit) { ... }

  void _invalidateAndPop() {
    final selectedDate = ref.read(selectedDateProvider);
    final focusedMonth = ref.read(focusedMonthProvider);
    ref.invalidate(recordsByDateProvider(selectedDate));
    ref.invalidate(recordCountsByDateProvider(focusedMonth));
    ref.invalidate(userStatsProvider);
    ref.invalidate(recentRecordsProvider);
    ref.invalidate(recentGymsProvider);
    ref.invalidate(userVisitedGymsProvider);
    ref.invalidate(favoriteGymsProvider);
    Navigator.pop(context, true);
  }

  /// 저장 후 무거운 작업을 백그라운드에서 실행 (화면 pop 이후에도 계속)
  static Future<void> _runPostSaveWork({
    required String videoPath,
    required String? videoQualityHint,
    required String recordId,
    required String userId,
    required bool isCloudMode,
    required bool isPro,
    required String? originalVideoPath,
    required ClimbingGym? gym,
    required List<GymColorScale>? scales,
    required UploadQueueNotifier uploadQueueNotifier,
    required String galleryAlbum,
  }) async {
    try {
      // 1) 편집 원본 파일 정리
      if (originalVideoPath != null) {
        try {
          final originalFile = File(originalVideoPath);
          if (await originalFile.exists()) await originalFile.delete();
        } catch (_) {}
      }

      // 2) 로컬 모드: 갤러리 저장
      if (!isCloudMode) {
        try {
          await Gal.putVideo(videoPath, album: galleryAlbum);
        } catch (_) {}
      }

      // 3) 썸네일 생성
      final thumbnailPath = await generateThumbnail(videoPath);

      // 4) FFprobe 1회로 duration + quality 동시 조회
      int? durationSeconds;
      String? videoQuality = videoQualityHint;
      try {
        final session = await FFprobeKit.getMediaInformation(videoPath);
        final info = session.getMediaInformation();
        await FFmpegKitConfig.clearSessions();
        if (info != null) {
          final durationStr = info.getDuration();
          if (durationStr != null) {
            durationSeconds = (double.parse(durationStr)).round();
          }
          if (videoQuality == null) {
            for (final stream in info.getStreams()) {
              final height = stream.getHeight();
              if (height != null && height > 0) {
                videoQuality = _qualityLabelFromHeight(height);
                break;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('FFprobe 조회 실패: $e');
      }

      // 5) DB 패치 (썸네일·길이·화질)
      await RecordService.patchMediaInfo(
        recordId: recordId,
        thumbnailPath: thumbnailPath,
        videoDurationSeconds: durationSeconds,
        videoQuality: videoQuality,
      );

      // 6) 클라우드 모드: 썸네일 R2 업로드 + 압축 + 업로드 큐 등록
      if (isCloudMode) {
        if (thumbnailPath != null) {
          try {
            await VideoUploadService.uploadThumbnailAndUpdateRecord(
              recordId: recordId,
              localThumbnailPath: thumbnailPath,
              userId: userId,
            );
          } catch (e) {
            debugPrint('썸네일 업로드 실패: $e');
          }
        }

        // 압축은 processQueue에서 일괄 수행 (이중 압축 방지)
        uploadQueueNotifier.enqueue(
          recordId: recordId,
          localVideoPath: videoPath,
        );
      }

      // 7) 캐시 정리
      await CacheCleanup.clearAppCache();
    } catch (e) {
      debugPrint('백그라운드 후처리 실패: $e');
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

  Future<void> _downloadToGallery() async {
    if (_savingToGallery) return;
    setState(() => _savingToGallery = true);

    try {
      final record = widget.existingRecord!;
      final videoPath = record.videoPath!;
      String localPath;

      if (record.isLocalVideo) {
        if (!File(videoPath).existsSync()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('영상 파일을 찾을 수 없습니다'), backgroundColor: Color(0xFFEF4444)),
            );
          }
          return;
        }
        localPath = videoPath;
      } else {
        final downloaded =
            await downloadRemoteVideoWithDialog(context, videoPath);
        if (downloaded == null) return;
        localPath = downloaded;
      }

      final album = resolveGalleryAlbum(
        ref.read(gallerySavePathProvider),
        gymName: record.gymName,
      );
      await Gal.putVideo(localPath, album: album);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('갤러리에 저장되었습니다'),
            backgroundColor: Color(0xFF2196F3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('저장에 실패했습니다'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingToGallery = false);
    }
  }

  /// 영상 높이로부터 화질 라벨 추출 (720p, 1080p, 4K 등)
  static String _qualityLabelFromHeight(int height) {
    if (height >= 2160) return '4K';
    if (height >= 1080) return '1080p';
    if (height >= 720) return '720p';
    if (height >= 480) return '480p';
    return '${height}p';
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(cameraSettingsProvider);

    // 편집 모드에서는 로컬 상태, 신규 저장에서는 cameraSettingsProvider 사용
    final displayGym = _isEditMode ? _editGym : settings.selectedGym;
    final displayColor = _isEditMode ? _editColor : settings.color;

    // 암장 이름으로 브랜드 색상표 조회
    final GymColorScale? colorScale = displayGym != null
        ? ref.watch(gymColorScaleProvider(displayGym.name))
        : null;

    return Scaffold(
      appBar: ReclimAppBar(
        title: _isEditMode ? '기록 편집' : '기록 저장',
        showBackButton: true,
        extraActions: [
          if (_isEditMode && _hasVideo)
            TextButton.icon(
              onPressed: () async {
                final selectedRecord = await showRecordSelectBottomSheet(
                  context,
                  excludeRecordId: widget.existingRecord!.id,
                );
                if (selectedRecord == null || !context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoCompareScreen(
                      record1: widget.existingRecord!,
                      record2: selectedRecord,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.compare_arrows, size: 18),
              label: const Text('비교모드', style: TextStyle(fontSize: 13)),
            ),
          if (_isEditMode && _hasVideo && !(widget.existingRecord?.localOnly ?? false))
            IconButton(
              onPressed: _savingToGallery
                  ? null
                  : () => _downloadToGallery(),
              icon: Icon(
                _savingToGallery
                    ? Icons.hourglass_top_rounded
                    : Icons.download_rounded,
              ),
              tooltip: '갤러리에 저장',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (_isEditMode && widget.existingRecord!.id != null) {
                  ref.invalidate(
                      exportedRecordsProvider(widget.existingRecord!.id!));
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // 기록일시 (편집 모드에서만, 영상 위)
            if (_isEditMode && widget.existingRecord!.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 14,
                        color: ReclimColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      '기록일시 ${_formatDateTime(widget.existingRecord!.createdAt!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ReclimColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

            // 영상 플레이어
            if (_hasVideo && !_videoFileMissing)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxHeight =
                        MediaQuery.of(context).size.height * 0.275;
                    final naturalHeight =
                        constraints.maxWidth / _displayAspectRatio;
                    final playerHeight =
                        naturalHeight > maxHeight ? maxHeight : naturalHeight;

                    return SizedBox(
                      width: double.infinity,
                      height: playerHeight,
                      child: Stack(
                        children: [
                          // 플레이어 또는 로딩 placeholder
                          Positioned.fill(
                            child: Container(
                              color: Colors.black,
                              alignment: Alignment.center,
                              child: _chewieController != null
                                  ? Chewie(controller: _chewieController!)
                                  : const Center(
                                      child: CircularProgressIndicator(
                                          color: Colors.white),
                                    ),
                            ),
                          ),
                          // 편집 버튼 (편집 모드에서만)
                          if (_isEditMode &&
                              _chewieController != null &&
                              widget.existingRecord!.videoPath != null)
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
                      ),
                    );
                  },
                ),
              )
            else if (_videoFileMissing)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8ECF0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_off_rounded, size: 36,
                            color: ReclimColors.textTertiary),
                        SizedBox(height: 6),
                        Text('영상 파일을 찾을 수 없습니다.\n촬영 영상은 기기에만 저장되므로,\n파일 삭제·이동 또는 다른 기기에서\n로그인한 경우 재생할 수 없습니다.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                color: ReclimColors.textTertiary)),
                      ],
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 완등 여부
                  const Text('완등 여부',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: ReclimColors.textPrimary,
                      )),
                  const SizedBox(height: 8),
                  Row(
                    children: ClimbingStatus.values.map((s) {
                      final isSelected = _status == s;
                      final isCompleted = s == ClimbingStatus.completed;
                      final activeColor = isCompleted
                          ? ReclimColors.success
                          : const Color(0xFFFF6B35);
                      return Padding(
                        padding: EdgeInsets.only(right: isCompleted ? 8 : 0),
                        child: InkWell(
                          onTap: () => setState(() => _status = s),
                          borderRadius: BorderRadius.circular(22),
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
                                      : ReclimColors.textTertiary,
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
                                        : ReclimColors.textTertiary,
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

                  // 난이도 선택
                  DifficultySelector(
                    selectedColor: displayColor,
                    colorScale: colorScale,
                    onColorChanged: (c) {
                      if (_isEditMode) {
                        setState(() => _editColor = c);
                      } else {
                        ref.read(cameraSettingsProvider.notifier).setColor(c);
                      }
                      // 브랜드 색상표가 있으면 등급 자동 추천
                      if (colorScale != null) {
                        final level = colorScale.levelForColor(c);
                        if (level != null) {
                          final suggestedGrade = level.vMin;
                          if (_isEditMode) {
                            setState(() => _editGrade = suggestedGrade);
                          } else {
                            ref.read(cameraSettingsProvider.notifier).setGrade(suggestedGrade);
                          }
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // 암장
                  const Text('암장',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: ReclimColors.textPrimary,
                      )),
                  const SizedBox(height: 8),
                  if (displayGym != null)
                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(
                            color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 18,
                              color: Colors.grey.shade600),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _showGymSelection(context, ref),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayGym.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: ReclimColors.textPrimary,
                                    ),
                                  ),
                                  if (displayGym.address != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        displayGym.address!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: ReclimColors.textTertiary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (displayGym.latitude != null &&
                              displayGym.longitude != null)
                            IconButton(
                              onPressed: () => GymMapSheet.show(
                                context,
                                selectedGym: displayGym,
                              ),
                              icon: const Icon(Icons.map_outlined,
                                  size: 20,
                                  color: ReclimColors.accent),
                              constraints: const BoxConstraints(
                                  minWidth: 40, minHeight: 40),
                              padding: EdgeInsets.zero,
                            ),
                          IconButton(
                            onPressed: () {
                              if (_isEditMode) {
                                setState(() {
                                  _editGym = null;
                                });
                              } else {
                                ref.read(cameraSettingsProvider.notifier).clearGym();
                              }
                            },
                            icon: const Icon(Icons.close_rounded,
                                size: 18,
                                color: ReclimColors.textTertiary),
                            constraints: const BoxConstraints(
                                minWidth: 40, minHeight: 40),
                            padding: EdgeInsets.zero,
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
                        child: const Row(
                          children: [
                            Icon(Icons.add_location_alt_outlined,
                                size: 18,
                                color: ReclimColors.textTertiary),
                            SizedBox(width: 10),
                            Text(
                              '암장을 선택해주세요',
                              style: TextStyle(
                                fontSize: 14,
                                color: ReclimColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // 태그 헤더 행 (라벨 + 유지 옵션)
                  Row(
                    children: [
                      const Text('태그',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: ReclimColors.textPrimary,
                          )),
                      const Spacer(),
                      if (!_isEditMode)
                        GestureDetector(
                          onTap: () {
                            final notifier = ref.read(cameraSettingsProvider.notifier);
                            final current = ref.read(cameraSettingsProvider).persistTags;
                            notifier.setPersistTags(!current);
                            setState(() {});
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: Checkbox(
                                  value: ref.watch(cameraSettingsProvider).persistTags,
                                  onChanged: (v) {
                                    ref.read(cameraSettingsProvider.notifier).setPersistTags(v ?? false);
                                    setState(() {});
                                  },
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                '다음 촬영에도 태그 유지',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ReclimColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 태그 입력
                  TagInput(
                    tags: _tags,
                    onTagsChanged: (tags) => setState(() => _tags = tags),
                    showLabel: false,
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
          ],
              ),
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
                const Icon(Icons.video_library_rounded,
                    size: 18,
                    color: ReclimColors.textSecondary),
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
                  onEditTitle: (newTitle) async {
                    await RecordService.updateExportMemo(
                      recordId: export.id!,
                      memo: newTitle.isEmpty ? null : newTitle,
                    );
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
      error: (_, __) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('내보내기 영상을 불러오지 못했습니다',
                style: TextStyle(fontSize: 13,
                  color: ReclimColors.textTertiary)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => ref.invalidate(
                    exportedRecordsProvider(parentRecordId)),
                child: const Text('다시 시도',
                  style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ReclimColors.accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 내보내기 영상 카드
class _ExportedVideoCard extends ConsumerStatefulWidget {
  final ClimbingRecord record;
  final VoidCallback onDelete;
  final ValueChanged<String> onEditTitle;
  const _ExportedVideoCard({
    required this.record,
    required this.onDelete,
    required this.onEditTitle,
  });

  @override
  ConsumerState<_ExportedVideoCard> createState() => _ExportedVideoCardState();
}

class _ExportedVideoCardState extends ConsumerState<_ExportedVideoCard> {
  bool _isEditing = false;
  late final TextEditingController _titleController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.record.memo?.isNotEmpty == true ? widget.record.memo : '',
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && _isEditing) {
      _commitEdit();
    }
  }

  Future<void> _saveExportToGallery(ClimbingRecord record) async {
    final videoPath = record.videoPath!;
    String localPath;

    if (record.isLocalVideo) {
      if (!File(videoPath).existsSync()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('영상 파일을 찾을 수 없습니다')),
          );
        }
        return;
      }
      localPath = videoPath;
    } else {
      final downloaded =
          await downloadRemoteVideoWithDialog(context, videoPath);
      if (downloaded == null) return;
      localPath = downloaded;
    }

    try {
      final album = resolveGalleryAlbum(
        ref.read(gallerySavePathProvider),
        gymName: record.gymName,
      );
      await Gal.putVideo(localPath, album: album);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('갤러리에 저장되었습니다'),
            backgroundColor: Color(0xFF2196F3),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('저장에 실패했습니다'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _startEditing() {
    setState(() => _isEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _commitEdit() {
    final newTitle = _titleController.text.trim();
    final oldTitle = widget.record.memo ?? '';
    setState(() => _isEditing = false);
    if (newTitle != oldTitle) {
      widget.onEditTitle(newTitle);
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final thumbPath = record.thumbnailPath;
    final hasThumbnail = thumbPath != null &&
        (thumbPath.startsWith('/') ? File(thumbPath).existsSync() : true);

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
          final vPath = record.videoPath;
          if (vPath == null) return;
          final canPlay = vPath.startsWith('/')
              ? File(vPath).existsSync()
              : true;
          if (canPlay) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _FullScreenVideoPlayer(
                      videoPath: vPath,
                      title: record.memo,
                    ),
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
                          ? (thumbPath.startsWith('/')
                              ? Image.file(
                                  File(thumbPath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFFE2E8F0),
                                    child: const Icon(Icons.movie_rounded,
                                        color: Colors.white, size: 20),
                                  ),
                                )
                              : FutureBuilder<String>(
                                  future: R2Config.getPresignedUrl(thumbPath),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError || !snapshot.hasData) {
                                      return Container(
                                        color: const Color(0xFFE2E8F0),
                                        child: snapshot.hasError
                                            ? const Icon(Icons.movie_rounded,
                                                color: Colors.white, size: 20)
                                            : const Center(
                                                child: SizedBox(
                                                  width: 16, height: 16,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                ),
                                              ),
                                      );
                                    }
                                    return Image.network(
                                      snapshot.data!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: const Color(0xFFE2E8F0),
                                        child: const Icon(Icons.movie_rounded,
                                            color: Colors.white, size: 20),
                                      ),
                                    );
                                  },
                                ))
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
                    if (_isEditing)
                      TextField(
                        controller: _titleController,
                        focusNode: _focusNode,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                        decoration: const InputDecoration(
                          hintText: '제목을 입력하세요',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 0, vertical: 4),
                          border: UnderlineInputBorder(),
                        ),
                        onSubmitted: (_) => _commitEdit(),
                      )
                    else
                      Text(
                        record.memo?.isNotEmpty == true
                            ? record.memo!
                            : '편집 영상',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(record.createdAt),
                      style: const TextStyle(
                          fontSize: 12,
                          color: ReclimColors.textTertiary),
                    ),
                  ],
                ),
              ),
              if (record.videoPath != null)
                IconButton(
                  onPressed: () => _saveExportToGallery(record),
                  icon: const Icon(Icons.download_rounded,
                      size: 18,
                      color: ReclimColors.textTertiary),
                  constraints: const BoxConstraints(
                      minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                ),
              IconButton(
                onPressed: _startEditing,
                icon: const Icon(Icons.edit_rounded,
                    size: 18,
                    color: ReclimColors.textTertiary),
                constraints: const BoxConstraints(
                    minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
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
                  if (confirmed == true) widget.onDelete();
                },
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20,
                    color: ReclimColors.textTertiary),
                constraints: const BoxConstraints(
                    minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
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
  final String? title;
  const _FullScreenVideoPlayer({required this.videoPath, this.title});

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
    if (widget.videoPath.startsWith('/')) {
      _videoController = VideoPlayerController.file(File(widget.videoPath));
    } else {
      final url = await R2Config.getPresignedUrl(widget.videoPath);
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    }
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
        title: Text(widget.title?.isNotEmpty == true ? widget.title! : '편집 영상'),
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
