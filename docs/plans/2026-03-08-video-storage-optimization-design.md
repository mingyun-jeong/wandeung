# 영상 저장 공간 최적화 설계

## 현재 구조

영상은 Supabase에 업로드하지 않고 **기기 로컬에만 저장**한다. DB에는 로컬 파일 경로(`video_path`)만 기록.

- 원본 촬영: `{appDir}/videos/*.mp4`
- 편집 내보내기: `{appDir}/edited_{timestamp}.mp4`
- 썸네일: `{appDir}/thumbnails/*.jpg`
- 갤러리 내보내기: `Gal.putVideo()` → 기기 갤러리 "완등" 앨범에 별도 복사

## 문제 분석

영상을 촬영/편집/저장할 때마다 앱의 로컬 저장 공간이 무한히 증가하는 문제. 원인:

### 1. 편집 시 원본 미삭제 (가장 큰 원인)
- 편집 후 `edited_{timestamp}.mp4` 새 파일 생성
- `RecordSaveScreen`에 `originalVideoPath`가 전달되지만 **저장 성공 후 원본을 삭제하지 않음**
- 편집을 여러 번 하면 중간 파일들이 계속 누적

### 2. 갤러리 중복 저장
- `_saveToGallery()`로 `Gal.putVideo()` 호출 → 기기 갤러리에 영상 복사
- 앱 내부 `videos/` 폴더에도 동일 영상이 남아있음 → 2배 용량 사용

### 3. 레코드 삭제 시 파일 미삭제
- `RecordService.deleteRecord()`가 DB 레코드만 삭제
- 로컬 비디오 파일과 썸네일은 orphan으로 남음

### 4. 압축 미적용
- 카메라가 `ResolutionPreset.high`로 촬영 (풀 해상도)
- 저장 시 별도 압축 없음
- FFmpeg 내보내기에서도 인코딩 최적화 파라미터 없음

### 5. 계정 삭제 시 로컬 파일 미정리
- DB는 정리하지만, 기기 내 `videos/`, `thumbnails/`, `edited_*.mp4` 파일은 그대로

---

## 해결 방안

### Phase 1: 편집 후 원본 파일 삭제 (핵심)

**대상 파일:** `lib/screens/record_save_screen.dart`

신규 촬영 → 편집 → 저장 흐름에서, 저장 성공 후 `originalVideoPath`(편집 전 원본) 삭제:

```dart
// _saveRecord() 에서 DB 저장 성공 후
if (widget.originalVideoPath != null) {
  final originalFile = File(widget.originalVideoPath!);
  if (await originalFile.exists()) {
    await originalFile.delete();
  }
}
```

기존 기록 편집(`saveExport`) 흐름에서도 마찬가지로, 편집 원본이 더 이상 필요없는 경우 정리.

**테스트:**
- 편집 저장 후 원본 파일 삭제 확인
- 편집 없이 저장 시 원본 유지 확인 (originalVideoPath == null)

### Phase 2: 레코드 삭제 시 연관 파일 정리

**대상 파일:** `lib/providers/record_provider.dart` (RecordService)

```dart
static Future<void> deleteRecord(String recordId) async {
  // 1. DB에서 레코드 조회 (video_path, thumbnail_path 확보)
  final record = await _supabase
      .from('climbing_records')
      .select('video_path, thumbnail_path')
      .eq('id', recordId)
      .single();

  // 2. 로컬 비디오 파일 삭제
  final videoPath = record['video_path'] as String?;
  if (videoPath != null) {
    final videoFile = File(videoPath);
    if (await videoFile.exists()) await videoFile.delete();
  }

  // 3. 로컬 썸네일 삭제
  final thumbPath = record['thumbnail_path'] as String?;
  if (thumbPath != null) {
    final thumbFile = File(thumbPath);
    if (await thumbFile.exists()) await thumbFile.delete();
  }

  // 4. 자식 레코드(내보내기 영상)도 같이 삭제
  final children = await _supabase
      .from('climbing_records')
      .select('id, video_path, thumbnail_path')
      .eq('parent_record_id', recordId);
  for (final child in children) {
    // 자식 파일 삭제 후 DB 삭제
  }

  // 5. DB 레코드 삭제
  await _supabase.from('climbing_records').delete().eq('id', recordId);
}
```

**테스트:**
- 레코드 삭제 후 로컬 비디오, 썸네일 파일 삭제 확인
- 자식 레코드(내보내기 영상) 파일도 함께 삭제 확인

### Phase 3: 비디오 압축

**대상 파일:** `lib/services/video_export_service.dart`

- `ffmpeg_kit_flutter` (이미 프로젝트에 있음) 활용
- 저장 전 영상 압축: 해상도 720p 제한 + 적절한 CRF
- 편집 내보내기 시에도 인코딩 파라미터 적용

```dart
// FFmpeg export 명령에 추가
// -vf "scale=-2:720" -crf 23 -preset fast
```

촬영 직후 저장 시에도 압축 적용할지는 선택사항 (사용자 체감 화질 vs 용량 트레이드오프).

**테스트:**
- 압축 후 파일 크기 감소 확인
- 압축 후 영상 재생 정상 확인

### Phase 4: 계정 삭제 시 로컬 정리

**대상 파일:** `lib/providers/auth_provider.dart`

계정 삭제 로직에 로컬 파일 정리 추가:

```dart
Future<void> _cleanupLocalFiles() async {
  final appDir = await getApplicationDocumentsDirectory();
  final videosDir = Directory(p.join(appDir.path, 'videos'));
  final thumbsDir = Directory(p.join(appDir.path, 'thumbnails'));
  if (await videosDir.exists()) await videosDir.delete(recursive: true);
  if (await thumbsDir.exists()) await thumbsDir.delete(recursive: true);
  // edited_*.mp4 파일들도 정리
  final entries = appDir.listSync();
  for (final entry in entries) {
    if (entry is File && p.basename(entry.path).startsWith('edited_')) {
      await entry.delete();
    }
  }
}
```

**테스트:**
- 계정 삭제 후 로컬 디렉토리 비어있음 확인

### Phase 5 (선택): 저장 공간 관리 UI

**새 파일:** `lib/screens/storage_management_screen.dart`

- 설정 화면에 "저장 공간 관리" 메뉴 추가
- 현재 로컬 파일 용량 표시 (영상/썸네일/캐시 분류)
- "orphan 파일 정리" 버튼: DB에 없는 로컬 파일 탐지 및 삭제

---

## 구현 우선순위

| 순서 | Phase | 영향도 | 난이도 |
|------|-------|--------|--------|
| 1 | Phase 1: 편집 후 원본 삭제 | **높음** — 중복 파일 핵심 원인 | 낮음 |
| 2 | Phase 2: 레코드 삭제 시 파일 정리 | **중간** — orphan 파일 방지 | 낮음 |
| 3 | Phase 3: 비디오 압축 | **높음** — 파일 크기 자체 감소 | 중간 |
| 4 | Phase 4: 계정 삭제 시 정리 | **낮음** — 빈도 낮음 | 낮음 |
| 5 | Phase 5: 저장 공간 관리 UI | **낮음** — 편의 기능 | 중간 |

Phase 1~2만 해도 저장 공간 증가 문제의 대부분이 해결됩니다.
