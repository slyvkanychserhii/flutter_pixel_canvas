import 'dart:ui';

import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';
import 'package:flutter_pixel_canvas/src/pixel_hit_test.dart';
import 'package:flutter_pixel_canvas/src/pixel_scene.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_atlas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PixelAtlas atlas;
  setUpAll(() async => atlas = await loadTestAtlas());
  tearDownAll(() => atlas.dispose());

  // Нажатие в пиксель (x, y) сцены 100 x 50.
  PixelHit? tap(
    List<PixelLayer> layers,
    int x,
    int y, {
    String Function(PixelSprite)? frameOf,
  }) {
    final scene = PixelScene.build(
      layers: layers,
      atlas: atlas,
      sceneSize: const Size(100, 50),
      frames: const [],
      frameOf: frameOf ?? (sprite) => sprite.frame,
    );
    return hitTestLayers(layers, scene, x, y);
  }

  PixelHit? tapItems(List<PixelObject> items, int x, int y) =>
      tap([PixelLayer(id: 'l', items: items)], x, y);

  group('порядок и слои', () {
    test('верхний слой перекрывает нижний', () {
      final layers = [
        const PixelLayer(
            id: 'low', items: [PixelSprite(id: 'a', frame: 'full')]),
        const PixelLayer(
            id: 'high', items: [PixelSprite(id: 'b', frame: 'full')]),
      ];
      final hit = tap(layers, 2, 2)!;
      expect(hit.id, 'b');
      expect(hit.layerId, 'high');
    });

    test('внутри слоя последний объект сверху', () {
      final hit = tapItems(const [
        PixelSprite(id: 'a', frame: 'full'),
        PixelSprite(id: 'b', frame: 'full'),
      ], 2, 2)!;
      expect(hit.id, 'b');
    });

    test('невидимый слой пропускается', () {
      final layers = [
        const PixelLayer(
            id: 'low', items: [PixelSprite(id: 'a', frame: 'full')]),
        const PixelLayer(
          id: 'high',
          visible: false,
          items: [PixelSprite(id: 'b', frame: 'full')],
        ),
      ];
      expect(tap(layers, 2, 2)!.id, 'a');
    });

    test('мимо графики пусто', () {
      expect(tapItems(const [PixelSprite(frame: 'full')], 50, 40), isNull);
    });

    test('в hit лежит прямоугольник объекта на сцене', () {
      final hit = tapItems(const [
        PixelSprite(id: 'a', frame: 'full', x: 10, y: 20),
      ], 12, 22)!;
      expect(hit.bounds, const Rect.fromLTWH(10, 20, 8, 8));
      expect(hit.sprite, isNotNull);
    });
  });

  group('спрайт: по пикселям и по прямоугольнику', () {
    // half: непрозрачна левая половина, x 0..3.
    test('по пикселям: прозрачная половина пропускает нажатие', () {
      final items = [const PixelSprite(frame: 'half')];
      expect(tapItems(items, 1, 3), isNotNull);
      expect(tapItems(items, 6, 3), isNull);
    });

    test('по прямоугольнику: попадает и прозрачная часть', () {
      final items = [
        const PixelSprite(frame: 'half', hitArea: PixelHitArea.bounds),
      ];
      expect(tapItems(items, 6, 3), isNotNull);
      expect(tapItems(items, 9, 3), isNull); // за кадром
    });

    test('прозрачный верхний объект пропускает нажатие нижнему', () {
      final hit = tapItems(const [
        PixelSprite(id: 'low', frame: 'full'),
        PixelSprite(id: 'top', frame: 'half'),
      ], 6, 3)!;
      expect(hit.id, 'low');
    });

    test('смотрит кадр, который показан сейчас (анимация)', () {
      final layers = [
        const PixelLayer(id: 'l', items: [
          PixelSprite(id: 'a', frame: 'half', animation: 'anim'),
        ]),
      ];
      expect(tap(layers, 6, 3, frameOf: (_) => 'half'), isNull);
      expect(tap(layers, 6, 3, frameOf: (_) => 'full'), isNotNull);
    });
  });

  group('спрайт с преобразованиями (half: непрозрачна левая половина)', () {
    // Повёрнутый на четверть по часовой левый край становится верхним.
    test('поворот на 1: непрозрачна верхняя половина', () {
      final items = [const PixelSprite(frame: 'half', quarterTurns: 1)];
      expect(tapItems(items, 3, 1), isNotNull);
      expect(tapItems(items, 3, 6), isNull);
    });

    test('поворот на 3: непрозрачна нижняя половина', () {
      final items = [const PixelSprite(frame: 'half', quarterTurns: 3)];
      expect(tapItems(items, 3, 6), isNotNull);
      expect(tapItems(items, 3, 1), isNull);
    });

    test('поворот на 2: непрозрачна правая половина', () {
      final items = [const PixelSprite(frame: 'half', quarterTurns: 2)];
      expect(tapItems(items, 6, 3), isNotNull);
      expect(tapItems(items, 1, 3), isNull);
    });

    test('flipX: непрозрачна правая половина', () {
      final items = [const PixelSprite(frame: 'half', flipX: true)];
      expect(tapItems(items, 6, 3), isNotNull);
      expect(tapItems(items, 1, 3), isNull);
    });

    test('flipY не меняет левую половину', () {
      final items = [const PixelSprite(frame: 'half', flipY: true)];
      expect(tapItems(items, 1, 3), isNotNull);
      expect(tapItems(items, 6, 3), isNull);
    });

    test('zoom 2: непрозрачна левая половина 16 x 16', () {
      final items = [const PixelSprite(frame: 'half', zoom: 2)];
      expect(tapItems(items, 7, 3), isNotNull);
      expect(tapItems(items, 9, 3), isNull);
      expect(tapItems(items, 7, 15), isNotNull);
    });
  });

  group('текст', () {
    // "A A": глиф A (x 0..2), пробел (x 4..5, прозрачный), глиф A (x 7..9).
    test('по прямоугольнику (по умолчанию) просвет нажимается', () {
      final items = [const PixelText(text: 'A A', font: 'f')];
      expect(tapItems(items, 5, 2), isNotNull);
    });

    test('по пикселям просвет пропускает нажатие', () {
      final items = [
        const PixelText(text: 'A A', font: 'f', hitArea: PixelHitArea.pixels),
      ];
      expect(tapItems(items, 1, 2), isNotNull);
      expect(tapItems(items, 5, 2), isNull);
      expect(tapItems(items, 8, 2), isNotNull);
    });

    test('нажатие вне текста мимо', () {
      expect(tapItems(const [PixelText(text: 'A', font: 'f')], 50, 40), isNull);
    });
  });

  group('примитивы', () {
    const color = Color(0xFFFFFFFF);

    test('прямоугольник', () {
      final items = [
        const PixelRect(id: 'r', x: 10, y: 10, width: 5, height: 5, color: color),
      ];
      expect(tapItems(items, 12, 12)!.id, 'r');
      expect(tapItems(items, 15, 12), isNull);
    });

    test('контур не нажимается изнутри', () {
      final items = [
        const PixelRect(
            id: 'r',
            x: 10,
            y: 10,
            width: 10,
            height: 10,
            filled: false,
            color: color),
      ];
      expect(tapItems(items, 10, 12)!.id, 'r');
      expect(tapItems(items, 14, 14), isNull);
    });

    test('примитив в невидимом слое не нажимается', () {
      final layers = [
        const PixelLayer(id: 'l', visible: false, items: [
          PixelRect(x: 0, y: 0, width: 10, height: 10, color: color),
        ]),
      ];
      expect(tap(layers, 2, 2), isNull);
    });
  });
}
