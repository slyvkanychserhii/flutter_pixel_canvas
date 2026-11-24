import 'package:flutter/material.dart';
import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';

import 'atlas_loader.dart';
import 'demo_layers.dart';

/// Демонстрация 6: нажатия на графику и на слой.
///
/// Нажмите на любую фигуру: под холстом появится пиксель сцены, слой и
/// id найденного объекта, а сам объект обведётся. Если слой выключить чипом,
/// нажатия его больше не замечают и достаются нижним слоям.
class HitTestDemo extends StatefulWidget {
  const HitTestDemo({super.key});

  @override
  State<HitTestDemo> createState() => _HitTestDemoState();
}

class _HitTestDemoState extends State<HitTestDemo> {
  final Set<String> _hidden = {}; // id скрытых слоёв
  PixelTap? _tap; // последнее нажатие

  List<PixelLayer> _buildLayers() {
    return [
      for (final layer in demoLayers)
        layer.copyWith(visible: !_hidden.contains(layer.id)),
    ];
  }

  void _toggle(String id, bool visible) {
    setState(() {
      if (visible) {
        _hidden.remove(id);
      } else {
        _hidden.add(id);
      }
      // Выбранное раньше могло исчезнуть вместе со слоем.
      _tap = null;
    });
  }

  // Текст о последнем нажатии.
  String _describe(PixelTap? tap) {
    if (tap == null) return 'Нажмите на холст';
    final where = 'Пиксель сцены: (${tap.x}, ${tap.y})';
    final hit = tap.hit;
    if (hit == null) return '$where\nПусто';
    final kind = hit.sprite != null
        ? 'спрайт'
        : hit.text != null
            ? 'текст'
            : 'примитив';
    return '$where\nСлой: ${hit.layerId}\nОбъект: ${hit.id ?? "без id"} ($kind)';
  }

  // Рисуем поверх всех слоёв (холст вызывает это последним). То, что
  // нарисовано здесь, нажатиями не определяется, поэтому подходит для
  // подсветки выбранного.
  void _paintSelection(Canvas canvas) {
    final tap = _tap;
    if (tap == null) return;

    final paint = Paint()
      ..color = Colors.redAccent
      ..isAntiAlias = false;

    // Метка на пикселе нажатия.
    canvas.drawRect(
      Rect.fromLTWH(tap.x.toDouble(), tap.y.toDouble(), 1, 1),
      paint,
    );

    // Рамка вокруг спрайта или текста (у примитивов рамки нет, только метка).
    // Положение берём у самой находки: так работает и выравнивание.
    final bounds = tap.hit?.bounds;
    if (bounds == null) return;

    final left = bounds.left - 1;
    final top = bounds.top - 1;
    final width = bounds.width + 2;
    final height = bounds.height + 2;
    // Четыре полоски толщиной в один пиксель.
    canvas.drawRect(Rect.fromLTWH(left, top, width, 1), paint);
    canvas.drawRect(Rect.fromLTWH(left, top + height - 1, width, 1), paint);
    canvas.drawRect(Rect.fromLTWH(left, top + 1, 1, height - 2), paint);
    canvas.drawRect(
        Rect.fromLTWH(left + width - 1, top + 1, 1, height - 2), paint);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Нажатия')),
      body: AtlasLoader(
        builder: (context, atlas) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final layer in demoLayers)
                    FilterChip(
                      label: Text('Слой ${layer.id}'),
                      selected: !_hidden.contains(layer.id),
                      onSelected: (selected) => _toggle(layer.id, selected),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: PixelCanvas(
                  scale: 8,
                  background: const Color(0xFF202030),
                  atlas: atlas,
                  layers: _buildLayers(),
                  onTap: (tap) => setState(() => _tap = tap),
                  onPaint: (canvas, size) => _paintSelection(canvas),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: Text(_describe(_tap)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
