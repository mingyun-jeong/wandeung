import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cling/models/subtitle_item.dart';
import 'package:cling/providers/subtitle_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('SubtitlesNotifier', () {
    test('starts with empty list', () {
      expect(container.read(subtitlesProvider), isEmpty);
    });

    test('addSubtitle adds item', () {
      const item = SubtitleItem(
        id: '1',
        text: '테스트',
        startTime: Duration.zero,
        endTime: Duration(seconds: 3),
      );
      container.read(subtitlesProvider.notifier).addSubtitle(item);
      expect(container.read(subtitlesProvider), hasLength(1));
      expect(container.read(subtitlesProvider).first.text, '테스트');
    });

    test('updateSubtitle updates existing item', () {
      const item = SubtitleItem(
        id: '1',
        text: '원본',
        startTime: Duration.zero,
        endTime: Duration(seconds: 3),
      );
      container.read(subtitlesProvider.notifier).addSubtitle(item);
      container.read(subtitlesProvider.notifier).updateSubtitle(
            '1',
            item.copyWith(text: '수정됨'),
          );
      expect(container.read(subtitlesProvider).first.text, '수정됨');
    });

    test('removeSubtitle removes item', () {
      const item = SubtitleItem(
        id: '1',
        text: '삭제할것',
        startTime: Duration.zero,
        endTime: Duration(seconds: 3),
      );
      container.read(subtitlesProvider.notifier).addSubtitle(item);
      container.read(subtitlesProvider.notifier).removeSubtitle('1');
      expect(container.read(subtitlesProvider), isEmpty);
    });

    test('updatePosition updates position', () {
      const item = SubtitleItem(
        id: '1',
        text: 'pos',
        startTime: Duration.zero,
        endTime: Duration(seconds: 3),
      );
      container.read(subtitlesProvider.notifier).addSubtitle(item);
      container.read(subtitlesProvider.notifier).updatePosition(
            '1',
            const Offset(0.3, 0.7),
          );
      expect(container.read(subtitlesProvider).first.position,
          const Offset(0.3, 0.7));
    });

    test('reset clears all items', () {
      container.read(subtitlesProvider.notifier).addSubtitle(const SubtitleItem(
        id: '1', text: 'a', startTime: Duration.zero, endTime: Duration(seconds: 1),
      ));
      container.read(subtitlesProvider.notifier).addSubtitle(const SubtitleItem(
        id: '2', text: 'b', startTime: Duration.zero, endTime: Duration(seconds: 1),
      ));
      container.read(subtitlesProvider.notifier).reset();
      expect(container.read(subtitlesProvider), isEmpty);
    });
  });

  group('selectedSubtitleIdProvider', () {
    test('starts as null', () {
      expect(container.read(selectedSubtitleIdProvider), isNull);
    });
  });
}
