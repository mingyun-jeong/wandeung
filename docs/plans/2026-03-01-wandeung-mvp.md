# 완등 (Wandeung) - 클라이밍 기록 앱 MVP 구현 플랜

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 클라이밍 영상을 촬영하고, 등반 기록(난이도/암장/완등여부/태그)을 저장하며, 캘린더에서 기록을 조회할 수 있는 MVP 앱

**Architecture:** Flutter 크로스플랫폼 앱 + Supabase(Auth, PostgreSQL, Storage). Google OAuth 로그인 후 메인 화면에서 캘린더 기반 기록 조회, FAB(+) 버튼으로 영상 촬영 → 메타데이터 입력 → 저장 플로우.

**Tech Stack:**
- Frontend: Flutter 3.x, Dart
- Backend: Supabase (Auth, PostgreSQL, Storage)
- 주요 패키지: `supabase_flutter`, `google_sign_in`, `camera`, `video_player`, `geolocator`, `geocoding`, `table_calendar`, `flutter_riverpod`
- 타겟: iOS + Android

---

## Task 1: Flutter 프로젝트 초기 설정

**Files:**
- Create: `wandeung/` (Flutter 프로젝트 루트)
- Create: `wandeung/lib/main.dart`
- Create: `wandeung/lib/app.dart`
- Create: `wandeung/lib/config/supabase_config.dart`
- Create: `wandeung/lib/config/routes.dart`
- Create: `wandeung/lib/utils/constants.dart`

**Step 1: Flutter 프로젝트 생성**

```bash
flutter create wandeung --org com.wandeung --platforms ios,android
cd wandeung
```

**Step 2: 핵심 패키지 설치**

```bash
flutter pub add supabase_flutter google_sign_in camera video_player geolocator geocoding table_calendar flutter_riverpod image_picker path_provider intl
flutter pub add --dev flutter_lints
```

**Step 3: 프로젝트 디렉토리 구조 생성**

```
lib/
├── main.dart
├── app.dart
├── config/
│   ├── supabase_config.dart
│   └── routes.dart
├── models/
│   ├── climbing_record.dart
│   └── climbing_gym.dart
├── providers/
│   ├── auth_provider.dart
│   ├── record_provider.dart
│   ├── gym_provider.dart
│   └── camera_provider.dart
├── screens/
│   ├── login_screen.dart
│   ├── home_screen.dart
│   ├── camera_screen.dart
│   ├── record_save_screen.dart
│   └── record_detail_screen.dart
├── widgets/
│   ├── difficulty_selector.dart
│   ├── gym_selector.dart
│   ├── tag_input.dart
│   ├── calendar_view.dart
│   └── record_card.dart
└── utils/
    └── constants.dart
```

**Step 4: constants.dart 작성**

```dart
// lib/utils/constants.dart

/// 클라이밍 난이도 등급
enum ClimbingGrade { v1, v2, v3, v4, v5 }

extension ClimbingGradeExt on ClimbingGrade {
  String get label => name.toUpperCase();
}

/// 난이도 색상
enum DifficultyColor {
  white('하얀', 0xFFFFFFFF),
  yellow('노랑', 0xFFFFEB3B),
  green('녹색', 0xFF4CAF50),
  blue('파랑', 0xFF2196F3),
  red('빨강', 0xFFF44336),
  purple('보라', 0xFF9C27B0),
  orange('주황', 0xFFFF9800),
  pink('핑크', 0xFFE91E63),
  black('검정', 0xFF212121);

  final String korean;
  final int colorValue;
  const DifficultyColor(this.korean, this.colorValue);
}

/// 완등 상태
enum ClimbingStatus {
  completed('완등'),
  inProgress('도전중');

  final String label;
  const ClimbingStatus(this.label);
}
```

**Step 5: Supabase 설정 파일**

```dart
// lib/config/supabase_config.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // .env 또는 --dart-define으로 주입
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}
```

**Step 6: main.dart 작성**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/supabase_config.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(const ProviderScope(child: WandeungApp()));
}
```

**Step 7: 커밋**

```bash
git add -A
git commit -m "chore: Flutter 프로젝트 초기 설정 및 디렉토리 구조 생성"
```

---

## Task 2: Supabase 데이터베이스 및 스토리지 설정

**Files:**
- Create: `wandeung/supabase/migrations/001_initial_schema.sql`

**Step 1: Supabase 프로젝트 생성**

Supabase 대시보드에서 프로젝트 생성 후 URL과 Anon Key 확보.

**Step 2: DB 스키마 SQL 작성 및 실행**

```sql
-- supabase/migrations/001_initial_schema.sql

-- 클라이밍장 테이블
CREATE TABLE climbing_gyms (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  address TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 등반 기록 테이블
CREATE TABLE climbing_records (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  gym_id UUID REFERENCES climbing_gyms(id),
  gym_name TEXT, -- gym_id가 null일 때 직접 입력값
  grade TEXT NOT NULL, -- v1, v2, v3, v4, v5
  difficulty_color TEXT NOT NULL, -- white, yellow, green 등
  status TEXT NOT NULL DEFAULT 'completed', -- completed, in_progress
  video_path TEXT, -- Supabase Storage 경로
  thumbnail_path TEXT,
  tags TEXT[] DEFAULT '{}', -- PostgreSQL 배열
  memo TEXT,
  recorded_at DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 인덱스
CREATE INDEX idx_records_user_date ON climbing_records(user_id, recorded_at);
CREATE INDEX idx_records_user_id ON climbing_records(user_id);
CREATE INDEX idx_gyms_location ON climbing_gyms USING gist (
  ll_to_earth(latitude, longitude)
);

-- RLS (Row Level Security) 활성화
ALTER TABLE climbing_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE climbing_gyms ENABLE ROW LEVEL SECURITY;

-- RLS 정책: 자신의 기록만 CRUD
CREATE POLICY "Users can CRUD own records"
  ON climbing_records FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- RLS 정책: 클라이밍장은 모든 인증 사용자가 조회 가능, 생성 가능
CREATE POLICY "Authenticated users can read gyms"
  ON climbing_gyms FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert gyms"
  ON climbing_gyms FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = created_by);
```

**Step 3: Supabase Storage 버킷 생성**

Supabase 대시보드 → Storage에서:
- `climbing-videos` 버킷 생성 (비공개, 50MB 파일 제한)
- `thumbnails` 버킷 생성 (비공개, 5MB 파일 제한)

Storage RLS 정책:
```sql
-- climbing-videos 버킷 정책
CREATE POLICY "Users can upload own videos"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'climbing-videos' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can read own videos"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (bucket_id = 'climbing-videos' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete own videos"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'climbing-videos' AND auth.uid()::text = (storage.foldername(name))[1]);
```

**Step 4: Google OAuth 설정**

Supabase 대시보드 → Authentication → Providers → Google:
- Google Cloud Console에서 OAuth 2.0 Client ID 생성 (iOS, Android, Web 각각)
- Supabase에 Client ID / Secret 입력

**Step 5: 커밋**

```bash
git add -A
git commit -m "feat: Supabase DB 스키마, Storage, Auth 설정"
```

---

## Task 3: Google 로그인 구현

**Files:**
- Create: `wandeung/lib/providers/auth_provider.dart`
- Create: `wandeung/lib/screens/login_screen.dart`
- Modify: `wandeung/lib/app.dart`
- Modify: `wandeung/android/app/build.gradle` (Google Sign-In 설정)
- Modify: `wandeung/ios/Runner/Info.plist` (Google Sign-In URL Scheme)

**Step 1: auth_provider.dart 작성**

```dart
// lib/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  AuthNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  final _supabase = SupabaseConfig.client;

  void _init() {
    final currentUser = _supabase.auth.currentUser;
    state = AsyncValue.data(currentUser);

    _supabase.auth.onAuthStateChange.listen((data) {
      state = AsyncValue.data(data.session?.user);
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
      const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

      final googleSignIn = GoogleSignIn(
        clientId: iosClientId,
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) throw Exception('Google ID Token is null');

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      state = AsyncValue.data(response.user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _supabase.auth.signOut();
    state = const AsyncValue.data(null);
  }
}
```

**Step 2: login_screen.dart 작성**

```dart
// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 앱 로고 & 이름
            const Text('완등', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('나의 클라이밍 기록', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 48),

            // 구글 로그인 버튼
            authState.isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: () => ref.read(authProvider.notifier).signInWithGoogle(),
                    icon: Image.asset('assets/google_logo.png', height: 24),
                    label: const Text('Google로 시작하기'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),

            // 에러 메시지
            if (authState.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text('로그인 실패: ${authState.error}',
                    style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
```

**Step 3: app.dart - 인증 상태에 따른 라우팅**

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

class WandeungApp extends ConsumerWidget {
  const WandeungApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: '완등',
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: authState.when(
        data: (user) => user != null ? const HomeScreen() : const LoginScreen(),
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => const LoginScreen(),
      ),
    );
  }
}
```

**Step 4: 플랫폼별 Google Sign-In 설정**

- Android: `android/app/build.gradle`에 `minSdkVersion 21` 확인, `google-services.json` 추가
- iOS: `ios/Runner/Info.plist`에 URL Scheme 추가, `GoogleService-Info.plist` 추가

**Step 5: 앱 실행 테스트**

```bash
flutter run --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_ANON_KEY=<key> --dart-define=GOOGLE_WEB_CLIENT_ID=<id> --dart-define=GOOGLE_IOS_CLIENT_ID=<id>
```
Expected: 로그인 화면 표시 → Google 로그인 → 홈 화면 이동

**Step 6: 커밋**

```bash
git add -A
git commit -m "feat: Google 로그인 구현 (Supabase Auth + Google Sign-In)"
```

---

## Task 4: 카메라 영상 촬영 화면 구현

**Files:**
- Create: `wandeung/lib/screens/camera_screen.dart`
- Create: `wandeung/lib/providers/camera_provider.dart`

**Step 1: camera_provider.dart 작성**

```dart
// lib/providers/camera_provider.dart
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final availableCamerasProvider = FutureProvider<List<CameraDescription>>((ref) async {
  return await availableCameras();
});

final cameraControllerProvider = FutureProvider.family<CameraController, CameraDescription>(
  (ref, camera) async {
    final controller = CameraController(camera, ResolutionPreset.high, enableAudio: true);
    await controller.initialize();
    return controller;
  },
);
```

**Step 2: camera_screen.dart 작성**

영상 촬영 전용 화면. 촬영 시작/정지 버튼, 촬영 시간 표시, 전면/후면 카메라 전환.

```dart
// lib/screens/camera_screen.dart
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'record_save_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _timer;
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isNotEmpty) {
      await _setupCamera(_cameras[_selectedCameraIndex]);
    }
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    _controller?.dispose();
    final controller = CameraController(camera, ResolutionPreset.high, enableAudio: true);
    await controller.initialize();
    if (mounted) setState(() => _controller = controller);
  }

  void _toggleRecording() async {
    if (_controller == null) return;

    if (_isRecording) {
      final file = await _controller!.stopVideoRecording();
      _timer?.cancel();
      if (!mounted) return;

      // 촬영 종료 → 저장 화면으로 이동
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RecordSaveScreen(videoPath: file.path),
        ),
      );

      // 삭제 선택 시 또는 뒤로가기 → 카메라 화면 유지
      setState(() {
        _isRecording = false;
        _recordingSeconds = 0;
      });

      if (result == true) {
        if (mounted) Navigator.pop(context); // 저장 완료 → 홈으로
      }
    } else {
      await _controller!.startVideoRecording();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _recordingSeconds++);
      });
      setState(() => _isRecording = true);
    }
  }

  void _switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _setupCamera(_cameras[_selectedCameraIndex]);
  }

  String get _formattedTime {
    final min = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final sec = (_recordingSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  void dispose() {
    _controller?.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 카메라 프리뷰
          Center(child: CameraPreview(_controller!)),

          // 상단: 닫기 버튼 + 촬영 시간
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  if (_isRecording)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(_formattedTime,
                          style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 28),
                    onPressed: _isRecording ? null : _switchCamera,
                  ),
                ],
              ),
            ),
          ),

          // 하단: 촬영 버튼
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _toggleRecording,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Center(
                    child: _isRecording
                        ? Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )
                        : Container(
                            width: 56, height: 56,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 3: 플랫폼 권한 설정**

- Android `AndroidManifest.xml`: `CAMERA`, `RECORD_AUDIO` 권한 추가
- iOS `Info.plist`: `NSCameraUsageDescription`, `NSMicrophoneUsageDescription` 추가

**Step 4: 커밋**

```bash
git add -A
git commit -m "feat: 카메라 영상 촬영 화면 구현"
```

---

## Task 5: 촬영 후 저장 화면 (메타데이터 입력)

**Files:**
- Create: `wandeung/lib/screens/record_save_screen.dart`
- Create: `wandeung/lib/widgets/difficulty_selector.dart`
- Create: `wandeung/lib/widgets/gym_selector.dart`
- Create: `wandeung/lib/widgets/tag_input.dart`
- Create: `wandeung/lib/models/climbing_record.dart`
- Create: `wandeung/lib/models/climbing_gym.dart`
- Create: `wandeung/lib/providers/record_provider.dart`
- Create: `wandeung/lib/providers/gym_provider.dart`

**Step 1: 모델 클래스 작성**

```dart
// lib/models/climbing_record.dart
class ClimbingRecord {
  final String? id;
  final String userId;
  final String? gymId;
  final String? gymName;
  final String grade;        // v1~v5
  final String difficultyColor; // white, yellow 등
  final String status;       // completed, in_progress
  final String? videoPath;
  final String? thumbnailPath;
  final List<String> tags;
  final String? memo;
  final DateTime recordedAt;
  final DateTime? createdAt;

  ClimbingRecord({
    this.id,
    required this.userId,
    this.gymId,
    this.gymName,
    required this.grade,
    required this.difficultyColor,
    required this.status,
    this.videoPath,
    this.thumbnailPath,
    this.tags = const [],
    this.memo,
    required this.recordedAt,
    this.createdAt,
  });

  Map<String, dynamic> toInsertMap() => {
    'user_id': userId,
    'gym_id': gymId,
    'gym_name': gymName,
    'grade': grade,
    'difficulty_color': difficultyColor,
    'status': status,
    'video_path': videoPath,
    'thumbnail_path': thumbnailPath,
    'tags': tags,
    'memo': memo,
    'recorded_at': recordedAt.toIso8601String().split('T')[0],
  };

  factory ClimbingRecord.fromMap(Map<String, dynamic> map) => ClimbingRecord(
    id: map['id'],
    userId: map['user_id'],
    gymId: map['gym_id'],
    gymName: map['gym_name'],
    grade: map['grade'],
    difficultyColor: map['difficulty_color'],
    status: map['status'],
    videoPath: map['video_path'],
    thumbnailPath: map['thumbnail_path'],
    tags: List<String>.from(map['tags'] ?? []),
    memo: map['memo'],
    recordedAt: DateTime.parse(map['recorded_at']),
    createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
  );
}
```

```dart
// lib/models/climbing_gym.dart
class ClimbingGym {
  final String? id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;

  ClimbingGym({this.id, required this.name, this.address, this.latitude, this.longitude});

  factory ClimbingGym.fromMap(Map<String, dynamic> map) => ClimbingGym(
    id: map['id'],
    name: map['name'],
    address: map['address'],
    latitude: map['latitude'],
    longitude: map['longitude'],
  );
}
```

**Step 2: gym_provider.dart - 위치 기반 암장 조회**

```dart
// lib/providers/gym_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../config/supabase_config.dart';
import '../models/climbing_gym.dart';

final nearbyGymsProvider = FutureProvider<List<ClimbingGym>>((ref) async {
  // 위치 권한 요청 및 현재 위치 가져오기
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  final position = await Geolocator.getCurrentPosition();

  // Supabase에서 근처 암장 조회 (PostgreSQL 거리 계산)
  final response = await SupabaseConfig.client
      .from('climbing_gyms')
      .select()
      .order('name');

  final gyms = (response as List).map((e) => ClimbingGym.fromMap(e)).toList();

  // 클라이언트에서 거리순 정렬 (MVP 단순화)
  gyms.sort((a, b) {
    if (a.latitude == null || b.latitude == null) return 0;
    final distA = Geolocator.distanceBetween(
        position.latitude, position.longitude, a.latitude!, a.longitude!);
    final distB = Geolocator.distanceBetween(
        position.latitude, position.longitude, b.latitude!, b.longitude!);
    return distA.compareTo(distB);
  });

  return gyms;
});

final gymSearchProvider = FutureProvider.family<List<ClimbingGym>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final response = await SupabaseConfig.client
      .from('climbing_gyms')
      .select()
      .ilike('name', '%$query%')
      .limit(10);
  return (response as List).map((e) => ClimbingGym.fromMap(e)).toList();
});
```

**Step 3: record_provider.dart - 기록 저장/조회**

```dart
// lib/providers/record_provider.dart
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../config/supabase_config.dart';
import '../models/climbing_record.dart';

final recordsByDateProvider = FutureProvider.family<List<ClimbingRecord>, DateTime>((ref, date) async {
  final userId = SupabaseConfig.client.auth.currentUser!.id;
  final dateStr = date.toIso8601String().split('T')[0];

  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select()
      .eq('user_id', userId)
      .eq('recorded_at', dateStr)
      .order('created_at', ascending: false);

  return (response as List).map((e) => ClimbingRecord.fromMap(e)).toList();
});

// 캘린더 마커용: 월별 기록이 있는 날짜 목록
final recordDatesProvider = FutureProvider.family<Set<DateTime>, DateTime>((ref, month) async {
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

  /// 영상 업로드 + 기록 저장
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
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = p.extension(videoPath);

    // 1. 영상 업로드
    final storagePath = '$userId/$timestamp$ext';
    await _supabase.storage
        .from('climbing-videos')
        .upload(storagePath, File(videoPath));

    // 2. DB에 기록 저장
    final record = ClimbingRecord(
      userId: userId,
      gymId: gymId,
      gymName: gymName,
      grade: grade,
      difficultyColor: difficultyColor,
      status: status,
      videoPath: storagePath,
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
```

**Step 4: 위젯 작성 - difficulty_selector.dart**

```dart
// lib/widgets/difficulty_selector.dart
import 'package:flutter/material.dart';
import '../utils/constants.dart';

class DifficultySelector extends StatelessWidget {
  final ClimbingGrade? selectedGrade;
  final DifficultyColor? selectedColor;
  final ValueChanged<ClimbingGrade> onGradeChanged;
  final ValueChanged<DifficultyColor> onColorChanged;

  const DifficultySelector({
    super.key,
    this.selectedGrade,
    this.selectedColor,
    required this.onGradeChanged,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('난이도 등급', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ClimbingGrade.values.map((grade) {
            final isSelected = grade == selectedGrade;
            return ChoiceChip(
              label: Text(grade.label),
              selected: isSelected,
              onSelected: (_) => onGradeChanged(grade),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        const Text('난이도 색상', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: DifficultyColor.values.map((dc) {
            final isSelected = dc == selectedColor;
            return GestureDetector(
              onTap: () => onColorChanged(dc),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Color(dc.colorValue),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.green : Colors.grey.shade300,
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
```

**Step 5: 위젯 작성 - gym_selector.dart**

```dart
// lib/widgets/gym_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/climbing_gym.dart';
import '../providers/gym_provider.dart';

class GymSelector extends ConsumerStatefulWidget {
  final ClimbingGym? selectedGym;
  final String? manualGymName;
  final ValueChanged<ClimbingGym?> onGymSelected;
  final ValueChanged<String> onManualInput;

  const GymSelector({
    super.key,
    this.selectedGym,
    this.manualGymName,
    required this.onGymSelected,
    required this.onManualInput,
  });

  @override
  ConsumerState<GymSelector> createState() => _GymSelectorState();
}

class _GymSelectorState extends ConsumerState<GymSelector> {
  bool _isManualMode = false;
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final nearbyGyms = ref.watch(nearbyGymsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('클라이밍장', style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => setState(() => _isManualMode = !_isManualMode),
              child: Text(_isManualMode ? '목록에서 선택' : '직접 입력'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isManualMode)
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: '클라이밍장 이름 입력',
              border: OutlineInputBorder(),
            ),
            onChanged: widget.onManualInput,
          )
        else
          nearbyGyms.when(
            data: (gyms) => SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: gyms.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final gym = gyms[i];
                  final isSelected = gym.id == widget.selectedGym?.id;
                  return ChoiceChip(
                    label: Text(gym.name),
                    selected: isSelected,
                    onSelected: (_) => widget.onGymSelected(gym),
                  );
                },
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('위치 정보를 가져올 수 없습니다: $e'),
          ),
      ],
    );
  }
}
```

**Step 6: 위젯 작성 - tag_input.dart**

```dart
// lib/widgets/tag_input.dart
import 'package:flutter/material.dart';

class TagInput extends StatefulWidget {
  final List<String> tags;
  final ValueChanged<List<String>> onTagsChanged;

  const TagInput({super.key, required this.tags, required this.onTagsChanged});

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final _controller = TextEditingController();

  void _addTag() {
    var text = _controller.text.trim();
    if (text.isEmpty) return;
    if (!text.startsWith('#')) text = '#$text';
    if (!widget.tags.contains(text)) {
      widget.onTagsChanged([...widget.tags, text]);
    }
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('태그', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: widget.tags.map((tag) => Chip(
            label: Text(tag),
            onDeleted: () {
              widget.onTagsChanged(widget.tags.where((t) => t != tag).toList());
            },
          )).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: '#태그 입력 (예: #발컨, #슬탭)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(onPressed: _addTag, icon: const Icon(Icons.add)),
          ],
        ),
      ],
    );
  }
}
```

**Step 7: record_save_screen.dart - 촬영 후 저장 화면**

```dart
// lib/screens/record_save_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../models/climbing_gym.dart';
import '../providers/record_provider.dart';
import '../utils/constants.dart';
import '../widgets/difficulty_selector.dart';
import '../widgets/gym_selector.dart';
import '../widgets/tag_input.dart';

class RecordSaveScreen extends ConsumerStatefulWidget {
  final String videoPath;
  const RecordSaveScreen({super.key, required this.videoPath});

  @override
  ConsumerState<RecordSaveScreen> createState() => _RecordSaveScreenState();
}

class _RecordSaveScreenState extends ConsumerState<RecordSaveScreen> {
  late VideoPlayerController _videoController;
  ClimbingGrade? _grade;
  DifficultyColor? _color;
  ClimbingStatus _status = ClimbingStatus.completed;
  ClimbingGym? _selectedGym;
  String? _manualGymName;
  List<String> _tags = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  void _deleteVideo() {
    // 영상 파일 삭제 후 카메라 화면으로 복귀
    File(widget.videoPath).deleteSync();
    Navigator.pop(context, false);
  }

  Future<void> _saveRecord() async {
    if (_grade == null || _color == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('난이도와 색상을 선택해주세요')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await RecordService.saveRecord(
        videoPath: widget.videoPath,
        grade: _grade!.name,
        difficultyColor: _color!.name,
        status: _status.name,
        gymId: _selectedGym?.id,
        gymName: _selectedGym?.name ?? _manualGymName,
        tags: _tags,
      );

      if (mounted) Navigator.pop(context, true); // 저장 성공
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('등반 기록 저장'),
        actions: [
          TextButton(
            onPressed: _deleteVideo,
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 영상 프리뷰
            if (_videoController.value.isInitialized)
              AspectRatio(
                aspectRatio: _videoController.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_videoController),
                    IconButton(
                      icon: Icon(
                        _videoController.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                        size: 48, color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _videoController.value.isPlaying
                              ? _videoController.pause()
                              : _videoController.play();
                        });
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // 난이도 선택
            DifficultySelector(
              selectedGrade: _grade,
              selectedColor: _color,
              onGradeChanged: (g) => setState(() => _grade = g),
              onColorChanged: (c) => setState(() => _color = c),
            ),
            const SizedBox(height: 24),

            // 클라이밍장 선택
            GymSelector(
              selectedGym: _selectedGym,
              manualGymName: _manualGymName,
              onGymSelected: (gym) => setState(() {
                _selectedGym = gym;
                _manualGymName = null;
              }),
              onManualInput: (name) => setState(() {
                _manualGymName = name;
                _selectedGym = null;
              }),
            ),
            const SizedBox(height: 24),

            // 완등 여부
            const Text('완등 여부', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<ClimbingStatus>(
              segments: ClimbingStatus.values.map((s) => ButtonSegment(
                value: s,
                label: Text(s.label),
              )).toList(),
              selected: {_status},
              onSelectionChanged: (s) => setState(() => _status = s.first),
            ),
            const SizedBox(height: 24),

            // 태그 입력
            TagInput(
              tags: _tags,
              onTagsChanged: (tags) => setState(() => _tags = tags),
            ),
            const SizedBox(height: 32),

            // 저장 버튼
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveRecord,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('저장하기', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 8: 커밋**

```bash
git add -A
git commit -m "feat: 촬영 후 저장 화면 구현 (난이도/암장/완등여부/태그)"
```

---

## Task 6: 홈 화면 + 캘린더 기반 기록 조회

**Files:**
- Create: `wandeung/lib/screens/home_screen.dart`
- Create: `wandeung/lib/widgets/calendar_view.dart`
- Create: `wandeung/lib/widgets/record_card.dart`
- Create: `wandeung/lib/screens/record_detail_screen.dart`

**Step 1: home_screen.dart - 캘린더 + 기록 목록**

```dart
// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/auth_provider.dart';
import '../providers/record_provider.dart';
import '../widgets/record_card.dart';
import 'camera_screen.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final focusedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final focusedMonth = ref.watch(focusedMonthProvider);
    final records = ref.watch(recordsByDateProvider(selectedDate));
    final recordDates = ref.watch(recordDatesProvider(focusedMonth));

    return Scaffold(
      appBar: AppBar(
        title: const Text('완등'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 캘린더
          TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: focusedMonth,
            selectedDayPredicate: (day) => isSameDay(day, selectedDate),
            onDaySelected: (selected, focused) {
              ref.read(selectedDateProvider.notifier).state = selected;
              ref.read(focusedMonthProvider.notifier).state = focused;
            },
            onPageChanged: (focused) {
              ref.read(focusedMonthProvider.notifier).state = focused;
            },
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            // 기록이 있는 날짜에 마커 표시
            eventLoader: (day) {
              final dates = recordDates.valueOrNull ?? {};
              final normalized = DateTime(day.year, day.month, day.day);
              return dates.contains(normalized) ? ['record'] : [];
            },
          ),
          const Divider(),

          // 선택된 날짜의 기록 목록
          Expanded(
            child: records.when(
              data: (list) => list.isEmpty
                  ? const Center(child: Text('이 날의 등반 기록이 없습니다'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (_, i) => RecordCard(record: list[i]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
            ),
          ),
        ],
      ),

      // FAB: 촬영 시작
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CameraScreen()),
          );
          // 카메라에서 돌아온 후 기록 새로고침
          ref.invalidate(recordsByDateProvider(selectedDate));
          ref.invalidate(recordDatesProvider(focusedMonth));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

**Step 2: record_card.dart - 기록 카드 위젯**

```dart
// lib/widgets/record_card.dart
import 'package:flutter/material.dart';
import '../models/climbing_record.dart';
import '../utils/constants.dart';
import '../screens/record_detail_screen.dart';

class RecordCard extends StatelessWidget {
  final ClimbingRecord record;
  const RecordCard({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final color = DifficultyColor.values.firstWhere(
      (c) => c.name == record.difficultyColor,
      orElse: () => DifficultyColor.white,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RecordDetailScreen(record: record)),
        ),
        leading: CircleAvatar(
          backgroundColor: Color(color.colorValue),
          child: Text(
            record.grade.toUpperCase(),
            style: TextStyle(
              color: color == DifficultyColor.white ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(record.gymName ?? '암장 미지정'),
        subtitle: Wrap(
          spacing: 4,
          children: [
            Chip(
              label: Text(
                record.status == 'completed' ? '완등' : '도전중',
                style: const TextStyle(fontSize: 11),
              ),
              visualDensity: VisualDensity.compact,
              backgroundColor: record.status == 'completed' ? Colors.green.shade100 : Colors.orange.shade100,
            ),
            ...record.tags.map((tag) => Chip(
              label: Text(tag, style: const TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
            )),
          ],
        ),
        trailing: record.videoPath != null
            ? const Icon(Icons.videocam, color: Colors.grey)
            : null,
      ),
    );
  }
}
```

**Step 3: record_detail_screen.dart - 기록 상세 (영상 재생)**

```dart
// lib/screens/record_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../config/supabase_config.dart';
import '../models/climbing_record.dart';
import '../utils/constants.dart';

class RecordDetailScreen extends StatefulWidget {
  final ClimbingRecord record;
  const RecordDetailScreen({super.key, required this.record});

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    if (widget.record.videoPath == null) return;

    final url = SupabaseConfig.client.storage
        .from('climbing-videos')
        .getPublicUrl(widget.record.videoPath!);

    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    await _videoController!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final color = DifficultyColor.values.firstWhere(
      (c) => c.name == record.difficultyColor,
      orElse: () => DifficultyColor.white,
    );

    return Scaffold(
      appBar: AppBar(title: Text(record.gymName ?? '등반 기록')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 영상 플레이어
            if (_videoController != null && _videoController!.value.isInitialized)
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_videoController!),
                    IconButton(
                      icon: Icon(
                        _videoController!.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                        size: 56, color: Colors.white,
                      ),
                      onPressed: () => setState(() {
                        _videoController!.value.isPlaying
                            ? _videoController!.pause()
                            : _videoController!.play();
                      }),
                    ),
                  ],
                ),
              )
            else if (record.videoPath != null)
              const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 난이도 + 색상 + 상태
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Color(color.colorValue),
                        child: Text(record.grade.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Text(color.korean, style: const TextStyle(fontSize: 16)),
                      const Spacer(),
                      Chip(
                        label: Text(record.status == 'completed' ? '완등' : '도전중'),
                        backgroundColor: record.status == 'completed'
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 암장
                  if (record.gymName != null) ...[
                    Text('클라이밍장', style: Theme.of(context).textTheme.labelLarge),
                    Text(record.gymName!, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                  ],

                  // 태그
                  if (record.tags.isNotEmpty) ...[
                    Text('태그', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: record.tags.map((tag) => Chip(label: Text(tag))).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 4: 커밋**

```bash
git add -A
git commit -m "feat: 홈 캘린더 화면 및 기록 상세 화면 구현"
```

---

## Task 7: 플랫폼 권한 설정 및 앱 설정 마무리

**Files:**
- Modify: `wandeung/android/app/src/main/AndroidManifest.xml`
- Modify: `wandeung/ios/Runner/Info.plist`
- Modify: `wandeung/android/app/build.gradle`

**Step 1: Android 권한 설정**

`android/app/src/main/AndroidManifest.xml`에 추가:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

`android/app/build.gradle`에서:
```groovy
minSdkVersion 21
compileSdkVersion 34
```

**Step 2: iOS 권한 설정**

`ios/Runner/Info.plist`에 추가:
```xml
<key>NSCameraUsageDescription</key>
<string>등반 영상을 촬영하기 위해 카메라 접근이 필요합니다</string>
<key>NSMicrophoneUsageDescription</key>
<string>등반 영상에 소리를 녹음하기 위해 마이크 접근이 필요합니다</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>근처 클라이밍장을 자동으로 찾기 위해 위치 정보가 필요합니다</string>
```

**Step 3: 커밋**

```bash
git add -A
git commit -m "chore: Android/iOS 카메라, 위치 권한 설정"
```

---

## Task 8: 통합 테스트 및 마무리

**Step 1: 전체 플로우 수동 테스트**

```bash
flutter run --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_ANON_KEY=<key> --dart-define=GOOGLE_WEB_CLIENT_ID=<id> --dart-define=GOOGLE_IOS_CLIENT_ID=<id>
```

테스트 체크리스트:
- [ ] Google 로그인 → 홈 화면 진입
- [ ] FAB(+) 버튼 → 카메라 화면 진입
- [ ] 영상 촬영 시작/중지
- [ ] 촬영 후 저장 화면에서 영상 프리뷰 재생
- [ ] 난이도 등급(V1-V5) 선택
- [ ] 난이도 색상 선택
- [ ] 클라이밍장 위치 기반 자동 추천 / 직접 입력 전환
- [ ] 완등/도전중 선택
- [ ] 태그 입력 및 삭제
- [ ] 저장 → Supabase Storage에 영상 업로드 확인
- [ ] 저장 → Supabase DB에 기록 저장 확인
- [ ] 홈 캘린더에서 기록 있는 날짜 마커 표시
- [ ] 날짜 선택 시 해당 날짜 기록 목록 표시
- [ ] 기록 카드 탭 → 상세 화면 → 영상 재생
- [ ] 촬영 후 "삭제" 선택 시 카메라 화면으로 복귀
- [ ] 로그아웃

**Step 2: 최종 커밋**

```bash
git add -A
git commit -m "feat: 완등 MVP 완성 - 클라이밍 기록 앱"
```

---

## 요약: 핵심 파일 목록

| 파일 | 역할 |
|------|------|
| `lib/main.dart` | 앱 진입점, Supabase 초기화 |
| `lib/app.dart` | MaterialApp, 인증 기반 라우팅 |
| `lib/config/supabase_config.dart` | Supabase 설정 |
| `lib/utils/constants.dart` | 난이도/색상/상태 enum |
| `lib/models/climbing_record.dart` | 등반 기록 모델 |
| `lib/models/climbing_gym.dart` | 클라이밍장 모델 |
| `lib/providers/auth_provider.dart` | Google 인증 상태 관리 |
| `lib/providers/record_provider.dart` | 기록 CRUD + 영상 업로드 |
| `lib/providers/gym_provider.dart` | 위치 기반 암장 조회 |
| `lib/screens/login_screen.dart` | Google 로그인 화면 |
| `lib/screens/home_screen.dart` | 캘린더 + 기록 목록 메인 화면 |
| `lib/screens/camera_screen.dart` | 영상 촬영 화면 |
| `lib/screens/record_save_screen.dart` | 메타데이터 입력 + 저장/삭제 |
| `lib/screens/record_detail_screen.dart` | 기록 상세 + 영상 재생 |
| `lib/widgets/difficulty_selector.dart` | 난이도 등급/색상 선택 위젯 |
| `lib/widgets/gym_selector.dart` | 암장 선택/검색 위젯 |
| `lib/widgets/tag_input.dart` | 태그 입력 위젯 |
| `lib/widgets/record_card.dart` | 기록 리스트 카드 위젯 |
| `supabase/migrations/001_initial_schema.sql` | DB 스키마 (테이블, RLS, 인덱스) |

---

## 구현 상태

> 작성일: 2026-03-01

| Task | 설명 | 상태 |
|------|------|------|
| Task 1 | Flutter 프로젝트 초기 설정 | ✅ 완료 |
| Task 2 | Supabase DB 스키마 및 스토리지 설정 | ✅ 완료 |
| Task 3 | Google 로그인 구현 | ✅ 완료 |
| Task 4 | 카메라 영상 촬영 화면 | ✅ 완료 |
| Task 5 | 촬영 후 저장 화면 (메타데이터 입력) | ✅ 완료 |
| Task 6 | 홈 캘린더 + 기록 상세 화면 | ✅ 완료 |
| Task 7 | 플랫폼 권한 설정 (Android/iOS) | ✅ 완료 |
| Task 8 | 통합 테스트 | ⬜ 미실행 (디바이스/Supabase 연동 필요) |

**`flutter analyze`: No issues found**

## 앱 실행 전 필수 작업

1. **Supabase 프로젝트 생성** → URL, Anon Key 확보
2. **SQL 마이그레이션 실행** → Supabase SQL Editor에서 `supabase/migrations/001_initial_schema.sql` 실행
3. **Storage 버킷 생성** → `climbing-videos` (50MB), `thumbnails` (5MB)
4. **Google OAuth 설정** → Google Cloud Console에서 OAuth 2.0 Client ID 생성 → Supabase Auth Provider에 연결
5. **앱 실행**:
```bash
flutter run \
  --dart-define=SUPABASE_URL=<your-url> \
  --dart-define=SUPABASE_ANON_KEY=<your-key> \
  --dart-define=GOOGLE_WEB_CLIENT_ID=<your-web-client-id> \
  --dart-define=GOOGLE_IOS_CLIENT_ID=<your-ios-client-id>
```
