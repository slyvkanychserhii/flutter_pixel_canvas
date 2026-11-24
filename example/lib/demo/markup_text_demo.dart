import 'package:flutter/material.dart';
import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';

import 'atlas_loader.dart';

/// Демонстрация 24: текст разными цветами в одной строке.
///
/// Включается параметром `markup: true` у PixelText. Цвет задаёт тег
/// `<color=#RRGGBB>…</color>`: можно писать #RGB, #RRGGBB, #AARRGGBB или
/// имя (red, green, blue, yellow, orange, white, black, gray). Теги
/// вкладываются, а `<<` даёт обычный символ `<`. В поле ниже можно
/// набрать свой текст с тегами и сразу увидеть результат. Переключатель
/// «Обрабатывать теги» ставит markup в false: тогда теги не разбираются
/// и выводятся как обычный текст.
class MarkupTextDemo extends StatefulWidget {
  const MarkupTextDemo({super.key});

  @override
  State<MarkupTextDemo> createState() => _MarkupTextDemoState();
}

class _MarkupTextDemoState extends State<MarkupTextDemo> {
  static const _minScale = 1;
  static const _maxScale = 8;

  final TextEditingController _controller = TextEditingController(
    text: 'Урон: <color=red>-25</color>, лечение: <color=#4CAF50>+10</color>',
  );
  int _scale = 2;
  bool _markup = true; // обрабатывать ли теги цвета (параметр markup)

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Цветной текст')),
      body: AtlasLoader(
        builder: (context, atlas) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _controller,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Текст с тегами'),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _scale > _minScale ? () => setState(() => _scale--) : null,
                ),
                Text('Масштаб x$_scale'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _scale < _maxScale ? () => setState(() => _scale++) : null,
                ),
              ],
            ),
            SwitchListTile(
              dense: true,
              title: const Text('Обрабатывать теги (markup)'),
              value: _markup,
              onChanged: (v) => setState(() => _markup = v),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: PixelCanvas(
                  scale: _scale,
                  background: const Color(0xFF202030),
                  atlas: atlas,
                  layers: [
                    PixelLayer(id: 'texts', items: [
                      // Введённый текст; цвет по умолчанию белый.
                      PixelText(
                        text: _controller.text,
                        font: 'main',
                        markup: _markup,
                        x: 2,
                        y: 2,
                      ),
                      // Несколько цветов в одной строке.
                      PixelText(
                        text: '<color=red>К</color><color=orange>р</color>'
                            '<color=yellow>а</color><color=green>с</color>'
                            '<color=blue>к</color><color=#A0F>и</color>',
                        font: 'main',
                        markup: _markup,
                        x: 2,
                        y: 18,
                      ),
                      // Вложенные теги: после «синего» снова зелёный.
                      PixelText(
                        text: '<color=green>зелёный <color=blue>синий</color> '
                            'снова зелёный</color>',
                        font: 'main',
                        markup: _markup,
                        x: 2,
                        y: 30,
                      ),
                      // Свой цвет текста: куски без тега берут его.
                      PixelText(
                        text: 'Золото: <color=white>100</color> монет',
                        font: 'main',
                        markup: _markup,
                        color: const Color(0xFFFFC107),
                        x: 2,
                        y: 42,
                      ),
                      // Знак < пишется двойным.
                      PixelText(
                        text: '1 << 2 и <color=#80FF0000>полупрозрачный</color>',
                        font: 'main',
                        markup: _markup,
                        x: 2,
                        y: 54,
                      ),
                    ]),
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
