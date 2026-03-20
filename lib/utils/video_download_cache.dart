import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/r2_config.dart';
import '../app.dart';

/// 다운로드 작업을 제어하기 위한 토큰.
/// 취소 요청 및 상태 추적에 사용한다.
class DownloadToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// R2 원격 영상을 로컬 임시 디렉토리에 다운로드·캐시한다.
class VideoDownloadCache {
  VideoDownloadCache._();

  static const _cacheDir = 'r2_video_cache';
  static const _partialSuffix = '.partial';

  /// [objectKey]에 해당하는 로컬 캐시 경로를 반환한다.
  /// 이미 캐시되어 있으면 즉시 반환, 아니면 다운로드 후 반환.
  /// [onProgress]는 0.0~1.0 범위의 진행률을 콜백한다.
  /// [token]이 주어지면 취소를 지원한다.
  /// [onBytesInfo]는 (receivedBytes, totalBytes)를 콜백한다.
  static Future<String> getLocalPath(
    String objectKey, {
    void Function(double progress)? onProgress,
    void Function(int received, int total)? onBytesInfo,
    DownloadToken? token,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory('${tempDir.path}/$_cacheDir');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final fileName = objectKey.replaceAll('/', '_');
    final file = File('${dir.path}/$fileName');
    final partialFile = File('${dir.path}/$fileName$_partialSuffix');

    // 완성된 캐시가 있으면 즉시 반환
    if (file.existsSync() && file.lengthSync() > 0) {
      onProgress?.call(1.0);
      onBytesInfo?.call(file.lengthSync(), file.lengthSync());
      return file.path;
    }

    // 이전에 중단된 부분 파일이 있으면 이어받기 시도
    int existingBytes = 0;
    if (partialFile.existsSync()) {
      existingBytes = partialFile.lengthSync();
    }

    final url = R2Config.getPresignedUrl(objectKey);
    final request = http.Request('GET', Uri.parse(url));

    // Range 헤더로 이어받기
    if (existingBytes > 0) {
      request.headers['Range'] = 'bytes=$existingBytes-';
    }

    final client = http.Client();

    try {
      final response = await client.send(request);

      // 206 = 이어받기 성공, 200 = 전체 다운로드
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException(
          '영상 다운로드 실패 (${response.statusCode})',
          uri: Uri.parse(url),
        );
      }

      // 서버가 Range를 지원하지 않으면 처음부터 다시
      final isResumed = response.statusCode == 206;
      if (!isResumed && existingBytes > 0) {
        existingBytes = 0;
        if (partialFile.existsSync()) partialFile.deleteSync();
      }

      final contentLength = response.contentLength ?? -1;
      final totalBytes =
          isResumed ? existingBytes + contentLength : contentLength;
      int receivedBytes = existingBytes;

      // 부분 파일에 추가 기록
      final sink = partialFile.openWrite(
        mode: isResumed ? FileMode.append : FileMode.write,
      );

      try {
        await for (final chunk in response.stream) {
          if (token != null && token.isCancelled) {
            await sink.close();
            client.close();
            throw _DownloadCancelledException();
          }

          sink.add(chunk);
          receivedBytes += chunk.length;

          if (totalBytes > 0) {
            onProgress?.call(receivedBytes / totalBytes);
            onBytesInfo?.call(receivedBytes, totalBytes);
          }
        }

        await sink.close();
      } catch (e) {
        await sink.close();
        rethrow;
      }

      // 다운로드 완료 → 부분 파일을 정식 캐시로 이름 변경
      await partialFile.rename(file.path);
      return file.path;
    } catch (e) {
      if (e is _DownloadCancelledException) rethrow;
      client.close();
      rethrow;
    } finally {
      client.close();
    }
  }

  /// 부분 파일이 존재하는지 확인한다 (이어받기 가능 여부).
  static Future<int> getPartialBytes(String objectKey) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = objectKey.replaceAll('/', '_');
      final partialFile =
          File('${tempDir.path}/$_cacheDir/$fileName$_partialSuffix');
      if (partialFile.existsSync()) return partialFile.lengthSync();
    } catch (_) {}
    return 0;
  }

  /// 다운로드 실패 시 부분 파일을 삭제한다.
  static Future<void> cleanupPartialFile(String objectKey) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = objectKey.replaceAll('/', '_');
      final file = File('${tempDir.path}/$_cacheDir/$fileName');
      final partialFile =
          File('${tempDir.path}/$_cacheDir/$fileName$_partialSuffix');
      if (file.existsSync()) file.deleteSync();
      if (partialFile.existsSync()) partialFile.deleteSync();
    } catch (_) {}
  }
}

class _DownloadCancelledException implements Exception {}

/// 파일 크기를 읽기 쉬운 문자열로 변환한다.
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Wi-Fi 미연결 시 네트워크 사용 확인 다이얼로그를 표시한다.
/// 사용자가 확인하면 true, 취소하면 false 반환.
/// Wi-Fi 연결 시 확인 없이 true 반환.
///
/// [title]과 [message]로 다이얼로그 내용을 커스텀할 수 있다.
/// [confirmLabel]은 확인 버튼 텍스트 (기본: '다운로드').
Future<bool> confirmIfNotWifi(
  BuildContext context, {
  String title = '영상 다운로드',
  String message = '영상을 편집하려면 먼저 다운로드해야 합니다.\n\nWi-Fi에 연결되어 있지 않습니다. 모바일 데이터로 다운로드하시겠습니까?',
  String confirmLabel = '다운로드',
}) async {
  bool isWifi;
  try {
    final interfaces = await NetworkInterface.list();
    debugPrint('[Wi-Fi 체크] interfaces: ${interfaces.map((i) => i.name).toList()}');
    // Android Wi-Fi 인터페이스명: wlan0
    isWifi = interfaces.any((i) => i.name.startsWith('wlan'));
  } catch (e) {
    debugPrint('[Wi-Fi 체크] 오류: $e');
    isWifi = false;
  }
  debugPrint('[Wi-Fi 체크] isWifi: $isWifi');
  if (isWifi) return true;

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ClimpickColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // 제목
              Row(
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      size: 20, color: ClimpickColors.textPrimary),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: ClimpickColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 안내 메시지
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: ClimpickColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ClimpickColors.border),
                ),
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: ClimpickColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 버튼 영역
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ClimpickColors.textSecondary,
                          side: const BorderSide(color: ClimpickColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          confirmLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  return confirmed == true;
}

/// R2 영상을 다운로드하면서 예쁜 바텀시트 UI를 표시한다.
/// 성공 시 로컬 경로, 실패 시 null 반환.
Future<String?> downloadRemoteVideoWithDialog(
  BuildContext context,
  String objectKey,
) async {
  // Wi-Fi 미연결 시 사용자 확인
  final confirmed = await confirmIfNotWifi(context);
  if (!confirmed) return null;
  if (!context.mounted) return null;

  final progress = ValueNotifier<double>(0.0);
  final bytesInfo = ValueNotifier<(int, int)>((0, 0));
  final status = ValueNotifier<_DownloadStatus>(_DownloadStatus.downloading);
  DownloadToken? token = DownloadToken();
  String? result;

  final partialBytes = await VideoDownloadCache.getPartialBytes(objectKey);
  final isResuming = partialBytes > 0;

  Future<void> startDownload() async {
    status.value = _DownloadStatus.downloading;
    token = DownloadToken();

    try {
      result = await VideoDownloadCache.getLocalPath(
        objectKey,
        onProgress: (v) => progress.value = v,
        onBytesInfo: (received, total) => bytesInfo.value = (received, total),
        token: token,
      );
      status.value = _DownloadStatus.completed;
    } on _DownloadCancelledException {
      status.value = _DownloadStatus.cancelled;
    } catch (e) {
      status.value = _DownloadStatus.error;
    }
  }

  // 다운로드 시작 (fire-and-forget)
  // ignore: unawaited_futures
  startDownload();

  // 캐시 히트 등으로 즉시 완료되었으면 바텀시트 없이 바로 반환
  // (microtask가 끝날 때까지 기다려서 동기적 완료를 감지한다)
  await Future<void>.delayed(Duration.zero);
  if (status.value == _DownloadStatus.completed) {
    progress.dispose();
    bytesInfo.dispose();
    status.dispose();
    return result;
  }

  if (!context.mounted) {
    token?.cancel();
    progress.dispose();
    bytesInfo.dispose();
    status.dispose();
    return null;
  }

  // 바텀시트 표시
  await showModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _DownloadBottomSheet(
      progress: progress,
      bytesInfo: bytesInfo,
      status: status,
      isResuming: isResuming,
      onCancel: () {
        token?.cancel();
      },
      onResume: () {
        progress.value = 0.0;
        startDownload();
      },
      onClose: () {
        Navigator.of(sheetContext).pop();
      },
    ),
  );

  // 다운로드가 아직 진행 중이면 취소
  if (status.value == _DownloadStatus.downloading) {
    token?.cancel();
  }

  final finalStatus = status.value;

  progress.dispose();
  bytesInfo.dispose();
  status.dispose();

  if (finalStatus == _DownloadStatus.error && context.mounted) {
    await VideoDownloadCache.cleanupPartialFile(objectKey);
  }

  return result;
}

enum _DownloadStatus { downloading, completed, cancelled, error }

class _DownloadBottomSheet extends StatefulWidget {
  final ValueNotifier<double> progress;
  final ValueNotifier<(int, int)> bytesInfo;
  final ValueNotifier<_DownloadStatus> status;
  final bool isResuming;
  final VoidCallback onCancel;
  final VoidCallback onResume;
  final VoidCallback onClose;

  const _DownloadBottomSheet({
    required this.progress,
    required this.bytesInfo,
    required this.status,
    required this.isResuming,
    required this.onCancel,
    required this.onResume,
    required this.onClose,
  });

  @override
  State<_DownloadBottomSheet> createState() => _DownloadBottomSheetState();
}

class _DownloadBottomSheetState extends State<_DownloadBottomSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    widget.status.addListener(_onStatusChanged);

    // 다운로드가 이미 완료된 경우 (캐시 히트 등) 즉시 닫기
    if (widget.status.value == _DownloadStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onClose();
      });
    }
  }

  void _onStatusChanged() {
    final s = widget.status.value;
    if (s == _DownloadStatus.completed) {
      // 완료 시 자동으로 닫기
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) widget.onClose();
      });
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.status.removeListener(_onStatusChanged);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const teal = ClimpickColors.accent;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 드래그 핸들
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outline.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // 아이콘 + 상태
              ValueListenableBuilder<_DownloadStatus>(
                valueListenable: widget.status,
                builder: (_, status, __) => _buildStatusIcon(status, teal),
              ),
              const SizedBox(height: 16),

              // 상태 텍스트
              ValueListenableBuilder<_DownloadStatus>(
                valueListenable: widget.status,
                builder: (_, status, __) {
                  final text = switch (status) {
                    _DownloadStatus.downloading =>
                      widget.isResuming ? '이어서 다운로드 중...' : '영상 다운로드 중...',
                    _DownloadStatus.completed => '다운로드 완료!',
                    _DownloadStatus.cancelled => '다운로드가 취소되었습니다',
                    _DownloadStatus.error => '다운로드에 실패했습니다',
                  };
                  return Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // 프로그레스 바
              ValueListenableBuilder<_DownloadStatus>(
                valueListenable: widget.status,
                builder: (_, status, __) {
                  if (status == _DownloadStatus.cancelled ||
                      status == _DownloadStatus.error) {
                    return const SizedBox.shrink();
                  }
                  return ValueListenableBuilder<double>(
                    valueListenable: widget.progress,
                    builder: (_, value, __) {
                      final isComplete =
                          status == _DownloadStatus.completed;
                      return Column(
                        children: [
                          // 프로그레스 바 컨테이너
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: teal.withOpacity(0.1),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, _) {
                                  return LinearProgressIndicator(
                                    value: value > 0 ? value : null,
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isComplete
                                          ? teal
                                          : Color.lerp(
                                              teal,
                                              teal.withOpacity(0.7),
                                              _pulseController.value,
                                            )!,
                                    ),
                                    minHeight: 8,
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // 퍼센트 + 파일 크기 정보
                          ValueListenableBuilder<(int, int)>(
                            valueListenable: widget.bytesInfo,
                            builder: (_, info, __) {
                              final (received, total) = info;
                              final percent = (value * 100).toInt();
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$percent%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: teal,
                                    ),
                                  ),
                                  if (total > 0)
                                    Text(
                                      '${_formatBytes(received)} / ${_formatBytes(total)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurface
                                            .withOpacity(0.45),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),

              // 액션 버튼
              ValueListenableBuilder<_DownloadStatus>(
                valueListenable: widget.status,
                builder: (_, status, __) {
                  return switch (status) {
                    _DownloadStatus.downloading => SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: widget.onCancel,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('취소'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.onSurface
                                .withOpacity(0.6),
                            side: BorderSide(
                              color:
                                  colorScheme.outline.withOpacity(0.2),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    _DownloadStatus.cancelled => Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: widget.onClose,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colorScheme.onSurface
                                      .withOpacity(0.6),
                                  side: BorderSide(
                                    color: colorScheme.outline
                                        .withOpacity(0.2),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('닫기'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: () {
                                  setState(() {});
                                  widget.onResume();
                                },
                                icon: const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 20),
                                label: const Text('이어받기'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: teal,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    _DownloadStatus.error => Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: widget.onClose,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colorScheme.onSurface
                                      .withOpacity(0.6),
                                  side: BorderSide(
                                    color: colorScheme.outline
                                        .withOpacity(0.2),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('닫기'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: () {
                                  setState(() {});
                                  widget.onResume();
                                },
                                icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 20),
                                label: const Text('다시 시도'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: teal,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    _DownloadStatus.completed => const SizedBox.shrink(),
                  };
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(_DownloadStatus status, Color teal) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (status) {
        _DownloadStatus.downloading => Container(
            key: const ValueKey('downloading'),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: teal.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.download_rounded,
              color: teal,
              size: 28,
            ),
          ),
        _DownloadStatus.completed => Container(
            key: const ValueKey('completed'),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: teal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: teal,
              size: 32,
            ),
          ),
        _DownloadStatus.cancelled => Container(
            key: const ValueKey('cancelled'),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pause_circle_rounded,
              color: Colors.orange,
              size: 32,
            ),
          ),
        _DownloadStatus.error => Container(
            key: const ValueKey('error'),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_rounded,
              color: Colors.red,
              size: 32,
            ),
          ),
      },
    );
  }
}

