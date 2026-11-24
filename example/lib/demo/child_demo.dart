import 'package:flutter/material.dart';
import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';

import 'atlas_loader.dart';

/// Демонстрация 9: холст с дочерним виджетом.
///
/// У холста есть `child`: обычные виджеты (колонка из кнопки и списка), а пиксельная
/// графика рисуется поверх них. Часть кнопки закрыта сердечками. Сверху,
/// вне холста, панель настроек: режим нажатий, масштаб и счётчики.
///
/// Режимы нажатий:
///
/// * «Графика» (graphicsOnly): холст ловит нажатия на свою графику, всё
///   остальное достаётся дочерним виджетам. Кнопка не нажимается там, где её
///   закрывает графика.
/// * «Насквозь» (transparent): холст ничего не блокирует. Кнопка нажимается
///   даже под сердечками (при нажатии надпись «Кнопка нажата» вспыхивает
///   зелёным), а холст при этом всё равно сообщает о нажатиях.
/// * «Перехват» (capture): холст ловит все нажатия, дочерние виджеты замирают.
///   Выход: нажать на сердце.
///
/// Графика расставлена в пикселях сцены относительно кнопки, поэтому при
/// смене масштаба растёт вместе и не налезает друг на друга.
class ChildDemo extends StatefulWidget {
  const ChildDemo({super.key});

  @override
  State<ChildDemo> createState() => _ChildDemoState();
}

class _ChildDemoState extends State<ChildDemo> {
  static const int _minScale = 1;
  static const int _maxScale = 6;

  // Положение и размер кнопки внутри холста в логических пикселях. Дочерний
  // виджет занимает весь холст, поэтому это же координаты относительно
  // левого верхнего угла холста.
  static const double _buttonLeft = 24;
  static const double _buttonTop = 16;
  static const double _buttonWidth = 180;
  static const double _buttonHeight = 56;

  PixelTouchMode _mode = PixelTouchMode.graphicsOnly;
  int _scale = 4;

  int _buttonPresses = 0; // нажатия на обычную кнопку
  bool _buttonFlash = false; // подсветка счётчика сразу после нажатия
  int _smileyTaps = 0; // нажатия на смайлик
  int _canvasTaps = 0; // нажатия на холст мимо графики

  // Нажатие на кнопку: увеличиваем счётчик и на мгновение подсвечиваем
  // надпись, чтобы было видно, что кнопка сработала (даже под графикой).
  void _pressButton() {
    setState(() {
      _buttonPresses++;
      _buttonFlash = true;
    });
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _buttonFlash = false);
    });
  }

  void _onCanvasTap(PixelTap tap) {
    setState(() {
      switch (tap.hit?.id) {
        case 'smiley':
          _smileyTaps++;
        case 'heart':
          // Выход из режима перехвата. В других режимах сердце как все.
          if (_mode == PixelTouchMode.capture) {
            _mode = PixelTouchMode.graphicsOnly;
          }
        case 'cover1' || 'cover2':
          break; // сердечки над кнопкой: только мешают, своего дела нет
        case _:
          // Нажатия мимо графики. В режиме graphicsOnly сюда не попадают.
          _canvasTaps++;
      }
    });
  }

  String get _modeHint => switch (_mode) {
        PixelTouchMode.capture =>
          'Холст ловит все нажатия. Выход: нажмите на сердце внизу.',
        PixelTouchMode.graphicsOnly =>
          'Кнопка не нажимается там, где её закрывает графика.',
        PixelTouchMode.transparent =>
          'Кнопка нажимается даже под графикой.',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Холст с дочерним виджетом')),
      body: AtlasLoader(
        builder: (context, atlas) => Column(
          children: [
            // Панель настроек: обычные виджеты вне холста.
            _buildPanel(),
            const Divider(height: 1),
            // Холст на всё оставшееся место. child внутри, графика поверх.
            Expanded(
              child: PixelCanvas(
                scale: _scale,
                atlas: atlas,
                touchMode: _mode,
                onTap: _onCanvasTap,
                // Прозрачный фон: виден цвет экрана под дочерним виджетом.
                background: const Color(0x00000000),
                layers: _buildLayers(),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Графика поверх дочернего виджета. Всё в пикселях сцены; в экранных
  // пикселях заданы только положение и размер кнопки.
  List<PixelLayer> _buildLayers() {
    // Переводит логические пиксели в пиксели сцены.
    int toScene(double logical) => (logical / _scale).round();

    // Левый край кнопки в пикселях сцены; от него считаем всю графику.
    final x0 = toScene(_buttonLeft);

    // Сердечки над кнопкой: по центру кнопки по высоте, рядом друг с другом
    // (зазор 3 пикселя сцены).
    final coverX = toScene(_buttonLeft + 10);
    final coverY = toScene(_buttonTop + (_buttonHeight - 8 * _scale) / 2);

    // Верх графики под кнопкой.
    final graphicsY = toScene(_buttonTop + _buttonHeight + 8);

    return [
      PixelLayer(
        id: 'hud',
        items: [
          PixelSprite(id: 'cover1', frame: 'heart', x: coverX, y: coverY),
          PixelSprite(
            id: 'cover2',
            frame: 'heart',
            x: coverX + 9 + 3,
            y: coverY,
          ),
          // Смайлик и сердце под кнопкой, в одной строке.
          PixelSprite(
            id: 'smiley',
            frame: 'smiley',
            x: x0,
            y: graphicsY + 16,
            animation: 'blink',
          ),
          PixelSprite(
            id: 'heart',
            frame: 'heart',
            x: x0 + 12 + 4,
            y: graphicsY + 17,
          ),
          PixelText(
            text: 'Смайл: $_smileyTaps',
            font: 'main',
            x: x0,
            y: graphicsY,
            color: Colors.yellow,
          ),
        ],
      ),
    ];
  }

  // Дочерний виджет холста: обычный интерфейс. Он ничего не знает о графике.
  //
  // Обычная колонка: кнопка, а за ней список, который занимает всё
  // оставшееся место. Размер и отступы кнопки заданы константами, поэтому
  // графика знает, где кнопка (при её собственном размере положение
  // зависело бы от надписи и шрифта).
  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Слева и сверху отступы _buttonLeft и _buttonTop, снизу 8
          // (графика под кнопкой отсчитывается от этой точки).
          padding: const EdgeInsets.fromLTRB(_buttonLeft, _buttonTop, 0, 8),
          child: SizedBox(
            width: _buttonWidth,
            height: _buttonHeight,
            child: FilledButton(
              onPressed: _pressButton,
              child: Text('Кнопка: $_buttonPresses'),
            ),
          ),
        ),
        // Список занимает остальное место; графика лежит поверх него,
        // а он листается.
        Expanded(
          child: ListView.builder(
            itemCount: 30,
            itemBuilder: (context, index) => ListTile(
              dense: true,
              title: Text('Строка списка ${index + 1}'),
            ),
          ),
        ),
      ],
    );
  }

  // Панель настроек: режим, масштаб, счётчики.
  Widget _buildPanel() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedButton<PixelTouchMode>(
            segments: const [
              ButtonSegment(
                value: PixelTouchMode.capture,
                label: Text('Перехват'),
              ),
              ButtonSegment(
                value: PixelTouchMode.graphicsOnly,
                label: Text('Графика'),
              ),
              ButtonSegment(
                value: PixelTouchMode.transparent,
                label: Text('Насквозь'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) =>
                setState(() => _mode = selection.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: SizedBox(
            width: double.infinity,
            height: 40,
            child: Text(_modeHint),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed:
                  _scale > _minScale ? () => setState(() => _scale--) : null,
            ),
            Text('Масштаб x$_scale'),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed:
                  _scale < _maxScale ? () => setState(() => _scale++) : null,
            ),
          ],
        ),
        Text('Нажатий на холст мимо графики: $_canvasTaps'),
        const SizedBox(height: 4),
        // Счётчик кнопки: на мгновение вспыхивает зелёным при каждом нажатии.
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          color: _buttonFlash ? Colors.greenAccent : Colors.transparent,
          child: Text('Кнопка нажата: $_buttonPresses'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
