import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../models/climbing_gym.dart';
import '../models/climbing_record.dart';
import '../models/user_climbing_stats.dart';
import '../services/video_upload_service.dart';
import 'auth_provider.dart';

// 필터 상태 (카테고리별 단일 선택)
final selectedColorFilterProvider = StateProvider<String?>((ref) => null);
final selectedStatusFilterProvider = StateProvider<String?>((ref) => null);
final selectedTagFilterProvider = StateProvider<String?>((ref) => null);
final selectedGymFilterProvider = StateProvider<String?>((ref) => null);

const _selectWithGym = '*, climbing_gyms(name)';

/// authProvider를 watch해서 현재 유저 ID를 가져온다.
/// 로그인하면 자동으로 provider가 re-fetch되고, 로그아웃하면 빈 값 반환.
String? _watchUserId(Ref ref) => ref.watch(authProvider).valueOrNull?.id;

final recordsByDateProvider =
    FutureProvider.family<List<ClimbingRecord>, DateTime>((ref, date) async {
  final userId = _watchUserId(ref);
  if (userId == null) return [];
  final dateStr = date.toIso8601String().split('T')[0];

  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select(_selectWithGym)
      .eq('user_id', userId)
      .eq('recorded_at', dateStr)
      .isFilter('parent_record_id', null)
      .order('created_at', ascending: false);

  return (response as List)
      .map((e) => ClimbingRecord.fromMap(e))
      .toList();
});

/// 캘린더 마커용: 월별 기록이 있는 날짜 목록
final recordDatesProvider =
    FutureProvider.family<Set<DateTime>, DateTime>((ref, month) async {
  final userId = _watchUserId(ref);
  if (userId == null) return {};
  final firstDay = DateTime(month.year, month.month, 1);
  final lastDay = DateTime(month.year, month.month + 1, 0);

  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select('recorded_at')
      .eq('user_id', userId)
      .gte('recorded_at', firstDay.toIso8601String().split('T')[0])
      .lte('recorded_at', lastDay.toIso8601String().split('T')[0])
      .isFilter('parent_record_id', null);

  return (response as List)
      .map((e) => DateTime.parse(e['recorded_at']))
      .toSet();
});

/// 캘린더 배지용: 월별 날짜 → 필터 적용된 기록 개수 맵
final recordCountsByDateProvider =
    FutureProvider.family<Map<DateTime, int>, DateTime>((ref, month) async {
  final color = ref.watch(selectedColorFilterProvider);
  final status = ref.watch(selectedStatusFilterProvider);
  final tag = ref.watch(selectedTagFilterProvider);
  final gymName = ref.watch(selectedGymFilterProvider);

  final userId = _watchUserId(ref);
  if (userId == null) return {};
  final firstDay = DateTime(month.year, month.month, 1);
  final lastDay = DateTime(month.year, month.month + 1, 0);

  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select('recorded_at, status, difficulty_color, tags, climbing_gyms(name)')
      .eq('user_id', userId)
      .gte('recorded_at', firstDay.toIso8601String().split('T')[0])
      .lte('recorded_at', lastDay.toIso8601String().split('T')[0])
      .isFilter('parent_record_id', null);

  final counts = <DateTime, int>{};
  for (final row in response as List) {
    if (color != null && row['difficulty_color'] != color) continue;
    if (status != null && row['status'] != status) continue;
    if (gymName != null) {
      final rowGymName = (row['climbing_gyms'] as Map?)?['name'];
      if (rowGymName != gymName) continue;
    }
    if (tag != null) {
      final tags = (row['tags'] as List?)?.cast<String>() ?? [];
      if (!tags.contains(tag)) continue;
    }

    final date = DateTime.parse(row['recorded_at']);
    final normalized = DateTime(date.year, date.month, date.day);
    counts[normalized] = (counts[normalized] ?? 0) + 1;
  }
  return counts;
});

/// 내보내기 영상 목록 (원본 기록 기준)
final exportedRecordsProvider =
    FutureProvider.family<List<ClimbingRecord>, String>((ref, parentId) async {
  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select(_selectWithGym)
      .eq('parent_record_id', parentId)
      .order('created_at', ascending: false);

  return (response as List)
      .map((e) => ClimbingRecord.fromMap(e))
      .toList();
});

/// 홈 탭 요약 통계 (최근 30일 기준)
final userStatsProvider = FutureProvider<UserClimbingStats>((ref) async {
  final userId = _watchUserId(ref);
  if (userId == null) {
    return const UserClimbingStats(
      totalClimbs: 0,
      totalCompleted: 0,
      totalInProgress: 0,
      completionRate: 0,
      inProgressRate: 0,
      currentStreak: 0,
      monthlyClimbs: 0,
    );
  }
  final now = DateTime.now();
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  final thirtyDaysAgoStr = thirtyDaysAgo.toIso8601String().split('T')[0];

  // 최근 30일 기록만 조회
  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select('id, status, recorded_at')
      .eq('user_id', userId)
      .isFilter('parent_record_id', null)
      .gte('recorded_at', thirtyDaysAgoStr);

  final rows = response as List;
  final totalClimbs = rows.length;
  final totalCompleted =
      rows.where((r) => r['status'] == 'completed').length;
  final totalInProgress =
      rows.where((r) => r['status'] == 'in_progress').length;
  final completionRate =
      totalClimbs > 0 ? (totalCompleted / totalClimbs * 100) : 0.0;
  final inProgressRate =
      totalClimbs > 0 ? (totalInProgress / totalClimbs * 100) : 0.0;

  // 이번 달 등반 횟수
  final monthlyClimbs = rows.where((r) {
    final date = DateTime.parse(r['recorded_at']);
    return date.year == now.year && date.month == now.month;
  }).length;

  // 연속 등반일수 (streak) — 전체 기록 기준
  final allResponse = await SupabaseConfig.client
      .from('climbing_records')
      .select('recorded_at')
      .eq('user_id', userId)
      .isFilter('parent_record_id', null);

  final allDates = (allResponse as List)
      .map((r) => DateTime.parse(r['recorded_at']))
      .map((d) => DateTime(d.year, d.month, d.day))
      .toSet();

  int streak = 0;
  var checkDate = DateTime(now.year, now.month, now.day);
  if (!allDates.contains(checkDate)) {
    checkDate = checkDate.subtract(const Duration(days: 1));
  }
  while (allDates.contains(checkDate)) {
    streak++;
    checkDate = checkDate.subtract(const Duration(days: 1));
  }

  return UserClimbingStats(
    totalClimbs: totalClimbs,
    totalCompleted: totalCompleted,
    totalInProgress: totalInProgress,
    completionRate: completionRate,
    inProgressRate: inProgressRate,
    currentStreak: streak,
    monthlyClimbs: monthlyClimbs,
  );
});

/// 홈 탭 최근 기록 (최신 5개)
final recentRecordsProvider =
    FutureProvider<List<ClimbingRecord>>((ref) async {
  final userId = _watchUserId(ref);
  if (userId == null) return [];

  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select(_selectWithGym)
      .eq('user_id', userId)
      .isFilter('parent_record_id', null)
      .order('recorded_at', ascending: false)
      .order('created_at', ascending: false)
      .limit(5);

  return (response as List)
      .map((e) => ClimbingRecord.fromMap(e))
      .toList();
});

/// 홈 탭 최근 방문 암장 (최근 기록에서 추출, 중복 제거)
final recentGymsProvider = FutureProvider<List<ClimbingGym>>((ref) async {
  final userId = _watchUserId(ref);
  if (userId == null) return [];

  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select('climbing_gyms(id, name, address, latitude, longitude, google_place_id), recorded_at')
      .eq('user_id', userId)
      .isFilter('parent_record_id', null)
      .not('gym_id', 'is', null)
      .order('recorded_at', ascending: false)
      .limit(50);

  final seen = <String>{};
  final gyms = <ClimbingGym>[];
  for (final row in response as List) {
    final gymMap = row['climbing_gyms'] as Map<String, dynamic>?;
    if (gymMap == null) continue;
    final name = gymMap['name'] as String?;
    if (name != null && seen.add(name)) {
      gyms.add(ClimbingGym.fromMap(gymMap));
    }
    if (gyms.length >= 5) break;
  }
  return gyms;
});

/// 사용자가 방문한 모든 암장 이름 (필터용)
final userVisitedGymsProvider = FutureProvider<List<String>>((ref) async {
  final userId = _watchUserId(ref);
  if (userId == null) return [];

  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select('climbing_gyms(name)')
      .eq('user_id', userId)
      .isFilter('parent_record_id', null)
      .not('gym_id', 'is', null);

  final gyms = (response as List)
      .map((e) => (e['climbing_gyms'] as Map?)?['name'] as String?)
      .where((name) => name != null)
      .cast<String>()
      .toSet()
      .toList()
    ..sort();

  return gyms;
});

/// 사용자의 모든 태그 (필터용)
final userAllTagsProvider = FutureProvider<List<String>>((ref) async {
  final userId = _watchUserId(ref);
  if (userId == null) return [];

  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select('tags')
      .eq('user_id', userId)
      .isFilter('parent_record_id', null);

  final tags = (response as List)
      .expand((e) => (e['tags'] as List?)?.cast<String>() ?? <String>[])
      .toSet()
      .toList()
    ..sort();

  return tags;
});

/// 서버에 업로드되지 않은 로컬 전용 영상 레코드 조회
final localOnlyRecordsProvider =
    FutureProvider<List<ClimbingRecord>>((ref) async {
  final userId = _watchUserId(ref);
  if (userId == null) return [];

  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select(_selectWithGym)
      .eq('user_id', userId)
      .like('video_path', '/%')
      .isFilter('parent_record_id', null)
      .order('recorded_at', ascending: false);

  return (response as List)
      .map((e) => ClimbingRecord.fromMap(e))
      .toList();
});

class RecordService {
  static final _supabase = SupabaseConfig.client;

  /// Google Place ID로 기존 gym 찾거나 새로 생성
  static Future<String> _findOrCreateGym(ClimbingGym gym) async {
    final userId = _supabase.auth.currentUser!.id;

    if (gym.googlePlaceId != null) {
      // google_place_id로 기존 gym 검색
      final existing = await _supabase
          .from('climbing_gyms')
          .select('id')
          .eq('google_place_id', gym.googlePlaceId!)
          .maybeSingle();

      if (existing != null) return existing['id'] as String;
    }

    // 새 gym 생성
    final inserted = await _supabase
        .from('climbing_gyms')
        .insert({
          ...gym.toInsertMap(),
          'created_by': userId,
        })
        .select('id')
        .single();

    return inserted['id'] as String;
  }

  /// 기록 저장 (영상은 로컬 경로로 보관)
  static Future<ClimbingRecord> saveRecord({
    required String videoPath,
    required String grade,
    required String difficultyColor,
    required String status,
    ClimbingGym? gym,
    String? thumbnailPath,
    List<String> tags = const [],
    int? videoDurationSeconds,
  }) async {
    final userId = _supabase.auth.currentUser!.id;

    String? resolvedGymId;
    if (gym != null) {
      resolvedGymId = await _findOrCreateGym(gym);
    }

    final record = ClimbingRecord(
      userId: userId,
      gymId: resolvedGymId,
      grade: grade,
      difficultyColor: difficultyColor,
      status: status,
      videoPath: videoPath,
      thumbnailPath: thumbnailPath,
      tags: tags,
      recordedAt: DateTime.now(),
      videoDurationSeconds: videoDurationSeconds,
    );

    final response = await _supabase
        .from('climbing_records')
        .insert(record.toInsertMap())
        .select(_selectWithGym)
        .single();

    return ClimbingRecord.fromMap(response);
  }

  /// 기록 수정
  static Future<ClimbingRecord> updateRecord({
    required String recordId,
    required String grade,
    required String difficultyColor,
    required String status,
    ClimbingGym? gym,
    List<String> tags = const [],
  }) async {
    String? resolvedGymId;
    if (gym != null) {
      resolvedGymId = await _findOrCreateGym(gym);
    }

    final response = await _supabase
        .from('climbing_records')
        .update({
          'grade': grade,
          'difficulty_color': difficultyColor,
          'status': status,
          'gym_id': resolvedGymId,
          'tags': tags,
        })
        .eq('id', recordId)
        .select(_selectWithGym)
        .single();

    return ClimbingRecord.fromMap(response);
  }

  /// 내보내기 영상 저장 (원본 기록의 메타데이터를 복사)
  static Future<ClimbingRecord> saveExport({
    required String parentRecordId,
    required ClimbingRecord parentRecord,
    required String videoPath,
    String? thumbnailPath,
    int? videoDurationSeconds,
  }) async {
    final userId = _supabase.auth.currentUser!.id;

    final record = ClimbingRecord(
      userId: userId,
      gymId: parentRecord.gymId,
      grade: parentRecord.grade,
      difficultyColor: parentRecord.difficultyColor,
      status: parentRecord.status,
      videoPath: videoPath,
      thumbnailPath: thumbnailPath,
      tags: parentRecord.tags,
      recordedAt: parentRecord.recordedAt,
      parentRecordId: parentRecordId,
      videoDurationSeconds: videoDurationSeconds,
    );

    final response = await _supabase
        .from('climbing_records')
        .insert(record.toInsertMap())
        .select(_selectWithGym)
        .single();

    return ClimbingRecord.fromMap(response);
  }

  /// 기록 삭제 (로컬 파일 + R2 리모트 파일도 함께 정리)
  static Future<void> deleteRecord(String recordId) async {
    final userId = _supabase.auth.currentUser?.id;

    // 1. 삭제 전 레코드 조회 (파일 경로 확보)
    final record = await _supabase
        .from('climbing_records')
        .select('video_path, thumbnail_path')
        .eq('id', recordId)
        .maybeSingle();

    // 2. 자식 레코드(내보내기 영상)도 파일 정리 후 삭제
    final children = await _supabase
        .from('climbing_records')
        .select('id, video_path, thumbnail_path')
        .eq('parent_record_id', recordId);
    for (final child in children as List) {
      await _deleteLocalFile(child['video_path'] as String?);
      await _deleteLocalFile(child['thumbnail_path'] as String?);
      // 자식 레코드의 R2 파일도 삭제
      if (userId != null) {
        try {
          await VideoUploadService.deleteRemoteFiles(
            userId: userId,
            recordId: child['id'] as String,
          );
        } catch (e) {
          debugPrint('자식 레코드 R2 삭제 실패: $e');
        }
      }
    }
    if ((children as List).isNotEmpty) {
      await _supabase
          .from('climbing_records')
          .delete()
          .eq('parent_record_id', recordId);
    }

    // 3. 본인 레코드의 로컬 파일 삭제
    if (record != null) {
      await _deleteLocalFile(record['video_path'] as String?);
      await _deleteLocalFile(record['thumbnail_path'] as String?);
    }

    // 4. R2 리모트 파일 삭제
    if (userId != null) {
      try {
        await VideoUploadService.deleteRemoteFiles(
          userId: userId,
          recordId: recordId,
        );
      } catch (e) {
        debugPrint('R2 삭제 실패: $e');
      }
    }

    // 5. DB 레코드 삭제
    await _supabase
        .from('climbing_records')
        .delete()
        .eq('id', recordId);
  }

  /// 로컬 파일 안전 삭제
  static Future<void> _deleteLocalFile(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
