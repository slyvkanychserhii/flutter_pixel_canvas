import 'package:flutter/material.dart';
import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';

import 'atlas_loader.dart';

/// Демонстрация 12: нажатия по пикселям.
///
/// Сердце, смайлик и красный квадрат лежат так, что их прямоугольники
/// перекрываются, а сам смайлик ещё и мигает (у кадров моргания другая
/// форма). Переключатель выбирает, что считать попаданием:
///
/// * «По пикселям» (PixelHitArea.pixels): нажатие на прозрачный угол
///   кадра пролетает насквозь к тому, что лежит ниже. У мигающего смайлика
///   проверяется кадр, который виден в момент нажатия.
/// * «По прямоугольнику» (PixelHitArea.bounds): попадание в любую точку
///   прямоугольника кадра, даже прозрачную.
///
/// Тексту по умолчанию достаётся прямоугольник (в тонкие буквы пальцем
/// трудно попасть): отдельный переключатель включает проверку по пикселям
/// букв, тогда просветы между буквами не нажимаются.
///
/// Нажатый объект обводится красной рамкой, а пиксель нажатия помечается
/// точкой.
class PixelHitDemo extends StatefulWidget {
  const PixelHitDemo({super.key});

  @override
  State<PixelHitDemo> createState() => _PixelHitDemoState();
}

class _PixelHitDemoState extends State<PixelHitDemo> {
  static const _minScale = 2;
  static const _maxScale = 12;

  int _scale = 8;
  bool _spritePixels = true;
  bool _textPixels = false;
  PixelTap? _tap;

  void _changeScale(int delta) {
    setState(() => _scale = (_scale + delta).clamp(_minScale, _maxScale));
  }

  String _describe(PixelTap? tap) {
    if (tap == null) return 'Нажмите на холст';
    final hit = tap.hit;
    final what = hit == null ? 'пусто' : (hit.id ?? 'без id');
    return 'Пиксель сцены (${tap.x}, ${tap.y}): $what';
  }

  // Рамка вокруг нажатого объекта и точка на пикселе нажатия. Рисуется
  // поверх слоёв и нажатиями не определяется.
  void _paintSelection(Canvas canvas) {
    final tap = _tap;
    if (tap == null) return;

    final paint = Paint()
      ..color = Colors.redAccent
      ..isAntiAlias = false;

    canvas.drawRect(
      Rect.fromLTWH(tap.x.toDouble(), tap.y.toDouble(), 1, 1),
      paint,
    );

    final bounds = tap.hit?.bounds;
    if (bounds == null) return;
    final r = bounds.inflate(1);
    // Четыре полоски толщиной в один пиксель.
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 1), paint);
    canvas.drawRect(Rect.fromLTWH(r.left, r.bottom - 1, r.width, 1), paint);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top + 1, 1, r.height - 2), paint);
    canvas.drawRect(
        Rect.fromLTWH(r.right - 1, r.top + 1, 1, r.height - 2), paint);
  }

  @override
  Widget build(BuildContext context) {
    final spriteArea =
        _spritePixels ? PixelHitArea.pixels : PixelHitArea.bounds;
    final textArea = _textPixels ? PixelHitArea.pixels : PixelHitArea.bounds;

    return Scaffold(
      appBar: AppBar(title: const Text('Нажатия по пикселям')),
      body: AtlasLoader(
        builder: (context, atlas) => Column(
          children: [
            SwitchListTile(
              dense: true,
              title: Text(_spritePixels
                  ? 'Спрайты: по пикселям'
                  : 'Спрайты: по прямоугольнику'),
              value: _spritePixels,
              onChanged: (value) => setState(() => _spritePixels = value),
            ),
            SwitchListTile(
              dense: true,
              title: Text(
                  _textPixels ? 'Текст: по пикселям' : 'Текст: по прямоугольнику'),
              value: _textPixels,
              onChanged: (value) => setState(() => _textPixels = value),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _scale > _minScale ? () => _changeScale(-1) : null,
                ),
                Text('Масштаб x$_scale'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _scale < _maxScale ? () => _changeScale(1) : null,
                ),
              ],
            ),
            Text(_describe(_tap)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: PixelCanvas(
                  scale: _scale,
                  background: const Color(0xFF202030),
                  atlas: atlas,
                  onTap: (tap) => setState(() => _tap = tap),
                  onPaint: (canvas, size) => _paintSelection(canvas),
                  layers: [
                    PixelLayer(
                      id: 'main',
                      items: [
                        // Нижний объект: красный квадрат. Остальные
                        // накладываются на него.
                        PixelSprite(
                          id: 'red',
                          frame: 'red',
                          x: 4,
                          y: 4,
                          hitArea: spriteArea,
                        ),
                        // Сердце лежит поверх квадрата: его прозрачные углы
                        // нажатие пропускает на квадрат.
                        PixelSprite(
                          id: 'heart',
                          frame: 'heart',
                          x: 10,
                          y: 8,
                          hitArea: spriteArea,
                        ),
                        // Мигающий смайлик: форма кадров разная.
                        PixelSprite(
                          id: 'smiley',
                          frame: 'smiley',
                          x: 18,
                          y: 6,
                          animation: 'blink',
                          hitArea: spriteArea,
                        ),
                        PixelText(
                          id: 'text',
                          text: 'Текст',
                          font: 'main',
                          x: 4,
                          y: 28,
                          hitArea: textArea,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
