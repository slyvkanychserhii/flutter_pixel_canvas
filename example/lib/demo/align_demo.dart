import 'package:flutter/material.dart';
import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';

import 'atlas_loader.dart';

/// Демонстрация 10: выравнивание и привязка.
///
/// Смайлик ("target") крепится к одной из девяти точек холста: выбираете
/// точку кнопками. Подпись и строка с числами не знают, где стоит смайлик:
/// подпись привязана к смайлику, а строка к подписи (цепочка из трёх).
/// Поэтому они едут за смайликом сами. Когда смайлик у нижнего края,
/// подпись и строка встают НАД ним (демо решает это одним условием,
/// координаты нигде не считаются).
class AlignDemo extends StatefulWidget {
  const AlignDemo({super.key});

  @override
  State<AlignDemo> createState() => _AlignDemoState();
}

class _AlignDemoState extends State<AlignDemo> {
  static const _minScale = 1;
  static const _maxScale = 12;

  // Девять точек: подпись кнопки и выравнивание. Порядок: строки сверху вниз.
  static const _points = <(String, Alignment)>[
    ('↖', Alignment.topLeft),
    ('↑', Alignment.topCenter),
    ('↗', Alignment.topRight),
    ('←', Alignment.centerLeft),
    ('•', Alignment.center),
    ('→', Alignment.centerRight),
    ('↙', Alignment.bottomLeft),
    ('↓', Alignment.bottomCenter),
    ('↘', Alignment.bottomRight),
  ];

  int _scale = 4;
  Alignment _align = Alignment.center;

  void _changeScale(int delta) {
    setState(() {
      _scale = (_scale + delta).clamp(_minScale, _maxScale);
    });
  }

  // Одна строка из трёх кнопок сетки 3 x 3.
  Widget _row(int row) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (label, align) in _points.skip(row * 3).take(3))
          Padding(
            padding: const EdgeInsets.all(2),
            child: ChoiceChip(
              label: Text(label),
              selected: _align == align,
              onSelected: (_) => setState(() => _align = align),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Смайлик у нижнего края: подписи уходят наверх, иначе они вылезли бы
    // за холст.
    final below = _align.y <= 0;
    // Точка на подписи и точка на смайлике, которые совмещаются:
    // для "под" это верх подписи и низ смайлика, для "над" наоборот.
    final side = below ? Alignment.bottomCenter : Alignment.topCenter;
    final labelSide = below ? Alignment.topCenter : Alignment.bottomCenter;
    final gap = below ? 2 : -2;

    return Scaffold(
      appBar: AppBar(title: const Text('Выравнивание')),
      body: AtlasLoader(
        builder: (context, atlas) => Column(
          children: [
            const SizedBox(height: 8),
            _row(0),
            _row(1),
            _row(2),
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: PixelCanvas(
                  scale: _scale,
                  background: const Color(0xFF202030),
                  atlas: atlas,
                  layers: [
                    PixelLayer(
                      id: 'ui',
                      items: [
                        // Смайлик вписан в точку холста: align без anchorAlign
                        // значит "эта точка смайлика совпадает с такой же
                        // точкой холста". Отступ в 2 пикселя внутрь не
                        // нужен: края видны и так.
                        PixelSprite(
                          id: 'target',
                          frame: 'smiley',
                          align: _align,
                        ),
                        // Подпись крепится к смайлику (anchor), а не к холсту.
                        PixelText(
                          id: 'label',
                          text: 'Смайлик',
                          font: 'main',
                          anchor: 'target',
                          anchorAlign: side,
                          align: labelSide,
                          y: gap,
                        ),
                        // А эта строка крепится к подписи: цепочка из трёх.
                        PixelText(
                          id: 'info',
                          text: '(${_align.x.toInt()}, ${_align.y.toInt()})',
                          font: 'main',
                          color: const Color(0xFFFFEB3B),
                          anchor: 'label',
                          anchorAlign: side,
                          align: labelSide,
                          y: gap,
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
