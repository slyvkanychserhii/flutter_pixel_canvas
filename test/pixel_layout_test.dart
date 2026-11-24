import 'package:flutter/painting.dart';
import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';
import 'package:flutter_pixel_canvas/src/pixel_layout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_atlas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PixelAtlas atlas;
  setUpAll(() async => atlas = await loadTestAtlas());
  tearDownAll(() => atlas.dispose());

  // Раскладывает один слой на сцене 100 x 50; кадр спрайта это его frame.
  PixelSceneLayout place(List<PixelObject> items) => layoutScene(
        layers: [PixelLayer(id: 'l', items: items)],
        atlas: atlas,
        sceneSize: const Size(100, 50),
        frameOf: (sprite) => sprite.frame,
      );

  // Положение i-го объекта единственного слоя.
  Offset at(PixelSceneLayout layout, int i) => layout.layers[0][i]!.position;

  group('выравнивание по холсту', () {
    test('по умолчанию (x, y) это левый верхний угол', () {
      final layout = place(const [PixelSprite(frame: 'full', x: 3, y: 4)]);
      expect(at(layout, 0), const Offset(3, 4));
    });

    test('правый нижний угол с отступом', () {
      final layout = place(const [
        PixelSprite(
            frame: 'full', align: Alignment.bottomRight, x: -2, y: -2),
      ]);
      expect(at(layout, 0), const Offset(90, 40)); // 100-8-2, 50-8-2
    });

    test('центр', () {
      final layout =
          place(const [PixelSprite(frame: 'full', align: Alignment.center)]);
      expect(at(layout, 0), const Offset(46, 21)); // 50-4, 25-4
    });

    test('дробный результат округляется до целого пикселя', () {
      // Текст "AA": ширина 3 + 1 + 3 = 7, высота 5. Центр: 46.5 и 22.5.
      final layout = place(const [
        PixelText(text: 'AA', font: 'f', align: Alignment.center),
      ]);
      expect(layout.layers[0][0]!.size, const Size(7, 5));
      expect(at(layout, 0), const Offset(47, 23));
    });
  });

  group('привязка к объекту', () {
    test('подпись под объектом', () {
      final layout = place(const [
        PixelSprite(id: 'a', frame: 'full', x: 10, y: 10),
        PixelSprite(
          frame: 'half',
          anchor: 'a',
          anchorAlign: Alignment.bottomCenter,
          align: Alignment.topCenter,
          y: 2,
        ),
      ]);
      // Низ-центр опоры (14, 18), центр-верх объекта (4, 0), плюс y: 2.
      expect(at(layout, 1), const Offset(10, 20));
    });

    test('цепочка: объект крепится к объекту, который крепится к объекту', () {
      final layout = place(const [
        PixelSprite(id: 'a', frame: 'full', x: 10, y: 10),
        PixelSprite(id: 'b', frame: 'full', anchor: 'a', x: 20),
        PixelSprite(frame: 'full', anchor: 'b', y: 20),
      ]);
      expect(at(layout, 1), const Offset(30, 10));
      expect(at(layout, 2), const Offset(30, 30));
    });

    test('опора может лежать ниже в списке (разрешается по требованию)', () {
      final layout = place(const [
        PixelSprite(frame: 'full', anchor: 'b', x: 5),
        PixelSprite(id: 'b', frame: 'full', x: 10, y: 10),
      ]);
      expect(at(layout, 0), const Offset(15, 10));
    });

    test('нет опоры с таким id: крепится к холсту', () {
      final layout = place(const [
        PixelSprite(frame: 'full', anchor: 'нет такого', x: 3, y: 4),
      ]);
      expect(at(layout, 0), const Offset(3, 4));
    });

    test('опора не рисуется (нет кадра): крепится к холсту', () {
      final layout = place(const [
        PixelSprite(id: 'a', frame: 'нет такого', x: 50, y: 20),
        PixelSprite(frame: 'full', anchor: 'a', x: 3, y: 4),
      ]);
      expect(layout.layers[0][0], isNull);
      expect(at(layout, 1), const Offset(3, 4));
    });

    test('цикл разрывается без ошибки', () {
      final layout = place(const [
        PixelSprite(id: 'a', frame: 'full', anchor: 'b', x: 5),
        PixelSprite(id: 'b', frame: 'full', anchor: 'a', x: 7),
      ]);
      // b дошёл до опоры a, которая ещё считается, и крепится к холсту.
      expect(at(layout, 1), const Offset(7, 0));
      expect(at(layout, 0), const Offset(12, 0));
    });

    test('объект, привязанный к самому себе, крепится к холсту', () {
      final layout = place(const [
        PixelSprite(id: 'a', frame: 'full', anchor: 'a', x: 6),
      ]);
      expect(at(layout, 0), const Offset(6, 0));
    });
  });

  group('размер объекта', () {
    test('zoom увеличивает', () {
      final layout = place(const [PixelSprite(frame: 'wide', zoom: 3)]);
      expect(layout.layers[0][0]!.size, const Size(18, 6));
    });

    test('поворот на четверть меняет ширину и высоту', () {
      final layout = place(const [
        PixelSprite(frame: 'wide', quarterTurns: 1, zoom: 2),
        PixelSprite(frame: 'wide', quarterTurns: 2),
        PixelSprite(frame: 'wide', quarterTurns: -1), // = 3
      ]);
      expect(layout.layers[0][0]!.size, const Size(4, 12));
      expect(layout.layers[0][1]!.size, const Size(6, 2));
      expect(layout.layers[0][2]!.size, const Size(2, 6));
    });

    test('отражение размер не меняет', () {
      final layout = place(const [PixelSprite(frame: 'wide', flipX: true)]);
      expect(layout.layers[0][0]!.size, const Size(6, 2));
    });

    test('выравнивание считается по размеру после поворота', () {
      final layout = place(const [
        PixelSprite(
            frame: 'wide', quarterTurns: 1, align: Alignment.bottomRight),
      ]);
      // Повёрнутый спрайт 2 x 6 в правом нижнем углу.
      expect(at(layout, 0), const Offset(98, 44));
    });

    test('кадр берётся у frameOf (кадр анимации)', () {
      final layout = layoutScene(
        layers: const [
          PixelLayer(id: 'l', items: [PixelSprite(frame: 'full')]),
        ],
        atlas: atlas,
        sceneSize: const Size(100, 50),
        frameOf: (_) => 'wide',
      );
      expect(layout.layers[0][0]!.size, const Size(6, 2));
    });
  });

  group('что не раскладывается', () {
    test('примитив, неизвестный кадр, неизвестный шрифт: null', () {
      final layout = place(const [
        PixelPoint(x: 1, y: 1, color: Color(0xFFFFFFFF)),
        PixelSprite(frame: 'нет такого'),
        PixelText(text: 'A', font: 'нет такого'),
      ]);
      expect(layout.layers[0], everyElement(isNull));
    });

    test('без атласа спрайты и тексты не рисуются', () {
      final layout = layoutScene(
        layers: const [
          PixelLayer(id: 'l', items: [
            PixelSprite(frame: 'full'),
            PixelText(text: 'A', font: 'f'),
          ]),
        ],
        atlas: null,
        sceneSize: const Size(100, 50),
        frameOf: (sprite) => sprite.frame,
      );
      expect(layout.layers[0], everyElement(isNull));
    });
  });

  group('раскладка текста', () {
    test('перенос строки и неизвестный символ', () {
      final two = layoutText(const PixelText(text: 'A\nA', font: 'f'), atlas)!;
      expect(two.size, const Size(3, 10)); // две строки по 5
      expect(two.glyphs.length, 2);

      // '#' нет в шрифте и '?' тоже нет: символ пропускается.
      final skipped =
          layoutText(const PixelText(text: 'A#A', font: 'f'), atlas)!;
      expect(skipped.glyphs.length, 2);
    });

    test('нет шрифта: null', () {
      expect(layoutText(const PixelText(text: 'A', font: 'x'), atlas), isNull);
    });
  });
}
