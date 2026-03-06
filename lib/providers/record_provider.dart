import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/climbing_record.dart';

final recordsByDateProvider =
    FutureProvider.family<List<ClimbingRecord>, DateTime>((ref, date) async {
  final userId = SupabaseConfig.client.auth.currentUser!.id;
  final dateStr = date.toIso8601String().split('T')[0];

  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select()
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
  final userId = SupabaseConfig.client.auth.currentUser!.id;
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

/// 캘린더 배지용: 월별 날짜 → 기록 개수 맵
final recordCountsByDateProvider =
    FutureProvider.family<Map<DateTime, int>, DateTime>((ref, month) async {
  final userId = SupabaseConfig.client.auth.currentUser!.id;
  final firstDay = DateTime(month.year, month.month, 1);
  final lastDay = DateTime(month.year, month.month + 1, 0);

  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select('recorded_at')
      .eq('user_id', userId)
      .gte('recorded_at', firstDay.toIso8601String().split('T')[0])
      .lte('recorded_at', lastDay.toIso8601String().split('T')[0])
      .isFilter('parent_record_id', null);

  final counts = <DateTime, int>{};
  for (final row in response as List) {
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
      .select()
      .eq('parent_record_id', parentId)
      .order('created_at', ascending: false);

  return (response as List)
      .map((e) => ClimbingRecord.fromMap(e))
      .toList();
});

class RecordService {
  static final _supabase = SupabaseConfig.client;

  /// 기록 저장 (영상은 로컬 경로로 보관)
  static Future<ClimbingRecord> saveRecord({
    required String videoPath,
    required String grade,
    required String difficultyColor,
    required String status,
    String? gymId,
    String? gymName,
    String? thumbnailPath,
    List<String> tags = const [],
  }) async {
    final userId = _supabase.auth.currentUser!.id;

    final record = ClimbingRecord(
      userId: userId,
      gymId: gymId,
      gymName: gymName,
      grade: grade,
      difficultyColor: difficultyColor,
      status: status,
      videoPath: videoPath,
      thumbnailPath: thumbnailPath,
      tags: tags,
      recordedAt: DateTime.now(),
    );

    final response = await _supabase
        .from('climbing_records')
        .insert(record.toInsertMap())
        .select()
        .single();

    return ClimbingRecord.fromMap(response);
  }

  /// 기록 수정
  static Future<ClimbingRecord> updateRecord({
    required String recordId,
    required String grade,
    required String difficultyColor,
    required String status,
    String? gymId,
    String? gymName,
    List<String> tags = const [],
  }) async {
    final response = await _supabase
        .from('climbing_records')
        .update({
          'grade': grade,
          'difficulty_color': difficultyColor,
          'status': status,
          'gym_id': gymId,
          'gym_name': gymName,
          'tags': tags,
        })
        .eq('id', recordId)
        .select()
        .single();

    return ClimbingRecord.fromMap(response);
  }

  /// 내보내기 영상 저장 (원본 기록의 메타데이터를 복사)
  static Future<ClimbingRecord> saveExport({
    required String parentRecordId,
    required ClimbingRecord parentRecord,
    required String videoPath,
    String? thumbnailPath,
  }) async {
    final userId = _supabase.auth.currentUser!.id;

    final record = ClimbingRecord(
      userId: userId,
      gymId: parentRecord.gymId,
      gymName: parentRecord.gymName,
      grade: parentRecord.grade,
      difficultyColor: parentRecord.difficultyColor,
      status: parentRecord.status,
      videoPath: videoPath,
      thumbnailPath: thumbnailPath,
      tags: parentRecord.tags,
      recordedAt: parentRecord.recordedAt,
      parentRecordId: parentRecordId,
    );

    final response = await _supabase
        .from('climbing_records')
        .insert(record.toInsertMap())
        .select()
        .single();

    return ClimbingRecord.fromMap(response);
  }

  /// 기록 삭제
  static Future<void> deleteRecord(String recordId) async {
    await _supabase
        .from('climbing_records')
        .delete()
        .eq('id', recordId);
  }
}
