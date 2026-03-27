import 'package:flutter_test/flutter_test.dart';
import 'package:cling/providers/gallery_save_path_provider.dart';

void main() {
  group('GallerySavePath', () {
    test('defaultAlbum과 byGym 두 가지 값이 존재한다', () {
      expect(GallerySavePath.values.length, 2);
      expect(GallerySavePath.defaultAlbum.name, 'defaultAlbum');
      expect(GallerySavePath.byGym.name, 'byGym');
    });
  });

  group('resolveGalleryAlbum', () {
    test('defaultAlbum이면 항상 "리클림"을 반환한다', () {
      expect(
        resolveGalleryAlbum(GallerySavePath.defaultAlbum),
        '리클림',
      );
    });

    test('defaultAlbum이면 gymName이 있어도 "리클림"을 반환한다', () {
      expect(
        resolveGalleryAlbum(GallerySavePath.defaultAlbum, gymName: '더클라임 신사'),
        '리클림',
      );
    });

    test('byGym이고 gymName이 있으면 해당 이름을 반환한다', () {
      expect(
        resolveGalleryAlbum(GallerySavePath.byGym, gymName: '더클라임 신사'),
        '더클라임 신사',
      );
    });

    test('byGym이고 gymName이 null이면 "리클림"을 반환한다', () {
      expect(
        resolveGalleryAlbum(GallerySavePath.byGym, gymName: null),
        '리클림',
      );
    });

    test('byGym이고 gymName이 빈 문자열이면 "리클림"을 반환한다', () {
      expect(
        resolveGalleryAlbum(GallerySavePath.byGym, gymName: ''),
        '리클림',
      );
    });

    test('byGym이고 gymName을 전달하지 않으면 "리클림"을 반환한다', () {
      expect(
        resolveGalleryAlbum(GallerySavePath.byGym),
        '리클림',
      );
    });
  });
}
