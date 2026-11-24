import 'dart:ui';

import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_atlas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PixelAtlas atlas;
  setUpAll(() async => atlas = await loadTestAtlas());
  tearDownAll(() => atlas.dispose());

  group('parsePixelColor', () {
    test('шестнадцатеричные записи', () {
      expect(parsePixelColor('#f00'), const Color(0xFFFF0000));
      expect(parsePixelColor('#00FF00'), const Color(0xFF00FF00));
      expect(parsePixelColor('#80112233'), const Color(0x80112233));
    });

    test('имена цветов без учёта регистра', () {
      expect(parsePixelColor('Red'), isNotNull);
      expect(parsePixelColor('white'), const Color(0xFFFFFFFF));
    });

    test('непонятные значения дают null', () {
      expect(parsePixelColor('#12'), isNull);
      expect(parsePixelColor('#GGGGGG'), isNull);
      expect(parsePixelColor('нет'), isNull);
      expect(parsePixelColor('ff0000'), isNull);
    });
  });

  group('parsePixelMarkup', () {
    test('текст без тегов не меняется', () {
      final m = parsePixelMarkup('abc');
      expect(m.text, 'abc');
      expect(m.colors, [null, null, null]);
    });

    test('тег красит только свой кусок', () {
      final m = parsePixelMarkup('a<color=#f00>bc</color>d');
      expect(m.text, 'abcd');
      expect(m.colors, [null, const Color(0xFFFF0000), const Color(0xFFFF0000), null]);
    });

    test('вложенные теги: после внутреннего возвращается внешний цвет', () {
      final m = parsePixelMarkup('<color=red>a<color=blue>b</color>c</color>');
      expect(m.text, 'abc');
      expect(m.colors[0], parsePixelColor('red'));
      expect(m.colors[1], parsePixelColor('blue'));
      expect(m.colors[2], parsePixelColor('red'));
    });

    test('<< даёт один символ <', () {
      final m = parsePixelMarkup('1 << 2');
      expect(m.text, '1 < 2');
    });

    test('незакрытый тег действует до конца', () {
      final m = parsePixelMarkup('<color=#0f0>ab');
      expect(m.text, 'ab');
      expect(m.colors, everyElement(const Color(0xFF00FF00)));
    });

    test('непонятный тег и лишний закрывающий остаются текстом', () {
      expect(parsePixelMarkup('<color=zzz>a').text, '<color=zzz>a');
      expect(parsePixelMarkup('a</color>').text, 'a</color>');
      expect(parsePixelMarkup('a < b').text, 'a < b');
      expect(parsePixelMarkup('<color=red').text, '<color=red');
    });

    test('перенос строки внутри тега сохраняется', () {
      final m = parsePixelMarkup('<color=red>a\nb</color>');
      expect(m.text, 'a\nb');
      expect(m.colors, hasLength(3));
    });

    test('цвета считаются по символам, а не по кодовым единицам', () {
      final m = parsePixelMarkup('😀<color=red>a</color>');
      expect(m.colors, [null, parsePixelColor('red')]);
    });
  });

  group('раскладка с разметкой', () {
    test('теги не занимают места и красят глифы', () {
      final plain = layoutText(const PixelText(text: 'AA', font: 'f'), atlas)!;
      final marked = layoutText(
        const PixelText(text: '<color=#f00>A</color>A', font: 'f', markup: true),
        atlas,
      )!;
      expect(marked.size, plain.size);
      expect(marked.glyphs, hasLength(2));
      expect(marked.glyphs[0].color, const Color(0xFFFF0000));
      expect(marked.glyphs[1].color, isNull);
      expect(marked.glyphs[1].position, plain.glyphs[1].position);
    });

    test('без markup теги выводятся как обычные символы', () {
      final l = layoutText(
        const PixelText(text: '<color=#f00>A</color>', font: 'f'),
        atlas,
      )!;
      expect(l.glyphs.every((g) => g.color == null), isTrue);
    });
  });
}
