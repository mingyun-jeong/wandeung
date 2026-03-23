---
name: flutter-native
description: "Flutter 고급 프로그래밍 스킬. 안드로이드/iOS 네이티브처럼 자연스럽고 안정적인 코드를 작성한다. 플랫폼별 UX 차이 대응, 성능 최적화, 안정성 확보, 네이티브 수준 인터랙션을 구현한다."
---

# Flutter Native-Quality Programming

## Overview

Flutter 코드를 작성할 때 안드로이드/iOS 네이티브 앱과 동일한 수준의 자연스러움과 안정성을 달성하는 스킬. 단순히 "돌아가는 코드"가 아닌, 각 플랫폼 사용자가 기대하는 동작과 느낌을 구현한다.

**Announce at start:** "flutter-native 스킬을 사용합니다. 네이티브 품질 코드를 작성합니다."

## Core Principles

### 1. 플랫폼 적응형 UI/UX

각 플랫폼 사용자가 익숙한 패턴을 존중한다:

**네비게이션:**
- iOS: 스와이프 백 제스처(`CupertinoPageRoute`), 모달 시트는 아래에서 올라옴
- Android: 시스템 백 버튼, `PopScope`로 뒤로가기 제어
- 공통: `Platform.isIOS`로 분기하되, 과도한 분기는 피함

```dart
// 플랫폼 적응형 페이지 전환
PageRoute<T> buildAdaptiveRoute<T>({
  required WidgetBuilder builder,
  bool fullscreenDialog = false,
}) {
  if (Platform.isIOS) {
    return CupertinoPageRoute<T>(
      builder: builder,
      fullscreenDialog: fullscreenDialog,
    );
  }
  return MaterialPageRoute<T>(
    builder: builder,
    fullscreenDialog: fullscreenDialog,
  );
}
```

**스크롤 물리:**
- iOS: `BouncingScrollPhysics` (바운스 효과)
- Android: `ClampingScrollPhysics` (글로우 효과)
- Flutter 기본값이 이미 플랫폼별로 적용되므로, 명시적으로 physics를 지정할 때만 주의

**다이얼로그/시트:**
- iOS: `CupertinoAlertDialog`, `CupertinoActionSheet` 스타일 선호
- Android: `AlertDialog`, `BottomSheet` Material 스타일
- `showAdaptiveDialog` (Flutter 3.13+) 활용 권장

```dart
// 적응형 다이얼로그
Future<bool?> showConfirmDialog(BuildContext context, String message) {
  return showAdaptiveDialog<bool>(
    context: context,
    builder: (context) {
      // iOS에서는 CupertinoAlertDialog, Android에서는 AlertDialog로 자동 전환
      if (Platform.isIOS) {
        return CupertinoAlertDialog(
          title: Text(message),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('확인'),
            ),
          ],
        );
      }
      return AlertDialog(
        title: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      );
    },
  );
}
```

### 2. 60fps 사수 — 성능 최적화

**빌드 최적화:**
```dart
// BAD: 전체 리스트를 한 번에 빌드
ListView(
  children: items.map((e) => ItemWidget(e)).toList(),
)

// GOOD: 필요한 항목만 lazy 빌드
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(items[index]),
)

// BETTER: 아이템 크기가 고정이면 명시
ListView.builder(
  itemCount: items.length,
  itemExtent: 72.0, // 고정 높이 → 스크롤 성능 향상
  itemBuilder: (context, index) => ItemWidget(items[index]),
)
```

**불필요한 rebuild 방지:**
```dart
// BAD: 부모가 rebuild될 때마다 자식도 전부 rebuild
class ParentWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allData = ref.watch(largeDataProvider);
    return Column(
      children: [
        HeaderWidget(allData.title), // title만 필요한데 전체를 watch
        BodyWidget(allData.items),
      ],
    );
  }
}

// GOOD: select로 필요한 데이터만 구독
class ParentWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // 각 자식이 필요한 데이터만 watch
        const HeaderSection(),
        const BodySection(),
      ],
    );
  }
}

class HeaderSection extends ConsumerWidget {
  const HeaderSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = ref.watch(largeDataProvider.select((d) => d.title));
    return HeaderWidget(title);
  }
}
```

**const 생성자 적극 활용:**
```dart
// const가 가능한 곳에서는 반드시 사용
const SizedBox(height: 16),
const Divider(),
const Icon(Icons.check, color: Colors.green),

// 커스텀 위젯에도 const 생성자 정의
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label});
  final String label;
  // ...
}
```

**이미지/미디어 최적화:**
```dart
// 네트워크 이미지: 캐싱 + 적절한 크기 요청
CachedNetworkImage(
  imageUrl: url,
  memCacheWidth: 200, // 표시 크기에 맞는 메모리 캐시
  maxWidthDiskCache: 400,
  placeholder: (_, __) => const ShimmerPlaceholder(),
  errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
)

// 대용량 리스트에서 이미지: AutomaticKeepAlive 주의
// 기본적으로 ListView.builder는 화면 밖 위젯을 dispose하므로
// 스크롤 시 이미지 깜빡임이 있으면 cacheExtent 조절
ListView.builder(
  cacheExtent: 500, // 기본 250 → 화면 밖 500px까지 유지
  // ...
)
```

**애니메이션 성능:**
```dart
// BAD: setState로 매 프레임 전체 위젯 rebuild
// GOOD: AnimatedBuilder + 별도 위젯으로 rebuild 범위 최소화

// RepaintBoundary로 자주 변하는 영역 격리
RepaintBoundary(
  child: CustomPaint(
    painter: WaveformPainter(progress),
  ),
)

// 간단한 전환은 Implicit Animation 사용
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeOutCubic, // 네이티브에 가까운 커브
  // ...
)

// 복잡한 애니메이션만 Explicit Animation 사용
```

### 3. 네이티브 수준 애니메이션 & 인터랙션

**자연스러운 모션 커브:**
```dart
// 플랫폼별 권장 커브
// iOS: Curves.easeInOut, Curves.decelerate
// Android Material: Curves.easeOutCubic, Curves.fastOutSlowIn

// 네이티브 느낌의 지속시간 가이드
// 페이드: 150-200ms
// 슬라이드/스케일: 250-350ms
// 페이지 전환: 300-400ms
// 복잡한 전환: 400-600ms (최대)
```

**터치 피드백:**
```dart
// 모든 탭 가능한 영역에 피드백 제공
// Material: InkWell (ripple 효과)
// iOS: 투명도 변화 또는 스케일 다운

// 기본 Material 버튼이 이미 피드백을 제공하므로
// 커스텀 터치 영역에만 직접 구현
class TapScaleWidget extends StatefulWidget {
  const TapScaleWidget({super.key, required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<TapScaleWidget> createState() => _TapScaleWidgetState();
}

class _TapScaleWidgetState extends State<TapScaleWidget> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
```

**햅틱 피드백:**
```dart
import 'package:flutter/services.dart';

// 중요한 액션에 햅틱 피드백 추가
// 토글, 선택, 삭제 등 사용자가 "느껴야 하는" 순간에
HapticFeedback.lightImpact();   // 가벼운 탭 (토글, 선택)
HapticFeedback.mediumImpact();  // 중간 (확인, 완료)
HapticFeedback.heavyImpact();   // 강한 (삭제, 중요 액션)
HapticFeedback.selectionClick(); // 리스트 스크롤 중 항목 선택
```

### 4. 안정성 & 에러 처리

**비동기 작업 안전 패턴:**
```dart
// BAD: mounted 체크 없이 비동기 후 setState
Future<void> _loadData() async {
  final data = await fetchData();
  setState(() => _data = data); // 위젯이 dispose된 후 호출될 수 있음
}

// GOOD: mounted 체크
Future<void> _loadData() async {
  final data = await fetchData();
  if (!mounted) return;
  setState(() => _data = data);
}

// BETTER: Riverpod 사용 시 — provider가 자동으로 생명주기 관리
// ref.watch()는 위젯이 dispose되면 자동으로 구독 해제
```

**에러 바운더리:**
```dart
// 앱 전체 에러 핸들링
void main() {
  FlutterError.onError = (details) {
    // Crashlytics나 로깅 서비스로 전송
    debugPrint('Flutter Error: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    // 비동기 에러 캐치
    debugPrint('Async Error: $error');
    return true;
  };

  runApp(const MyApp());
}

// 개별 위젯 에러 바운더리 (치명적이지 않은 UI 에러 격리)
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({super.key, required this.child});
  final Widget child;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _hasError = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(child: Text('문제가 발생했습니다'));
    }

    return ErrorWidget.builder = (details) {
      _hasError = true;
      return const SizedBox.shrink();
    };
    // 실제로는 ErrorWidget.builder를 전역으로 설정하거나
    // try-catch로 빌드 에러를 잡는 것이 더 적합
  }
}
```

**Null Safety & Defensive Coding:**
```dart
// 서버 데이터는 항상 null일 수 있다고 가정
factory ClimbingRecord.fromMap(Map<String, dynamic> map) {
  return ClimbingRecord(
    id: map['id'] as String,
    // null fallback 제공
    grade: ClimbingGrade.values.firstWhere(
      (g) => g.name == (map['grade'] as String?),
      orElse: () => ClimbingGrade.v0, // 기본값
    ),
    // 날짜 파싱 실패 대비
    createdAt: DateTime.tryParse(map['created_at'] as String? ?? '')
        ?? DateTime.now(),
  );
}
```

### 5. 메모리 & 리소스 관리

**Controller/Listener 정리:**
```dart
class _MyScreenState extends State<MyScreen> {
  late final ScrollController _scrollController;
  late final TextEditingController _textController;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _textController = TextEditingController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // 스크롤 위치에 따른 로직
  }
  // ...
}
```

**대용량 데이터 처리:**
```dart
// BAD: 수천 개 레코드를 한 번에 메모리에 로드
final allRecords = await supabase.from('climbing_records').select();

// GOOD: 페이지네이션
Future<List<ClimbingRecord>> fetchRecords({
  required int page,
  int pageSize = 20,
}) async {
  final from = page * pageSize;
  final to = from + pageSize - 1;
  final response = await supabase
      .from('climbing_records')
      .select()
      .order('created_at', ascending: false)
      .range(from, to);
  return response.map((e) => ClimbingRecord.fromMap(e)).toList();
}
```

**비디오/이미지 메모리:**
```dart
// 비디오 컨트롤러는 반드시 dispose
// 여러 비디오가 리스트에 있을 때: 화면에 보이는 것만 초기화
// VisibilityDetector 패키지 또는 커스텀 로직으로 관리

// 썸네일은 적절한 크기로 생성
final thumbnail = await VideoThumbnail.thumbnailData(
  video: videoPath,
  imageFormat: ImageFormat.JPEG,
  maxWidth: 200, // 표시 크기에 맞게
  quality: 75,
);
```

### 6. 네이티브 기능 통합

**권한 요청 — 자연스러운 플로우:**
```dart
// BAD: 앱 시작 시 모든 권한 한꺼번에 요청
// GOOD: 기능 사용 직전에 맥락과 함께 요청

Future<bool> requestCameraPermission(BuildContext context) async {
  final status = await Permission.camera.status;
  if (status.isGranted) return true;

  if (status.isDenied) {
    // 먼저 왜 필요한지 설명 (rationale)
    final shouldRequest = await showConfirmDialog(
      context,
      '클라이밍 영상을 촬영하려면\n카메라 접근 권한이 필요합니다.',
    );
    if (shouldRequest != true) return false;

    final result = await Permission.camera.request();
    return result.isGranted;
  }

  if (status.isPermanentlyDenied) {
    // 설정으로 안내
    await showConfirmDialog(
      context,
      '카메라 권한이 거부되었습니다.\n설정에서 권한을 허용해주세요.',
    );
    await openAppSettings();
    return false;
  }

  return false;
}
```

**플랫폼 채널 사용 시:**
```dart
// MethodChannel 호출은 항상 try-catch
Future<String?> getNativeDeviceInfo() async {
  try {
    const channel = MethodChannel('com.wandeung.wandeung/device');
    final result = await channel.invokeMethod<String>('getDeviceInfo');
    return result;
  } on PlatformException catch (e) {
    debugPrint('Platform channel error: ${e.message}');
    return null;
  } on MissingPluginException {
    // 해당 플랫폼에서 구현되지 않음
    debugPrint('Plugin not available on this platform');
    return null;
  }
}
```

### 7. 키보드 & 입력 처리

```dart
// 키보드가 올라올 때 레이아웃 대응
Scaffold(
  // false로 설정하면 키보드가 올라와도 body가 리사이즈되지 않음
  // 필요에 따라 선택
  resizeToAvoidBottomInset: true,
  body: SingleChildScrollView(
    // 키보드가 올라오면 포커스된 필드가 보이도록 자동 스크롤
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    child: // ...
  ),
)

// TextField 외부 탭 시 키보드 닫기
GestureDetector(
  onTap: () => FocusScope.of(context).unfocus(),
  child: // ...
)

// iOS에서 키보드 위 Done 버튼 (숫자 키패드에 완료 버튼이 없는 문제)
// 직접 구현하거나 keyboard_actions 패키지 사용
```

### 8. 접근성 & 국제화 기반

```dart
// 텍스트 크기 조절 대응 (시스템 폰트 크기에 따라)
Text(
  '완등',
  style: Theme.of(context).textTheme.bodyLarge,
  // 너무 커지면 레이아웃 깨지는 곳에서만 제한
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
)

// MediaQuery.textScalerOf(context) 로 현재 배율 확인 가능
// 고정 크기 영역에서는 textScaler 고려 필요

// 스크린 리더 지원 (기본적인 수준)
Semantics(
  label: '클라이밍 기록 삭제',
  button: true,
  child: IconButton(
    icon: const Icon(Icons.delete),
    onPressed: _deleteRecord,
  ),
)
```

### 9. Safe Area & Edge-to-Edge

```dart
// 노치, 홈 인디케이터, 상태바 대응
SafeArea(
  // 필요한 방향만 적용 (전부 적용하면 불필요한 패딩이 생길 수 있음)
  bottom: true, // 홈 인디케이터 (iPhone X+)
  top: true,    // 상태바/노치
  child: // ...
)

// BottomNavigationBar, BottomSheet는 보통 자체적으로 SafeArea 처리
// 직접 만든 하단 UI는 반드시 SafeArea 또는 viewPadding 확인
final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

// 전체 화면 (카메라, 비디오 재생 등)
// SystemChrome으로 시스템 UI 제어
SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
// 복원
SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
```

### 10. 앱 생명주기

```dart
class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        // 백그라운드로 갈 때: 리소스 해제, 진행 상태 저장
        _saveProgress();
        break;
      case AppLifecycleState.resumed:
        // 포그라운드 복귀: 데이터 새로고침, 연결 재확인
        _refreshData();
        break;
      case AppLifecycleState.detached:
        // 앱 종료: 최종 정리
        break;
      default:
        break;
    }
  }
}
```

---

## Implementation Checklist

코드를 작성할 때 아래 체크리스트를 점검한다:

### 필수 (Every Widget)
- [ ] `const` 생성자가 가능한 곳에 모두 적용되었는가
- [ ] 리스트는 `builder` 패턴을 사용하는가
- [ ] Controller/Listener가 `dispose`에서 정리되는가
- [ ] 비동기 후 `mounted` 체크 또는 Riverpod provider로 관리되는가
- [ ] SafeArea가 필요한 곳에 적용되었는가
- [ ] 터치 타겟이 48x48dp 이상인가

### 권장 (Screen-Level)
- [ ] 로딩/에러/빈 상태가 모두 처리되었는가
- [ ] 키보드 올라올 때 레이아웃이 깨지지 않는가
- [ ] 뒤로가기(Android 백 버튼, iOS 스와이프)가 자연스러운가
- [ ] 긴 텍스트에서 overflow가 발생하지 않는가
- [ ] 시스템 폰트 크기 변경 시 레이아웃이 유지되는가

### 성능 (Complex Views)
- [ ] 자주 변하는 영역에 `RepaintBoundary` 적용되었는가
- [ ] `ref.watch`가 필요한 데이터만 구독하는가 (`.select()`)
- [ ] 이미지에 적절한 캐싱과 크기 제한이 있는가
- [ ] 대용량 데이터에 페이지네이션이 적용되었는가

---

## Anti-Patterns — 절대 하지 않는 것들

| Anti-Pattern | 문제 | 대안 |
|---|---|---|
| `Timer.periodic`으로 UI 업데이트 | 프레임 드롭, 메모리 누수 | `AnimationController` 또는 `Stream` |
| `GlobalKey`로 위젯 간 통신 | 성능 저하, 결합도 증가 | Riverpod provider, callback |
| `MediaQuery.of(context)` 남용 | 불필요한 rebuild | 필요한 값만 `MediaQuery.sizeOf`, `MediaQuery.viewInsetsOf` |
| 중첩 `FutureBuilder` | 콜백 지옥, 에러 처리 어려움 | Riverpod `FutureProvider` 조합 |
| `setState` 안에서 비동기 호출 | race condition | 비동기 완료 후 `setState` |
| `BuildContext`를 비동기 gap 너머로 전달 | disposed context 접근 | `mounted` 체크 또는 provider |
| 거대한 단일 `build()` 메서드 | rebuild 범위 과대, 가독성 저하 | private 위젯 메서드 또는 별도 위젯 클래스로 분리 |
| `addPostFrameCallback` 안에서 `setState` | 무한 루프 위험 | 로직 재설계 |

---

## Transition

- 이 스킬은 모든 Flutter 코드 작성 시 배경 원칙으로 적용
- 새 기능 개발 시: `brainstorming` → `writing-plans` → 이 스킬의 원칙을 적용하며 구현
- UI 중심 작업 시: `flutter-design` 스킬과 함께 사용
- 코드 리뷰 요청 시: `flutter-design`의 UI/UX Review 모드 + 이 스킬의 체크리스트로 점검
