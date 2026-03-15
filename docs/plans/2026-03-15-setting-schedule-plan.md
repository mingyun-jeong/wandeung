# 세팅일정 (Setting Schedule) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 사용자가 암장 세팅 공지 스크린샷을 올리면 GPT Vision으로 자동 파싱하여 캘린더에 세팅 일정을 보여주는 Beta 기능 구현

**Architecture:** Supabase Edge Function이 GPT Vision API를 호출하여 이미지 파싱 처리. Flutter 앱에 새 탭(세팅일정)을 추가하고, table_calendar로 일정을 캘린더 표시. 데이터는 gym_setting_schedules 테이블에 암장+월 단위로 저장.

**Tech Stack:** Flutter/Riverpod, Supabase (Edge Functions, Storage, Postgres), GPT-4o mini Vision API, table_calendar, image_picker

---

### Task 1: DB 마이그레이션 — gym_setting_schedules 테이블 생성

**Files:**
- Create: `supabase/migrations/018_gym_setting_schedules.sql`

**Step 1: 마이그레이션 SQL 작성**

```sql
-- 세팅일정 테이블
CREATE TABLE IF NOT EXISTS gym_setting_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_name TEXT NOT NULL,
  gym_brand TEXT,
  year_month TEXT NOT NULL,
  sectors JSONB NOT NULL DEFAULT '[]'::jsonb,
  source_image_url TEXT,
  submitted_by UUID REFERENCES auth.users ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'approved',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(gym_name, year_month)
);

-- RLS 활성화
ALTER TABLE gym_setting_schedules ENABLE ROW LEVEL SECURITY;

-- 모든 인증 사용자가 조회 가능
CREATE POLICY "Anyone can read setting schedules"
  ON gym_setting_schedules FOR SELECT
  TO authenticated
  USING (true);

-- 인증 사용자가 등록 가능
CREATE POLICY "Authenticated users can insert setting schedules"
  ON gym_setting_schedules FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = submitted_by);

-- 본인이 등록한 것만 수정 가능
CREATE POLICY "Users can update own setting schedules"
  ON gym_setting_schedules FOR UPDATE
  TO authenticated
  USING (auth.uid() = submitted_by);

-- 본인이 등록한 것만 삭제 가능
CREATE POLICY "Users can delete own setting schedules"
  ON gym_setting_schedules FOR DELETE
  TO authenticated
  USING (auth.uid() = submitted_by);

-- 인덱스
CREATE INDEX idx_setting_schedules_year_month ON gym_setting_schedules(year_month);
CREATE INDEX idx_setting_schedules_gym_name ON gym_setting_schedules(gym_name);

-- 기여자 테이블
CREATE TABLE IF NOT EXISTS setting_schedule_contributors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  schedule_id UUID NOT NULL REFERENCES gym_setting_schedules ON DELETE CASCADE,
  contributed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, schedule_id)
);

ALTER TABLE setting_schedule_contributors ENABLE ROW LEVEL SECURITY;

-- 모든 인증 사용자가 기여자 조회 가능
CREATE POLICY "Anyone can read contributors"
  ON setting_schedule_contributors FOR SELECT
  TO authenticated
  USING (true);

-- 인증 사용자가 기여 등록 가능
CREATE POLICY "Authenticated users can insert contributors"
  ON setting_schedule_contributors FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX idx_contributors_schedule_id ON setting_schedule_contributors(schedule_id);
CREATE INDEX idx_contributors_user_id ON setting_schedule_contributors(user_id);
```

**Step 2: Supabase에 마이그레이션 적용**

Run: `supabase db push` (또는 Supabase Dashboard에서 SQL 실행)

**Step 3: Commit**

```bash
git add supabase/migrations/018_gym_setting_schedules.sql
git commit -m "feat: add gym_setting_schedules table migration"
```

---

### Task 2: Supabase Edge Function — parse-setting-schedule

**Files:**
- Create: `supabase/functions/parse-setting-schedule/index.ts`

**Step 1: Edge Function 작성**

```typescript
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  try {
    // 인증 확인
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return Response.json(
        { error: "인증이 필요합니다." },
        { status: 401, headers: corsHeaders },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return Response.json(
        { error: "인증 실패" },
        { status: 401, headers: corsHeaders },
      );
    }

    // multipart에서 이미지 추출
    const formData = await req.formData();
    const imageFile = formData.get("image") as File | null;
    if (!imageFile) {
      return Response.json(
        { error: "이미지가 필요합니다." },
        { status: 400, headers: corsHeaders },
      );
    }

    // 이미지를 base64로 변환
    const arrayBuffer = await imageFile.arrayBuffer();
    const base64Image = btoa(
      String.fromCharCode(...new Uint8Array(arrayBuffer)),
    );
    const mimeType = imageFile.type || "image/jpeg";

    // GPT Vision API 호출
    const openaiApiKey = Deno.env.get("OPENAI_API_KEY");
    if (!openaiApiKey) {
      return Response.json(
        { error: "서버 설정 오류 (API key missing)" },
        { status: 500, headers: corsHeaders },
      );
    }

    const gptResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${openaiApiKey}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: `실내 클라이밍장 세팅 일정 이미지를 분석하는 AI입니다.
반드시 아래 JSON 형식으로만 응답하세요. JSON 외 다른 텍스트는 포함하지 마세요.

{
  "gym_name": "암장명 (지점 포함)",
  "gym_brand": "브랜드명 (없으면 null)",
  "year_month": "YYYY-MM",
  "sectors": [
    {"name": "섹터명", "dates": ["YYYY-MM-DD"]}
  ]
}

규칙:
- 이미지에서 암장 이름, 월, 섹터별 세팅 날짜를 추출하세요
- 색상으로 구분된 섹터는 맵/범례에서 색상-섹터 매칭을 시도하세요
- 연도가 명시되지 않으면 현재 연도(2026)를 사용하세요
- 확실하지 않은 정보는 빈 값으로 남겨주세요
- sectors의 dates는 반드시 YYYY-MM-DD 형식이어야 합니다`,
          },
          {
            role: "user",
            content: [
              {
                type: "image_url",
                image_url: {
                  url: `data:${mimeType};base64,${base64Image}`,
                },
              },
              {
                type: "text",
                text: "이 클라이밍장 세팅 일정 이미지를 분석해주세요.",
              },
            ],
          },
        ],
        max_tokens: 1000,
        temperature: 0,
      }),
    });

    if (!gptResponse.ok) {
      const errorBody = await gptResponse.text();
      console.error("GPT API error:", errorBody);
      return Response.json(
        { error: "AI 분석 실패. 잠시 후 다시 시도해주세요." },
        { status: 502, headers: corsHeaders },
      );
    }

    const gptData = await gptResponse.json();
    const content = gptData.choices?.[0]?.message?.content ?? "";

    // JSON 파싱 (코드블록 감싸기 대응)
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      return Response.json(
        { error: "AI가 일정을 인식하지 못했습니다. 다른 이미지를 시도해주세요." },
        { status: 422, headers: corsHeaders },
      );
    }

    const parsed = JSON.parse(jsonMatch[0]);

    return Response.json(parsed, { headers: corsHeaders });
  } catch (e) {
    console.error("Error:", e);
    return Response.json(
      { error: `처리 실패: ${e.message}` },
      { status: 500, headers: corsHeaders },
    );
  }
});
```

**Step 2: Commit**

```bash
git add supabase/functions/parse-setting-schedule/index.ts
git commit -m "feat: add parse-setting-schedule edge function with GPT Vision"
```

---

### Task 3: Supabase Edge Function — submit-setting-schedule

**Files:**
- Create: `supabase/functions/submit-setting-schedule/index.ts`

**Step 1: Edge Function 작성**

```typescript
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return Response.json(
        { error: "인증이 필요합니다." },
        { status: 401, headers: corsHeaders },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return Response.json(
        { error: "인증 실패" },
        { status: 401, headers: corsHeaders },
      );
    }

    const body = await req.json();
    const { gym_name, gym_brand, year_month, sectors, source_image_base64 } = body;

    if (!gym_name || !year_month || !sectors) {
      return Response.json(
        { error: "필수 항목이 누락되었습니다." },
        { status: 400, headers: corsHeaders },
      );
    }

    // 이미지를 Storage에 업로드 (있으면)
    let sourceImageUrl: string | null = null;
    if (source_image_base64) {
      const adminClient = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      );

      const fileName = `setting-schedules/${user.id}/${Date.now()}.jpg`;
      const imageBytes = Uint8Array.from(atob(source_image_base64), (c) => c.charCodeAt(0));

      const { error: uploadError } = await adminClient.storage
        .from("climbing-videos")
        .upload(fileName, imageBytes, {
          contentType: "image/jpeg",
          upsert: true,
        });

      if (!uploadError) {
        sourceImageUrl = fileName;
      }
    }

    // Upsert: 같은 gym_name + year_month이면 업데이트
    const { data, error } = await supabase
      .from("gym_setting_schedules")
      .upsert(
        {
          gym_name,
          gym_brand: gym_brand || null,
          year_month,
          sectors,
          source_image_url: sourceImageUrl,
          submitted_by: user.id,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "gym_name,year_month" },
      )
      .select()
      .single();

    if (error) {
      console.error("DB error:", error);
      return Response.json(
        { error: `저장 실패: ${error.message}` },
        { status: 500, headers: corsHeaders },
      );
    }

    // 기여자 기록
    await supabase
      .from("setting_schedule_contributors")
      .upsert(
        { user_id: user.id, schedule_id: data.id },
        { onConflict: "user_id,schedule_id" },
      );

    return Response.json(data, { headers: corsHeaders });
  } catch (e) {
    console.error("Error:", e);
    return Response.json(
      { error: `처리 실패: ${e.message}` },
      { status: 500, headers: corsHeaders },
    );
  }
});
```

**Step 2: Commit**

```bash
git add supabase/functions/submit-setting-schedule/index.ts
git commit -m "feat: add submit-setting-schedule edge function"
```

---

### Task 4: Flutter 모델 — SettingSchedule

**Files:**
- Create: `lib/models/setting_schedule.dart`

**Step 1: 모델 클래스 작성**

```dart
class SettingSector {
  final String name;
  final List<DateTime> dates;

  const SettingSector({required this.name, required this.dates});

  factory SettingSector.fromMap(Map<String, dynamic> map) {
    return SettingSector(
      name: map['name'] as String,
      dates: (map['dates'] as List<dynamic>)
          .map((d) => DateTime.parse(d as String))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'dates': dates.map((d) => d.toIso8601String().substring(0, 10)).toList(),
      };
}

class SettingSchedule {
  final String? id;
  final String gymName;
  final String? gymBrand;
  final String yearMonth;
  final List<SettingSector> sectors;
  final String? sourceImageUrl;
  final String? submittedBy;
  final String? submittedByEmail; // 기여자 이메일 (조인)
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SettingSchedule({
    this.id,
    required this.gymName,
    this.gymBrand,
    required this.yearMonth,
    required this.sectors,
    this.sourceImageUrl,
    this.submittedBy,
    this.submittedByEmail,
    this.status = 'approved',
    this.createdAt,
    this.updatedAt,
  });

  /// 기여자 표시명 (이메일 앞 2글자 + "님")
  String? get contributorDisplayName {
    if (submittedByEmail == null || submittedByEmail!.isEmpty) return null;
    final prefix = submittedByEmail!.substring(
        0, submittedByEmail!.length >= 2 ? 2 : submittedByEmail!.length);
    return '$prefix님';
  }

  factory SettingSchedule.fromMap(Map<String, dynamic> map) {
    // submitted_by가 조인된 경우 이메일 추출
    String? email;
    final submittedByRaw = map['submitted_by'];
    String? submittedById;
    if (submittedByRaw is Map) {
      submittedById = submittedByRaw['id'] as String?;
      email = submittedByRaw['email'] as String?;
    } else {
      submittedById = submittedByRaw as String?;
    }

    return SettingSchedule(
      id: map['id'] as String?,
      gymName: map['gym_name'] as String,
      gymBrand: map['gym_brand'] as String?,
      yearMonth: map['year_month'] as String,
      sectors: (map['sectors'] as List<dynamic>)
          .map((s) => SettingSector.fromMap(s as Map<String, dynamic>))
          .toList(),
      sourceImageUrl: map['source_image_url'] as String?,
      submittedBy: submittedById,
      submittedByEmail: email,
      status: map['status'] as String? ?? 'approved',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// 이 스케줄에 포함된 모든 세팅 날짜를 flat하게 반환
  Set<DateTime> get allDates {
    final result = <DateTime>{};
    for (final sector in sectors) {
      for (final date in sector.dates) {
        result.add(DateTime(date.year, date.month, date.day));
      }
    }
    return result;
  }

  /// 특정 날짜에 세팅되는 섹터 목록
  List<SettingSector> sectorsOnDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return sectors.where((s) => s.dates.any((d) =>
        DateTime(d.year, d.month, d.day) == normalized)).toList();
  }
}
```

**Step 2: Commit**

```bash
git add lib/models/setting_schedule.dart
git commit -m "feat: add SettingSchedule and SettingSector models"
```

---

### Task 5: Flutter Provider — setting_schedule_provider.dart

**Files:**
- Create: `lib/providers/setting_schedule_provider.dart`

**Step 1: Provider 작성**

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/setting_schedule.dart';

/// 선택된 월
final scheduleMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// 선택된 날짜
final scheduleSelectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// 암장 검색 필터 (null이면 전체)
final scheduleGymFilterProvider = StateProvider<String?>((ref) => null);

/// 암장 검색 쿼리
final scheduleSearchQueryProvider = StateProvider<String>((ref) => '');

/// 특정 월의 세팅 일정 목록 (암장 필터 적용)
final settingSchedulesProvider =
    FutureProvider.family<List<SettingSchedule>, DateTime>((ref, month) async {
  final yearMonth =
      '${month.year}-${month.month.toString().padLeft(2, '0')}';
  final gymFilter = ref.watch(scheduleGymFilterProvider);

  var query = SupabaseConfig.client
      .from('gym_setting_schedules')
      .select('*, submitted_by_user:submitted_by(id, email)')
      .eq('year_month', yearMonth)
      .eq('status', 'approved');

  if (gymFilter != null) {
    query = query.eq('gym_name', gymFilter);
  }

  final response = await query.order('gym_name');

  return (response as List)
      .map((e) {
        final map = Map<String, dynamic>.from(e as Map<String, dynamic>);
        // 조인 결과를 submitted_by로 매핑
        if (map['submitted_by_user'] != null) {
          map['submitted_by'] = map['submitted_by_user'];
          map.remove('submitted_by_user');
        }
        return SettingSchedule.fromMap(map);
      })
      .toList();
});

/// 특정 월에 세팅이 있는 날짜 → 해당 날짜의 스케줄 수 매핑
final settingDateCountsProvider =
    Provider.family<Map<DateTime, int>, DateTime>((ref, month) {
  final schedulesAsync = ref.watch(settingSchedulesProvider(month));
  final schedules = schedulesAsync.valueOrNull ?? [];

  final counts = <DateTime, int>{};
  for (final schedule in schedules) {
    for (final date in schedule.allDates) {
      counts[date] = (counts[date] ?? 0) + 1;
    }
  }
  return counts;
});

/// 특정 날짜의 세팅 일정 (암장 + 해당 섹터)
final settingSchedulesOnDateProvider =
    Provider.family<List<({SettingSchedule schedule, List<SettingSector> sectors})>, DateTime>(
        (ref, date) {
  final month = DateTime(date.year, date.month);
  final schedulesAsync = ref.watch(settingSchedulesProvider(month));
  final schedules = schedulesAsync.valueOrNull ?? [];

  final result = <({SettingSchedule schedule, List<SettingSector> sectors})>[];
  for (final schedule in schedules) {
    final sectors = schedule.sectorsOnDate(date);
    if (sectors.isNotEmpty) {
      result.add((schedule: schedule, sectors: sectors));
    }
  }
  return result;
});

/// Edge Function 호출 서비스
class SettingScheduleService {
  /// 이미지를 Edge Function에 보내서 GPT Vision 파싱
  static Future<Map<String, dynamic>> parseImage(File imageFile) async {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session == null) throw Exception('로그인이 필요합니다.');

    final uri = Uri.parse(
      '${SupabaseConfig.client.rest.url.replaceAll('/rest/v1', '/functions/v1')}/parse-setting-schedule',
    );

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${session.accessToken}'
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();
    final data = jsonDecode(responseBody) as Map<String, dynamic>;

    if (streamedResponse.statusCode != 200) {
      throw Exception(data['error'] ?? 'AI 분석에 실패했습니다.');
    }

    return data;
  }

  /// 확정된 세팅일정을 Edge Function으로 제출
  static Future<SettingSchedule> submit({
    required String gymName,
    String? gymBrand,
    required String yearMonth,
    required List<Map<String, dynamic>> sectors,
    String? imageBase64,
  }) async {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session == null) throw Exception('로그인이 필요합니다.');

    final uri = Uri.parse(
      '${SupabaseConfig.client.rest.url.replaceAll('/rest/v1', '/functions/v1')}/submit-setting-schedule',
    );

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: jsonEncode({
        'gym_name': gymName,
        'gym_brand': gymBrand,
        'year_month': yearMonth,
        'sectors': sectors,
        'source_image_base64': imageBase64,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? '저장에 실패했습니다.');
    }

    return SettingSchedule.fromMap(data);
  }
}
```

**Step 2: Commit**

```bash
git add lib/providers/setting_schedule_provider.dart
git commit -m "feat: add setting schedule providers and service"
```

---

### Task 6: 세팅일정 탭 화면 — SettingScheduleTabScreen

**Files:**
- Create: `lib/screens/setting_schedule_tab_screen.dart`

**Step 1: 화면 작성**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../app.dart';
import '../models/setting_schedule.dart';
import '../providers/gym_provider.dart';
import '../providers/setting_schedule_provider.dart';
import '../widgets/wandeung_app_bar.dart';
import 'setting_schedule_submit_screen.dart';

class SettingScheduleTabScreen extends ConsumerStatefulWidget {
  const SettingScheduleTabScreen({super.key});

  @override
  ConsumerState<SettingScheduleTabScreen> createState() =>
      _SettingScheduleTabScreenState();
}

class _SettingScheduleTabScreenState
    extends ConsumerState<SettingScheduleTabScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilter() {
    _searchController.clear();
    ref.read(scheduleGymFilterProvider.notifier).state = null;
    ref.read(scheduleSearchQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final focusedMonth = ref.watch(scheduleMonthProvider);
    final selectedDate = ref.watch(scheduleSelectedDateProvider);
    final gymFilter = ref.watch(scheduleGymFilterProvider);
    final dateCounts = ref.watch(settingDateCountsProvider(
        DateTime(focusedMonth.year, focusedMonth.month)));
    final schedulesOnDate = ref.watch(settingSchedulesOnDateProvider(selectedDate));
    final schedulesAsync = ref.watch(settingSchedulesProvider(
        DateTime(focusedMonth.year, focusedMonth.month)));
    final colorScheme = Theme.of(context).colorScheme;

    // 암장 필터가 있고, 해당 월 데이터가 비어있는지 확인
    final isFilteredEmpty = gymFilter != null &&
        (schedulesAsync.valueOrNull?.isEmpty ?? true);

    return Scaffold(
      appBar: WandeungAppBar(
        title: '세팅일정',
        extraActions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: WandeungColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Beta',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: WandeungColors.accent,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 암장 검색 바
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: GestureDetector(
              onTap: () => _showGymSearch(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: gymFilter != null
                        ? colorScheme.primary
                        : colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 20,
                        color: colorScheme.onSurface.withOpacity(0.5)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        gymFilter ?? '암장 검색...',
                        style: TextStyle(
                          fontSize: 14,
                          color: gymFilter != null
                              ? colorScheme.onSurface
                              : colorScheme.onSurface.withOpacity(0.5),
                          fontWeight: gymFilter != null
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (gymFilter != null)
                      GestureDetector(
                        onTap: _clearFilter,
                        child: Icon(Icons.close, size: 18,
                            color: colorScheme.onSurface.withOpacity(0.5)),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 암장 필터 + 데이터 없음 → 공유 유도
          if (isFilteredEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_busy_outlined,
                        size: 48,
                        color: colorScheme.onSurface.withOpacity(0.2)),
                    const SizedBox(height: 12),
                    Text(
                      '$gymFilter의\n등록된 세팅일정이 없습니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SettingScheduleSubmitScreen(
                              initialGymName: gymFilter,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                      label: const Text('세팅일정 공유해주기'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            TableCalendar(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: focusedMonth,
              selectedDayPredicate: (day) => isSameDay(day, selectedDate),
              onDaySelected: (selected, focused) {
                ref.read(scheduleSelectedDateProvider.notifier).state = selected;
                ref.read(scheduleMonthProvider.notifier).state = focused;
              },
              onPageChanged: (focused) {
                ref.read(scheduleMonthProvider.notifier).state = focused;
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  final normalized = DateTime(day.year, day.month, day.day);
                  final count = dateCounts[normalized] ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: WandeungColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
                selectedDecoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: TextStyle(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(color: colorScheme.error.withOpacity(0.7)),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                leftChevronIcon: Icon(Icons.chevron_left_rounded, color: colorScheme.onSurface),
                rightChevronIcon: Icon(Icons.chevron_right_rounded, color: colorScheme.onSurface),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
                weekendStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.error.withOpacity(0.5),
                ),
              ),
              eventLoader: (_) => [],
            ),
            const Divider(height: 1, color: Color(0xFFE8ECF0)),
            // 선택 날짜 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    '${selectedDate.month}월 ${selectedDate.day}일',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _weekdayLabel(selectedDate.weekday),
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            // 세팅 목록
            Expanded(
              child: schedulesOnDate.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_busy_outlined,
                              size: 40,
                              color: colorScheme.onSurface.withOpacity(0.2)),
                          const SizedBox(height: 10),
                          Text(
                            '이 날의 세팅 일정이 없습니다',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: schedulesOnDate.length,
                      itemBuilder: (_, i) {
                        final entry = schedulesOnDate[i];
                        return _SettingCard(
                          schedule: entry.schedule,
                          sectors: entry.sectors,
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
      floatingActionButton: isFilteredEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingScheduleSubmitScreen(
                      initialGymName: gymFilter,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('세팅일정 등록'),
            ),
    );
  }

  /// 암장 검색 바텀시트 (기존 GymSelectionSheet 패턴 재사용)
  void _showGymSearch(BuildContext context) {
    // gym_provider의 searchQueryProvider와 gymsProvider를 활용
    // 검색 결과에서 암장을 선택하면 scheduleGymFilterProvider에 세팅
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) => _GymSearchSheet(
          scrollController: scrollController,
          onSelected: (gymName) {
            ref.read(scheduleGymFilterProvider.notifier).state = gymName;
            _searchController.text = gymName;
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  String _weekdayLabel(int weekday) {
    const labels = ['', '월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    return labels[weekday];
  }
}

/// 암장 검색 바텀시트
class _GymSearchSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final ValueChanged<String> onSelected;

  const _GymSearchSheet({
    required this.scrollController,
    required this.onSelected,
  });

  @override
  ConsumerState<_GymSearchSheet> createState() => _GymSearchSheetState();
}

class _GymSearchSheetState extends ConsumerState<_GymSearchSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 기존 gym_provider의 searchQueryProvider 재사용
    final gyms = ref.watch(gymsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '암장 이름으로 검색',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              isDense: true,
            ),
            onChanged: (value) {
              ref.read(searchQueryProvider.notifier).state = value;
            },
          ),
        ),
        Expanded(
          child: gyms.when(
            data: (list) => ListView.builder(
              controller: widget.scrollController,
              itemCount: list.length,
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(list[i].name),
                subtitle: list[i].address != null
                    ? Text(list[i].address!,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis)
                    : null,
                onTap: () => widget.onSelected(list[i].name),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('검색 실패: $e')),
          ),
        ),
      ],
    );
  }
}

class _SettingCard extends StatelessWidget {
  final SettingSchedule schedule;
  final List<SettingSector> sectors;

  const _SettingCard({required this.schedule, required this.sectors});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 18, color: WandeungColors.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    schedule.gymName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...sectors.map((sector) => Padding(
                  padding: const EdgeInsets.only(left: 24, bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${sector.name} 세팅',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                )),
            // 기여자 표시
            if (schedule.contributorDisplayName != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Text(
                  '정보 공유자: ${schedule.contributorDisplayName}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/screens/setting_schedule_tab_screen.dart
git commit -m "feat: add setting schedule tab screen with calendar"
```

---

### Task 7: 세팅일정 등록 화면 — SettingScheduleSubmitScreen

**Files:**
- Create: `lib/screens/setting_schedule_submit_screen.dart`

**Step 1: 등록 화면 작성**

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../app.dart';
import '../providers/setting_schedule_provider.dart';

class SettingScheduleSubmitScreen extends ConsumerStatefulWidget {
  final String? initialGymName;

  const SettingScheduleSubmitScreen({super.key, this.initialGymName});

  @override
  ConsumerState<SettingScheduleSubmitScreen> createState() =>
      _SettingScheduleSubmitScreenState();
}

class _SettingScheduleSubmitScreenState
    extends ConsumerState<SettingScheduleSubmitScreen> {
  File? _imageFile;
  bool _isParsing = false;
  bool _isSubmitting = false;
  String? _error;

  // 파싱 결과 (수정 가능)
  final _gymNameController = TextEditingController();
  String? _gymBrand;
  String _yearMonth = '';
  List<_SectorEntry> _sectors = [];

  bool get _hasParsedResult => _gymNameController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.initialGymName != null) {
      _gymNameController.text = widget.initialGymName!;
    }
  }

  @override
  void dispose() {
    _gymNameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndParse() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _imageFile = File(picked.path);
      _isParsing = true;
      _error = null;
    });

    try {
      final result = await SettingScheduleService.parseImage(_imageFile!);

      setState(() {
        _gymNameController.text = result['gym_name'] as String? ?? '';
        _gymBrand = result['gym_brand'] as String?;
        _yearMonth = result['year_month'] as String? ?? '';
        _sectors = (result['sectors'] as List<dynamic>?)
                ?.map((s) => _SectorEntry(
                      nameController:
                          TextEditingController(text: s['name'] as String? ?? ''),
                      dates: (s['dates'] as List<dynamic>?)
                              ?.map((d) => d as String)
                              .toList() ??
                          [],
                    ))
                .toList() ??
            [];
        _isParsing = false;
      });
    } catch (e) {
      setState(() {
        _isParsing = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _submit() async {
    if (_gymNameController.text.isEmpty || _yearMonth.isEmpty) {
      setState(() => _error = '암장명과 월을 입력해주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      String? imageBase64;
      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        imageBase64 = base64Encode(bytes);
      }

      final sectors = _sectors
          .where((s) => s.nameController.text.isNotEmpty && s.dates.isNotEmpty)
          .map((s) => {
                'name': s.nameController.text,
                'dates': s.dates,
              })
          .toList();

      await SettingScheduleService.submit(
        gymName: _gymNameController.text,
        gymBrand: _gymBrand,
        yearMonth: _yearMonth,
        sectors: sectors,
        imageBase64: imageBase64,
      );

      // 캐시 무효화
      final month = DateTime(
        int.parse(_yearMonth.split('-')[0]),
        int.parse(_yearMonth.split('-')[1]),
      );
      ref.invalidate(settingSchedulesProvider(month));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('세팅일정이 등록되었습니다!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('세팅일정 등록')),
      body: _isParsing
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('AI가 일정을 분석중...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 이미지 선택 영역
                  if (_imageFile == null)
                    GestureDetector(
                      onTap: _pickAndParse,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 48,
                                color: colorScheme.onSurface.withOpacity(0.4)),
                            const SizedBox(height: 8),
                            Text(
                              '세팅일정 스크린샷을 선택하세요',
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_imageFile!, height: 200,
                              width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton.filled(
                            onPressed: _pickAndParse,
                            icon: const Icon(Icons.refresh, size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_error!,
                          style: TextStyle(color: colorScheme.onErrorContainer,
                              fontSize: 13)),
                    ),
                  ],

                  if (_hasParsedResult) ...[
                    const SizedBox(height: 20),
                    const Text('분석 결과',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('잘못된 부분은 수정해주세요',
                        style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withOpacity(0.5))),
                    const SizedBox(height: 16),

                    // 암장명
                    TextField(
                      controller: _gymNameController,
                      decoration: const InputDecoration(
                        labelText: '암장',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 월
                    TextField(
                      controller: TextEditingController(text: _yearMonth),
                      onChanged: (v) => _yearMonth = v,
                      decoration: const InputDecoration(
                        labelText: '월 (YYYY-MM)',
                        border: OutlineInputBorder(),
                        hintText: '2026-03',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 섹터 목록
                    Row(
                      children: [
                        const Text('섹터별 세팅일정',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _sectors.add(_SectorEntry(
                                nameController: TextEditingController(),
                                dates: [],
                              ));
                            });
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('섹터 추가'),
                        ),
                      ],
                    ),

                    ..._sectors.asMap().entries.map((entry) {
                      final i = entry.key;
                      final sector = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: sector.nameController,
                                      decoration: const InputDecoration(
                                        labelText: '섹터명',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() => _sectors.removeAt(i));
                                    },
                                    icon: Icon(Icons.delete_outline,
                                        color: colorScheme.error, size: 20),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                children: [
                                  ...sector.dates.map((d) => Chip(
                                        label: Text(d, style: const TextStyle(fontSize: 12)),
                                        onDeleted: () {
                                          setState(() => sector.dates.remove(d));
                                        },
                                      )),
                                  ActionChip(
                                    label: const Text('+ 날짜',
                                        style: TextStyle(fontSize: 12)),
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2030),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          sector.dates.add(picked
                                              .toIso8601String()
                                              .substring(0, 10));
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('등록하기',
                              style: TextStyle(fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _SectorEntry {
  final TextEditingController nameController;
  final List<String> dates;

  _SectorEntry({required this.nameController, required this.dates});
}
```

**Step 2: Commit**

```bash
git add lib/screens/setting_schedule_submit_screen.dart
git commit -m "feat: add setting schedule submit screen with image parsing"
```

---

### Task 8: 하단 탭에 세팅일정 메뉴 추가

**Files:**
- Modify: `lib/screens/main_shell_screen.dart`

**Step 1: 세팅일정 탭 추가**

Import 추가 (파일 상단):
```dart
import 'setting_schedule_tab_screen.dart';
```

IndexedStack children에 추가:
```dart
children: const [
  HomeTabScreen(),
  RecordsTabScreen(),
  CameraTabScreen(),
  StatsTabScreen(),
  SettingScheduleTabScreen(),  // 추가
],
```

NavigationBar destinations에 추가:
```dart
NavigationDestination(
  icon: Badge(
    label: Text('Beta', style: TextStyle(fontSize: 8)),
    backgroundColor: WandeungColors.accent,
    child: Icon(Icons.calendar_month_outlined),
  ),
  selectedIcon: Badge(
    label: Text('Beta', style: TextStyle(fontSize: 8)),
    backgroundColor: WandeungColors.accent,
    child: Icon(Icons.calendar_month_rounded),
  ),
  label: '세팅일정',
),
```

**Step 2: flutter analyze 실행**

Run: `cd wandeung && flutter analyze`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/screens/main_shell_screen.dart
git commit -m "feat: add setting schedule tab to bottom navigation"
```

---

### Task 9: image_picker 의존성 확인

**Files:**
- Check: `pubspec.yaml`

**Step 1: image_picker가 이미 있는지 확인**

`pubspec.yaml`에 `image_picker`가 없으면 추가:

```yaml
dependencies:
  image_picker: ^1.0.0
```

그리고 `http` 패키지도 확인:
```yaml
dependencies:
  http: ^1.0.0
```

Run: `cd wandeung && flutter pub get`

**Step 2: Commit (변경이 있으면)**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add image_picker and http dependencies"
```

---

### Task 10: Edge Function 배포 및 환경변수 설정

**Step 1: Supabase에 OPENAI_API_KEY 시크릿 등록**

```bash
supabase secrets set OPENAI_API_KEY=<your-openai-api-key>
```

**Step 2: Edge Function 배포**

```bash
supabase functions deploy parse-setting-schedule
supabase functions deploy submit-setting-schedule
```

**Step 3: 수동 테스트**

1. 앱 실행
2. 세팅일정 탭 진입
3. FAB 버튼 탭 → 갤러리에서 세팅일정 스크린샷 선택
4. AI 분석 결과 확인
5. 필요시 수정 후 등록
6. 캘린더에 반영 확인

**Step 4: Commit (최종)**

```bash
git add -A
git commit -m "feat: complete setting schedule beta feature"
```
