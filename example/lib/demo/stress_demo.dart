import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';

import 'atlas_loader.dart';

/// Демонстрация 11: нагрузка.
///
/// На холст кладётся много спрайтов, примитивов и текстов, часть спрайтов
/// анимирована. Сверху счётчик кадров в секунду (FPS) всего экрана: это
/// грубая проверка, что холст не тормозит. Чем выше число объектов, тем
/// заметнее выигрыш от кэша сцены: раскладка, растр примитивов и массивы
/// для drawRawAtlas строятся один раз и пересобираются только когда сменился
/// кадр анимации или изменились слои.
///
/// Переключатель «Анимация» включает циклическую анимацию у каждого
/// десятого спрайта: тогда сцена обновляется при каждой смене кадра. Без
/// анимации холст после первого кадра вообще не перерисовывается.
class StressDemo extends StatefulWidget {
  const StressDemo({super.key});

  @override
  State<StressDemo> createState() => _StressDemoState();
}

class _StressDemoState extends State<StressDemo>
    with SingleTickerProviderStateMixin {
  static const _counts = [100, 1000, 5000, 20000];
  static const _frames = ['red', 'green', 'blue', 'yellow', 'heart', 'smiley'];

  // Размер сцены, в которой разбросаны объекты (в пикселях сцены).
  static const _sceneW = 240;
  static const _sceneH = 360;

  int _count = 1000;
  bool _animated = true;
  int _scale = 2;

  // Слои пересобираются только при смене настроек (а не при каждой
  // пересборке экрана): тогда холст получает тот же список и использует
  // кэш сцены.
  late List<PixelLayer> _layers = _buildLayers();

  // Счётчик FPS: тикер вызывается перед каждым кадром экрана.
  late final Ticker _ticker = createTicker(_onTick);
  int _frameCount = 0;
  Duration _lastReport = Duration.zero;
  int _fps = 0;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    _frameCount++;
    // Раз в секунду показываем, сколько кадров набралось.
    if (elapsed - _lastReport >= const Duration(seconds: 1)) {
      setState(() {
        _fps = _frameCount;
        _frameCount = 0;
        _lastReport = elapsed;
      });
    }
  }

  // Строит слои с _count объектов. Random с постоянным числом: при одних и
  // тех же настройках картинка одна и та же.
  List<PixelLayer> _buildLayers() {
    final random = math.Random(1);
    final sprites = <PixelObject>[];
    final primitives = <PixelObject>[];

    for (var i = 0; i < _count; i++) {
      final x = random.nextInt(_sceneW);
      final y = random.nextInt(_sceneH);
      final animated = _animated && i % 10 == 0;
      sprites.add(PixelSprite(
        frame: _frames[random.nextInt(_frames.length)],
        x: x,
        y: y,
        // У анимированного спрайта обязателен id.
        id: animated ? 'a$i' : null,
        animation: animated ? 'cycle' : null,
      ));
    }

    // Примитивов в десять раз меньше: они дороже (растр и Path).
    for (var i = 0; i < _count ~/ 10; i++) {
      final x = random.nextInt(_sceneW);
      final y = random.nextInt(_sceneH);
      final color = Color(0xFF000000 | random.nextInt(0xFFFFFF));
      primitives.add(i.isEven
          ? PixelLine(
              x0: x,
              y0: y,
              x1: x + random.nextInt(40) - 20,
              y1: y + random.nextInt(40) - 20,
              color: color,
            )
          : PixelCircle(
              cx: x,
              cy: y,
              radius: 1 + random.nextInt(6),
              color: color,
              filled: false,
            ));
    }

    return [
      PixelLayer(id: 'sprites', items: sprites),
      PixelLayer(id: 'primitives', items: primitives),
      const PixelLayer(id: 'hud', items: [
        PixelText(
          text: 'Нагрузка',
          font: 'main',
          x: 2,
          y: 2,
          color: Color(0xFFFFFFFF),
        ),
      ]),
    ];
  }

  void _rebuild(VoidCallback change) {
    setState(() {
      change();
      _layers = _buildLayers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Нагрузка')),
      body: AtlasLoader(
        builder: (context, atlas) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final count in _counts)
                    ChoiceChip(
                      label: Text('$count'),
                      selected: _count == count,
                      onSelected: (_) => _rebuild(() => _count = count),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              dense: true,
              title: const Text('Анимация'),
              value: _animated,
              onChanged: (value) => _rebuild(() => _animated = value),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed:
                      _scale > 1 ? () => setState(() => _scale--) : null,
                ),
                Text('Масштаб x$_scale'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed:
                      _scale < 6 ? () => setState(() => _scale++) : null,
                ),
                const SizedBox(width: 16),
                Text('FPS: $_fps'),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: PixelCanvas(
                  scale: _scale,
                  background: const Color(0xFF202030),
                  atlas: atlas,
                  layers: _layers,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
