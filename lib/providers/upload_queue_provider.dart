import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/climbing_record.dart';
import '../models/user_subscription.dart';
import '../services/video_upload_service.dart';
import 'connectivity_provider.dart';
import 'subscription_provider.dart';

// --- 모델 ---

enum UploadStatus { pending, uploading, uploaded, failed }

class UploadTask {
  final String recordId;
  final String localVideoPath;
  UploadStatus status;
  int retryCount;
  String? errorMessage;
  final DateTime createdAt;

  UploadTask({
    required this.recordId,
    required this.localVideoPath,
    this.status = UploadStatus.pending,
    this.retryCount = 0,
    this.errorMessage,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'recordId': recordId,
        'localVideoPath': localVideoPath,
        'status': status.name,
        'retryCount': retryCount,
        'errorMessage': errorMessage,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UploadTask.fromJson(Map<String, dynamic> json) => UploadTask(
        recordId: json['recordId'] as String,
        localVideoPath: json['localVideoPath'] as String,
        status: UploadStatus.values.byName(json['status'] as String),
        retryCount: json['retryCount'] as int? ?? 0,
        errorMessage: json['errorMessage'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

// --- Provider ---

const _queueKey = 'upload_queue';
const _maxRetries = 5;

final uploadQueueProvider =
    StateNotifierProvider<UploadQueueNotifier, List<UploadTask>>((ref) {
  return UploadQueueNotifier(ref);
});

/// 업로드 큐에서 특정 recordId의 상태 조회
final uploadStatusProvider =
    Provider.family<UploadStatus?, String>((ref, recordId) {
  final queue = ref.watch(uploadQueueProvider);
  try {
    return queue.firstWhere((t) => t.recordId == recordId).status;
  } catch (_) {
    return null;
  }
});

class UploadQueueNotifier extends StateNotifier<List<UploadTask>> {
  final Ref _ref;
  bool _isProcessing = false;

  UploadQueueNotifier(this._ref) : super([]) {
    _init();
  }

  Future<void> _init() async {
    await _load();
    // 앱 시작 시 uploading → pending 리셋 (앱 킬 대응)
    var changed = false;
    for (final task in state) {
      if (task.status == UploadStatus.uploading) {
        task.status = UploadStatus.pending;
        changed = true;
      }
    }
    if (changed) {
      state = [...state];
      await _persist();
    }
    // 연결 상태 감시하여 Wi-Fi 전환 시 큐 처리
    _ref.listen(connectivityProvider, (prev, next) {
      next.whenData((results) {
        if (results.contains(ConnectivityResult.wifi)) {
          processQueue();
        }
      });
    });
    processQueue();

    // 클라우드 모드일 때만 고아 레코드 자동 등록
    final mode = _ref.read(storageModeProvider);
    if (mode == StorageMode.cloud) {
      _autoEnqueueOrphanedRecords();
    }
  }

  /// DB에서 로컬 전용(video_path가 '/'로 시작) 레코드를 조회하여
  /// 큐에 없는 건을 자동 등록
  Future<void> _autoEnqueueOrphanedRecords() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('climbing_records')
          .select('id, video_path')
          .eq('user_id', userId)
          .eq('local_only', false)
          .like('video_path', '/%');

      int enqueued = 0;
      for (final row in response as List) {
        final recordId = row['id'] as String;
        final videoPath = row['video_path'] as String;
        if (state.any((t) => t.recordId == recordId)) continue;
        if (!File(videoPath).existsSync()) continue;

        state = [...state, UploadTask(recordId: recordId, localVideoPath: videoPath)];
        enqueued++;
      }
      if (enqueued > 0) {
        debugPrint('[UploadQueue] 고아 레코드 $enqueued건 자동 큐 등록');
        await _persist();
        processQueue();
      }
    } catch (e) {
      debugPrint('[UploadQueue] 고아 레코드 자동 등록 실패: $e');
    }
  }

  /// 업로드 태스크 추가
  Future<void> enqueue({
    required String recordId,
    required String localVideoPath,
  }) async {
    // 이미 큐에 있으면 무시
    if (state.any((t) => t.recordId == recordId)) return;

    final task = UploadTask(
      recordId: recordId,
      localVideoPath: localVideoPath,
    );
    state = [...state, task];
    await _persist();
    processQueue();
  }

  /// 큐에서 제거
  Future<void> removeTask(String recordId) async {
    state = state.where((t) => t.recordId != recordId).toList();
    await _persist();
  }

  /// 전체 큐 초기화
  Future<void> clearAll() async {
    state = [];
    await _persist();
  }

  /// 로컬 전용 레코드 일괄 업로드 큐 등록
  Future<int> enqueueLocalRecords(List<ClimbingRecord> records) async {
    int enqueued = 0;
    for (final record in records) {
      if (record.id == null || record.videoPath == null) continue;
      if (!record.videoPath!.startsWith('/')) continue;
      if (state.any((t) => t.recordId == record.id)) continue;
      if (!File(record.videoPath!).existsSync()) continue;

      final task = UploadTask(
        recordId: record.id!,
        localVideoPath: record.videoPath!,
      );
      state = [...state, task];
      enqueued++;
    }
    if (enqueued > 0) {
      await _persist();
      processQueue();
    }
    return enqueued;
  }

  /// 실패 태스크 재시도
  Future<void> retryFailed() async {
    var changed = false;
    for (final task in state) {
      if (task.status == UploadStatus.failed) {
        task.status = UploadStatus.pending;
        task.retryCount = 0;
        task.errorMessage = null;
        changed = true;
      }
    }
    if (changed) {
      state = [...state];
      await _persist();
      processQueue();
    }
  }

  /// 큐 순차 처리
  Future<void> processQueue() async {
    if (_isProcessing) return;

    // 로컬 모드면 큐 처리하지 않음
    final mode = _ref.read(storageModeProvider);
    if (mode == StorageMode.local) return;

    _isProcessing = true;

    try {
      final wifiOnly = _ref.read(wifiOnlyUploadProvider);
      final isWifi = _ref.read(isWifiProvider);

      debugPrint('[UploadQueue] processQueue: ${state.length} tasks, wifiOnly=$wifiOnly, isWifi=$isWifi');

      // Wi-Fi 전용 모드인데 Wi-Fi가 아니면 중단
      if (wifiOnly && !isWifi) {
        debugPrint('[UploadQueue] 스킵: Wi-Fi 아님');
        return;
      }

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('[UploadQueue] 스킵: userId null');
        return;
      }

      for (final task in state) {
        if (task.status != UploadStatus.pending) {
          debugPrint('[UploadQueue] 스킵 task ${task.recordId}: status=${task.status.name}');
          continue;
        }

        // Wi-Fi 상태 재확인
        if (wifiOnly && !_ref.read(isWifiProvider)) break;

        // 로컬 파일 존재 확인
        if (!File(task.localVideoPath).existsSync()) {
          task.status = UploadStatus.failed;
          task.errorMessage = '영상 파일을 찾을 수 없습니다';
          state = [...state];
          await _persist();
          continue;
        }

        debugPrint('[UploadQueue] 업로드 시작: ${task.recordId} (${task.localVideoPath})');
        task.status = UploadStatus.uploading;
        state = [...state];
        await _persist();

        try {
          await VideoUploadService.uploadVideoAndUpdateRecord(
            recordId: task.recordId,
            localVideoPath: task.localVideoPath,
            userId: userId,
          ).timeout(const Duration(minutes: 5));

          debugPrint('[UploadQueue] 업로드 성공: ${task.recordId}');
          task.status = UploadStatus.uploaded;
        } catch (e) {
          task.retryCount++;
          if (task.retryCount >= _maxRetries) {
            task.status = UploadStatus.failed;
            task.errorMessage = e.toString();
          } else {
            task.status = UploadStatus.pending;
          }
          debugPrint('영상 업로드 실패 (${task.retryCount}/$_maxRetries): $e');
        }

        state = [...state];
        await _persist();
      }

      // 완료된 태스크 정리
      state = state.where((t) => t.status != UploadStatus.uploaded).toList();
      await _persist();
    } finally {
      _isProcessing = false;
    }
  }

  // --- 영속화 ---

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final json = state.map((t) => t.toJson()).toList();
    await prefs.setString(_queueKey, jsonEncode(json));
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => UploadTask.fromJson(e as Map<String, dynamic>))
          .toList();
      state = list;
    } catch (e) {
      debugPrint('업로드 큐 로드 실패: $e');
    }
  }
}
