import 'package:flutter/widgets.dart';
import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_atlas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PixelAtlas atlas;
  setUpAll(() async => atlas = await loadTestAtlas());
  tearDownAll(() => atlas.dispose());

  // Холст 200 x 100 в левом верхнем углу экрана: координаты нажатия на
  // экране совпадают с координатами внутри холста.
  Widget host(Widget canvas) => Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 200, height: 100, child: canvas),
        ),
      );

  testWidgets('занимает всё место родителя', (tester) async {
    await tester.pumpWidget(host(PixelCanvas(atlas: atlas)));
    expect(tester.getSize(find.byType(PixelCanvas)), const Size(200, 100));
  });

  testWidgets('без ограничений родителя сообщает понятную ошибку',
      (tester) async {
    // После понятной ошибки холст остаётся без размера, и Flutter сыплет
    // ещё несколько следующих за ней ошибок раскладки. tester.takeException
    // в таком случае отдаёт общую обёртку, поэтому собираем ошибки сами.
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          // В Column высота не ограничена.
          child: Column(children: [PixelCanvas(atlas: atlas)]),
        ),
      );
    } finally {
      FlutterError.onError = previous;
    }

    expect(
      errors.map((e) => e.exception.toString()),
      anyElement(contains('Оберните холст в Expanded или SizedBox')),
    );
  });

  group('onTap', () {
    // Спрайт 8 x 8 в левом верхнем углу сцены; масштаб 4: на экране он
    // занимает квадрат 32 x 32.
    testWidgets('сообщает пиксель сцены и объект', (tester) async {
      final taps = <PixelTap>[];
      await tester.pumpWidget(host(PixelCanvas(
        scale: 4,
        atlas: atlas,
        layers: const [
          PixelLayer(id: 'main', items: [PixelSprite(id: 'x', frame: 'full')]),
        ],
        onTap: taps.add,
      )));

      await tester.tapAt(const Offset(10, 10)); // пиксель сцены (2, 2)
      expect(taps.single.x, 2);
      expect(taps.single.y, 2);
      expect(taps.single.hit!.id, 'x');
      expect(taps.single.hit!.layerId, 'main');
    });

    testWidgets('мимо графики сообщает пустой hit (режим capture)',
        (tester) async {
      final taps = <PixelTap>[];
      await tester.pumpWidget(host(PixelCanvas(
        scale: 4,
        atlas: atlas,
        layers: const [
          PixelLayer(id: 'main', items: [PixelSprite(id: 'x', frame: 'full')]),
        ],
        onTap: taps.add,
      )));

      await tester.tapAt(const Offset(150, 80));
      expect(taps.single.hit, isNull);
      expect(taps.single.x, 37); // 150 / 4
      expect(taps.single.y, 20); // 80 / 4
    });

    testWidgets('учитывает выравнивание', (tester) async {
      final taps = <PixelTap>[];
      await tester.pumpWidget(host(PixelCanvas(
        scale: 4,
        atlas: atlas,
        layers: const [
          PixelLayer(id: 'main', items: [
            PixelSprite(
                id: 'corner', frame: 'full', align: Alignment.bottomRight),
          ]),
        ],
        onTap: taps.add,
      )));

      // Сцена 50 x 25, спрайт в её правом нижнем углу: пиксели (42..49, 17..24).
      await tester.tapAt(const Offset(190, 90)); // пиксель (47, 22)
      expect(taps.single.hit!.id, 'corner');
    });
  });

  group('дочерний виджет', () {
    // Кнопка (40 x 40 экранных пикселей) в правом нижнем углу холста и
    // спрайт, лежащий поверх её левого верхнего угла: сцена 50 x 25 при
    // масштабе 4, спрайт 8 x 8 в пикселях сцены (40, 15) закрывает на
    // экране квадрат (160..192, 60..92).
    Widget canvas({
      required PixelTouchMode mode,
      required VoidCallback onButton,
      required List<PixelTap> taps,
    }) {
      return host(PixelCanvas(
        scale: 4,
        atlas: atlas,
        touchMode: mode,
        layers: const [
          PixelLayer(
              id: 'main',
              items: [PixelSprite(id: 'cover', frame: 'full', x: 40, y: 15)]),
        ],
        onTap: taps.add,
        child: Align(
          alignment: Alignment.bottomRight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onButton,
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ));
    }

    testWidgets('graphicsOnly: под графикой кнопка не нажимается',
        (tester) async {
      var button = 0;
      final taps = <PixelTap>[];
      await tester.pumpWidget(canvas(
        mode: PixelTouchMode.graphicsOnly,
        onButton: () => button++,
        taps: taps,
      ));

      await tester.tapAt(const Offset(170, 70)); // кнопка под спрайтом
      expect(button, 0);
      expect(taps.single.hit!.id, 'cover');
    });

    testWidgets('graphicsOnly: мимо графики кнопка нажимается', (tester) async {
      var button = 0;
      final taps = <PixelTap>[];
      await tester.pumpWidget(canvas(
        mode: PixelTouchMode.graphicsOnly,
        onButton: () => button++,
        taps: taps,
      ));

      await tester.tapAt(const Offset(195, 95)); // кнопка вне спрайта
      expect(button, 1);
      expect(taps, isEmpty); // холст сообщает только о нажатиях на графику
    });

    testWidgets('capture: все нажатия достаются холсту', (tester) async {
      var button = 0;
      final taps = <PixelTap>[];
      await tester.pumpWidget(canvas(
        mode: PixelTouchMode.capture,
        onButton: () => button++,
        taps: taps,
      ));

      await tester.tapAt(const Offset(195, 95));
      expect(button, 0);
      expect(taps.single.hit, isNull);
    });

    testWidgets('transparent: кнопка нажимается и под графикой, холст тоже узнаёт',
        (tester) async {
      var button = 0;
      final taps = <PixelTap>[];
      await tester.pumpWidget(canvas(
        mode: PixelTouchMode.transparent,
        onButton: () => button++,
        taps: taps,
      ));

      await tester.tapAt(const Offset(170, 70));
      expect(button, 1);
      expect(taps.single.hit!.id, 'cover');
    });
  });
}
