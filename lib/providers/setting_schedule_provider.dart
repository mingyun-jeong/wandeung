import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/climbing_gym.dart';
import '../models/gym_setting_schedule.dart';
import 'auth_provider.dart';

// ─── State Providers ─────────────────────────────────────────────────────────

/// 세팅일정 탭에서 선택된 gym_id (null이면 전체)
final settingGymFilterProvider = StateProvider<String?>((ref) => null);

/// 세팅일정 탭에서 선택된 암장명 (표시용)
final settingGymFilterNameProvider = StateProvider<String?>((ref) => null);

/// 세팅일정 탭 캘린더 포커스 월
final settingFocusedMonthProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

/// 세팅일정 탭 선택된 날짜
final settingSelectedDateProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

// ─── Data Providers ──────────────────────────────────────────────────────────

/// 특정 월(year_month)의 세팅일정 목록 (암장 필터 적용)
/// climbing_gyms JOIN으로 gym name을 가져옴
final settingSchedulesProvider = FutureProvider.family<
    List<GymSettingSchedule>, String>((ref, yearMonth) async {
  final gymIdFilter = ref.watch(settingGymFilterProvider);

  var query = SupabaseConfig.client
      .from('gym_setting_schedules')
      .select('*, climbing_gyms(name)')
      .eq('year_month', yearMonth)
      .eq('status', 'approved');

  if (gymIdFilter != null) {
    query = query.eq('gym_id', gymIdFilter);
  }

  final data = await query.order('created_at');

  final schedules =
      (data as List).map((m) => GymSettingSchedule.fromMap(m)).toList();

  // submitted_by UUID → email 매핑
  final userIds = schedules
      .where((s) => s.submittedBy != null)
      .map((s) => s.submittedBy!)
      .toSet()
      .toList();

  if (userIds.isEmpty) return schedules;

  try {
    final emailMap = await SettingScheduleService.fetchUserEmails(userIds);
    return schedules.map((s) {
      if (s.submittedBy != null && emailMap.containsKey(s.submittedBy)) {
        final map = s.toInsertMap();
        map['id'] = s.id;
        map['created_at'] = s.createdAt?.toIso8601String();
        map['updated_at'] = s.updatedAt?.toIso8601String();
        map['submitted_by'] = s.submittedBy;
        map['submitted_by_email'] = emailMap[s.submittedBy];
        map['gym_name'] = s.gymName;
        return GymSettingSchedule.fromMap(map);
      }
      return s;
    }).toList();
  } catch (_) {
    return schedules;
  }
});

/// 내 암장의 이번 주 세팅일정 (홈 화면용)
/// 즐겨찾기 암장의 이번달 스케줄에서 이번 주 날짜에 해당하는 항목만 반환
final weeklySettingSchedulesProvider =
    FutureProvider<List<({GymSettingSchedule schedule, List<SettingSector> sectors, String dateStr})>>((ref) async {
  // 즐겨찾기 암장 가져오기 (import 없이 직접 조회)
  final userId = ref.watch(authProvider).valueOrNull?.id;
  if (userId == null) return [];

  final favResponse = await SupabaseConfig.client
      .from('user_favorite_gyms')
      .select('gym_id')
      .eq('user_id', userId);
  final favoriteGymIds = (favResponse as List)
      .map((e) => e['gym_id'] as String)
      .toList();
  final hasFavorites = favoriteGymIds.isNotEmpty;

  // 이번 주 월~일 날짜 계산
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final sunday = monday.add(const Duration(days: 6));

  // 이번 주가 걸치는 월 목록 (월초/월말 경우 2개월)
  final months = <String>{};
  for (var d = monday; !d.isAfter(sunday); d = d.add(const Duration(days: 1))) {
    months.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
  }

  // 이번 주 날짜 문자열 세트
  final weekDates = <String>{};
  for (var d = monday; !d.isAfter(sunday); d = d.add(const Duration(days: 1))) {
    weekDates.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
  }

  // 즐겨찾기 암장 또는 전체 스케줄 조회
  final results = <({GymSettingSchedule schedule, List<SettingSector> sectors, String dateStr})>[];
  for (final ym in months) {
    var query = SupabaseConfig.client
        .from('gym_setting_schedules')
        .select('*, climbing_gyms(name)')
        .eq('year_month', ym)
        .eq('status', 'approved');

    if (hasFavorites) {
      query = query.inFilter('gym_id', favoriteGymIds);
    }

    final data = await query;

    for (final row in data as List) {
      final schedule = GymSettingSchedule.fromMap(row);
      for (final dateStr in weekDates) {
        final sectors = schedule.sectorsForDate(dateStr);
        if (sectors.isNotEmpty) {
          results.add((schedule: schedule, sectors: sectors, dateStr: dateStr));
        }
      }
    }
  }

  // 날짜순 정렬
  results.sort((a, b) => a.dateStr.compareTo(b.dateStr));
  return results;
});

// ─── Service ─────────────────────────────────────────────────────────────────

class SettingScheduleService {
  static final _supabase = SupabaseConfig.client;

  /// Google Places에서 선택한 gym을 climbing_gyms에 등록/조회하여 ID 반환
  static Future<String> findOrCreateGym(ClimbingGym gym) async {
    final userId = _supabase.auth.currentUser!.id;

    if (gym.googlePlaceId != null) {
      final existing = await _supabase
          .from('climbing_gyms')
          .select('id')
          .eq('google_place_id', gym.googlePlaceId!)
          .maybeSingle();

      if (existing != null) return existing['id'] as String;
    }

    final insertMap = {...gym.toInsertMap(), 'created_by': userId};

    final inserted = await _supabase
        .from('climbing_gyms')
        .insert(insertMap)
        .select('id')
        .single();

    return inserted['id'] as String;
  }

  /// 이미지를 Edge Function에 보내 GPT Vision으로 파싱
  static Future<GymSettingSchedule?> parseScheduleImage(File imageFile) async {
    final session = _supabase.auth.currentSession;
    if (session == null) return null;

    final url = '${_supabase.rest.url.replaceAll('/rest/v1', '')}'
        '/functions/v1/parse-setting-schedule';

    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers['Authorization'] = 'Bearer ${session.accessToken}';
    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      throw Exception('파싱 실패: $responseBody');
    }

    final parsed = jsonDecode(responseBody) as Map<String, dynamic>;
    return GymSettingSchedule(
      gymId: '', // 파싱 결과에는 gym_id 없음, 제출 시 설정
      gymName: parsed['gym_name'] as String? ?? '',
      yearMonth: parsed['year_month'] as String? ?? '',
      sectors: (parsed['sectors'] as List? ?? [])
          .map((s) => SettingSector.fromMap(s as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 세팅일정 제출: gym을 climbing_gyms에 등록 → Edge Function으로 일정 upsert
  static Future<GymSettingSchedule> submitSchedule({
    required ClimbingGym gym,
    required String yearMonth,
    required List<SettingSector> sectors,
    File? sourceImage,
  }) async {
    final session = _supabase.auth.currentSession;
    if (session == null) throw Exception('로그인이 필요합니다');

    final userId = _supabase.auth.currentUser!.id;

    // 1. climbing_gyms에 등록/조회
    final gymId = await findOrCreateGym(gym);

    // 2. Edge Function 호출
    String? sourceImageBase64;
    if (sourceImage != null) {
      final bytes = await sourceImage.readAsBytes();
      sourceImageBase64 = base64Encode(bytes);
    }

    final url = '${_supabase.rest.url.replaceAll('/rest/v1', '')}'
        '/functions/v1/submit-setting-schedule';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'gym_id': gymId,
        'year_month': yearMonth,
        'sectors': sectors.map((s) => s.toMap()).toList(),
        if (sourceImageBase64 != null)
          'source_image_base64': sourceImageBase64,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('등록 실패: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // 기여자 기록
    final scheduleId = data['id'] as String;
    await _supabase.from('setting_schedule_contributors').upsert(
      {
        'user_id': userId,
        'schedule_id': scheduleId,
      },
      onConflict: 'user_id,schedule_id',
    );

    data['gym_name'] = gym.name;
    return GymSettingSchedule.fromMap(data);
  }

  /// user IDs로 이메일 조회
  static Future<Map<String, String>> fetchUserEmails(
      List<String> userIds) async {
    final session = _supabase.auth.currentSession;
    if (session == null) return {};

    final url = '${_supabase.rest.url.replaceAll('/rest/v1', '')}'
        '/functions/v1/get-user-emails';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'user_ids': userIds}),
    );

    if (response.statusCode != 200) return {};

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data.map((k, v) => MapEntry(k, v as String));
  }
}
