import 'package:flutter/material.dart';
import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';

import 'atlas_loader.dart';

/// Демонстрация 13: свойства спрайта.
///
/// Флажок (несимметричный, поэтому видно и поворот, и отражение) и
/// мигающий смайлик получают одни и те же настройки: поворот на
/// четверти оборота, отражение по осям, целое увеличение (zoom),
/// непрозрачность и подкраска. Серая полоса под спрайтами нужна, чтобы
/// была видна прозрачность. Нажатие на спрайт обводит его рамкой: она
/// показывает размер после поворота и увеличения, а нажатия по пикселям
/// учитывают все преобразования (нажмите в пустой угол «F»: нажатие
/// пролетит насквозь). Любая смена настройки сбрасывает рамку: она
/// описывала спрайт в прежнем виде.
class SpritePropsDemo extends StatefulWidget {
  const SpritePropsDemo({super.key});

  @override
  State<SpritePropsDemo> createState() => _SpritePropsDemoState();
}

class _SpritePropsDemoState extends State<SpritePropsDemo> {
  static const _tints = <(String, Color)>[
    ('без', Color(0xFFFFFFFF)),
    ('красный', Color(0xFFFF5252)),
    ('зелёный', Color(0xFF69F0AE)),
    ('синий', Color(0xFF448AFF)),
  ];

  int _scale = 6;
  int _turns = 0;
  bool _flipX = false;
  bool _flipY = false;
  int _zoom = 1;
  double _opacity = 1;
  Color _tint = _tints.first.$2;
  PixelTap? _tap;

  // Любое изменение настроек: применяем и сбрасываем выбранное. Рамка
  // относилась к спрайту в прежнем виде и после изменения была бы неверной.
  void _update(VoidCallback change) {
    setState(() {
      change();
      _tap = null;
    });
  }

  // Рамка вокруг нажатого спрайта и точка на пикселе нажатия.
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
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 1), paint);
    canvas.drawRect(Rect.fromLTWH(r.left, r.bottom - 1, r.width, 1), paint);
    canvas.drawRect(Rect.fromLTWH(r.left, r.top + 1, 1, r.height - 2), paint);
    canvas.drawRect(
        Rect.fromLTWH(r.right - 1, r.top + 1, 1, r.height - 2), paint);
  }

  // Строка со степпером: подпись, минус, число, плюс.
  Widget _stepper(String label, int value, int min, int max, void Function(int) onChange) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: value > min ? () => _update(() => onChange(value - 1)) : null,
        ),
        SizedBox(width: 120, child: Text('$label $value', textAlign: TextAlign.center)),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: value < max ? () => _update(() => onChange(value + 1)) : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Свойства спрайта')),
      body: AtlasLoader(
        builder: (context, atlas) => Column(
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                _stepper('Масштаб x', _scale, 2, 10, (v) => _scale = v),
                _stepper('Поворот', _turns, 0, 3, (v) => _turns = v),
                _stepper('Zoom', _zoom, 1, 4, (v) => _zoom = v),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilterChip(
                  label: const Text('flipX'),
                  selected: _flipX,
                  onSelected: (v) => _update(() => _flipX = v),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('flipY'),
                  selected: _flipY,
                  onSelected: (v) => _update(() => _flipY = v),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final (name, color) in _tints)
                  ChoiceChip(
                    label: Text(name),
                    selected: _tint == color,
                    onSelected: (_) => _update(() => _tint = color),
                  ),
              ],
            ),
            // Ползунок непрозрачности с подписью и текущим значением.
            Row(
              children: [
                const SizedBox(width: 16),
                Text('Непрозрачность: ${_opacity.toStringAsFixed(1)}'),
                Expanded(
                  child: Slider(
                    value: _opacity,
                    divisions: 10,
                    label: _opacity.toStringAsFixed(1),
                    onChanged: (v) => _update(() => _opacity = v),
                  ),
                ),
              ],
            ),
            Text(_tap == null
                ? 'Нажмите на спрайт'
                : 'Нажато: ${_tap!.hit?.id ?? "пусто"}'),
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
                    const PixelLayer(
                      id: 'bg',
                      items: [
                        // Серая полоса: сквозь полупрозрачный спрайт видно её.
                        PixelRect(
                          x: 0,
                          y: 12,
                          width: 400,
                          height: 14,
                          color: Color(0xFF808080),
                        ),
                      ],
                    ),
                    PixelLayer(
                      id: 'sprites',
                      items: [
                        PixelSprite(
                          id: 'flag',
                          frame: 'flag',
                          x: 6,
                          y: 6,
                          quarterTurns: _turns,
                          flipX: _flipX,
                          flipY: _flipY,
                          zoom: _zoom,
                          opacity: _opacity,
                          tint: _tint,
                        ),
                        // Смайлик справа (align), с теми же настройками:
                        // анимация и преобразования работают вместе.
                        PixelSprite(
                          id: 'smiley',
                          frame: 'smiley',
                          animation: 'blink',
                          align: Alignment.topRight,
                          x: -6,
                          y: 6,
                          quarterTurns: _turns,
                          flipX: _flipX,
                          flipY: _flipY,
                          zoom: _zoom,
                          opacity: _opacity,
                          tint: _tint,
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
