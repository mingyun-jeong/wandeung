import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../config/r2_config.dart';

class VideoPlaybackScreen extends StatefulWidget {
  final String videoPath;
  const VideoPlaybackScreen({super.key, required this.videoPath});

  @override
  State<VideoPlaybackScreen> createState() => _VideoPlaybackScreenState();
}

class _VideoPlaybackScreenState extends State<VideoPlaybackScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  double? _displayAspectRatio;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final path = widget.videoPath;

    // video_path가 null이면 보관 기간 만료
    if (path.isEmpty) {
      if (mounted) setState(() => _errorMessage = '보관 기간이 만료된 영상입니다.');
      return;
    }

    if (path.startsWith('/')) {
      if (!File(path).existsSync()) {
        if (mounted) setState(() => _errorMessage = '영상 파일을 찾을 수 없습니다.\n촬영 영상은 기기에만 저장되므로,\n파일 삭제·이동 또는 다른 기기에서\n로그인한 경우 재생할 수 없습니다.');
        return;
      }
      _videoController = VideoPlayerController.file(File(path));
    } else {
      debugPrint('[R2] video_path from DB: "$path"');
      final url = await R2Config.getPresignedUrl(path);
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    }

    try {
      await _videoController!.initialize().timeout(
        const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('[R2] 영상 초기화 실패: $e (path=$path)');
      _videoController?.dispose();
      _videoController = null;
      if (mounted) setState(() => _errorMessage = '영상을 재생할 수 없습니다');
      return;
    }

    final size = _videoController!.value.size;
    final rotation = _videoController!.value.rotationCorrection;
    if (size.width > 0 && size.height > 0 && (rotation == 90 || rotation == 270)) {
      _displayAspectRatio = size.height / size.width;
    } else {
      _displayAspectRatio = _videoController!.value.aspectRatio;
    }

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      aspectRatio: _displayAspectRatio,
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

    if (mounted) setState(() {});
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
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
        child: _errorMessage != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_off_rounded,
                      size: 48, color: Colors.white38),
                  const SizedBox(height: 8),
                  Text(_errorMessage!,
                      style: const TextStyle(color: Colors.white54)),
                ],
              )
            : _chewieController != null
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator(color: Colors.white),
      ),
      ),
    );
  }
}
