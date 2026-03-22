import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 갤러리 저장 경로 옵션
enum GallerySavePath {
  /// 기본: '리클림' 앨범에 저장
  defaultAlbum,

  /// 암장별: 암장 이름 앨범에 저장
  byGym,
}

const _prefKey = 'gallery_save_path';

final gallerySavePathProvider =
    StateNotifierProvider<GallerySavePathNotifier, GallerySavePath>((ref) {
  return GallerySavePathNotifier();
});

class GallerySavePathNotifier extends StateNotifier<GallerySavePath> {
  GallerySavePathNotifier() : super(GallerySavePath.defaultAlbum) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefKey);
    if (value != null) {
      state = GallerySavePath.values.firstWhere(
        (e) => e.name == value,
        orElse: () => GallerySavePath.defaultAlbum,
      );
    }
  }

  Future<void> set(GallerySavePath path) async {
    state = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, path.name);
  }
}

/// 설정과 암장 정보를 기반으로 갤러리 앨범 이름을 반환
String resolveGalleryAlbum(
  GallerySavePath savePath, {
  String? gymName,
}) {
  switch (savePath) {
    case GallerySavePath.byGym:
      if (gymName != null && gymName.isNotEmpty) return gymName;
      return '리클림';
    case GallerySavePath.defaultAlbum:
      return '리클림';
  }
}
