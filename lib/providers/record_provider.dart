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
      .lte('recorded_at', lastDay.toIso8601String().split('T')[0]);

  return (response as List)
      .map((e) => DateTime.parse(e['recorded_at']))
      .toSet();
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
}
