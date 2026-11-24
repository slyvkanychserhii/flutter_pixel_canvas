import 'dart:ui';

import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_atlas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PixelAtlas.load', () {
    late PixelAtlas atlas;
    setUpAll(() async => atlas = await loadTestAtlas());
    tearDownAll(() => atlas.dispose());

    test('читает кадры', () {
      expect(atlas.frame('half'), const Rect.fromLTWH(0, 0, 8, 8));
      expect(atlas.frame('wide'), const Rect.fromLTWH(0, 8, 6, 2));
      expect(atlas.frame('нет такого'), isNull);
      expect(atlas.frameNames, containsAll(['half', 'full', 'wide']));
    });

    test('читает шрифт', () {
      final font = atlas.font('f')!;
      expect(font.lineHeight, 5);
      expect(font.spacing, 1);
      expect(font.glyphs['A'.runes.first], 'ga');
      expect(atlas.font('нет'), isNull);
    });

    test('запоминает прозрачность пикселей', () {
      // half: непрозрачна левая половина (x 0..3).
      expect(atlas.alphaAt(1, 1), 255);
      expect(atlas.alphaAt(5, 1), 0);
      expect(atlas.isSolid(1, 1), isTrue);
      expect(atlas.isSolid(5, 1), isFalse);
      // За границами картинки прозрачно.
      expect(atlas.alphaAt(-1, 0), 0);
      expect(atlas.alphaAt(0, 99), 0);
      expect(atlas.alphaAt(99, 0), 0);
    });
  });

  group('PixelAnimation', () {
    late PixelAtlas atlas;
    setUpAll(() async => atlas = await loadTestAtlas());
    tearDownAll(() => atlas.dispose());

    test('зацикленная идёт по кругу и не заканчивается', () {
      final animation = atlas.animation('anim')!;
      expect(animation.frameAt(Duration.zero), 'half');
      expect(animation.frameAt(const Duration(milliseconds: 600)), 'full');
      expect(animation.frameAt(const Duration(seconds: 1)), 'half');
      expect(animation.frameAt(const Duration(milliseconds: 101600)), 'full');
      expect(animation.isFinished(const Duration(hours: 1)), isFalse);
    });

    test('обычная замирает на последнем кадре', () {
      final animation = atlas.animation('once')!;
      expect(animation.duration, const Duration(seconds: 1));
      expect(animation.frameAt(const Duration(milliseconds: 400)), 'half');
      expect(animation.frameAt(const Duration(seconds: 10)), 'full');
      expect(animation.isFinished(const Duration(milliseconds: 999)), isFalse);
      expect(animation.isFinished(const Duration(seconds: 1)), isTrue);
    });

    test('до старта показывает первый кадр', () {
      final animation = atlas.animation('once')!;
      expect(animation.frameAt(const Duration(seconds: -1)), 'half');
    });
  });

  group('PixelAtlas.load: ошибки описания', () {
    // Копия описания с изменением.
    Map<String, Object?> broken(void Function(Map<String, Object?>) change) {
      final json = Map<String, Object?>.of(testAtlasJson);
      change(json);
      return json;
    }

    test('нет поля image', () {
      final json = broken((j) => j.remove('image'));
      expect(loadTestAtlas(json: json), throwsA(isA<FormatException>()));
    });

    test('нет объекта frames', () {
      final json = broken((j) => j.remove('frames'));
      expect(loadTestAtlas(json: json), throwsA(isA<FormatException>()));
    });

    test('кадр выходит за картинку', () {
      final json = broken((j) => j['frames'] = {
            'bad': {'x': 30, 'y': 0, 'w': 8, 'h': 8},
          });
      expect(loadTestAtlas(json: json), throwsA(isA<FormatException>()));
    });

    test('у кадра нет размера', () {
      final json = broken((j) => j['frames'] = {
            'bad': {'x': 0, 'y': 0},
          });
      expect(loadTestAtlas(json: json), throwsA(isA<FormatException>()));
    });

    test('глиф ссылается на несуществующий кадр', () {
      final json = broken((j) => j['fonts'] = {
            'f': {
              'lineHeight': 5,
              'glyphs': {'A': 'нет такого'},
            },
          });
      expect(loadTestAtlas(json: json), throwsA(isA<FormatException>()));
    });

    test('анимация ссылается на несуществующий кадр', () {
      final json = broken((j) => j['animations'] = {
            'bad': {
              'frames': ['нет такого'],
              'fps': 1,
            },
          });
      expect(loadTestAtlas(json: json), throwsA(isA<FormatException>()));
    });
  });
}
