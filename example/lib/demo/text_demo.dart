import 'package:flutter/material.dart';
import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';

import 'atlas_loader.dart';

/// Демонстрация 7: растровый текст из атласа.
///
/// Буквы это кадры атласа (шрифт "main" описан в JSON). В поле можно
/// набрать свой текст: русские и латинские буквы, цифры, знаки. Символ,
/// которого нет в шрифте (например ☃), заменяется на «?». Перенос строки
/// работает через \n (в поле используйте Enter).
class TextDemo extends StatefulWidget {
  const TextDemo({super.key});

  @override
  State<TextDemo> createState() => _TextDemoState();
}

class _TextDemoState extends State<TextDemo> {
  static const _minScale = 1;
  static const _maxScale = 12;

  final TextEditingController _controller =
      TextEditingController(text: 'Привет, мир!\nPixel text ☃');
  int _scale = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changeScale(int delta) {
    setState(() {
      _scale = (_scale + delta).clamp(_minScale, _maxScale);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Текст из атласа')),
      body: AtlasLoader(
        builder: (context, atlas) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _controller,
                // Каждое изменение в поле перерисовывает холст.
                onChanged: (_) => setState(() {}),
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Текст'),
              ),
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: PixelCanvas(
                  scale: _scale,
                  background: const Color(0xFF202030),
                  atlas: atlas,
                  layers: [
                    PixelLayer(
                      id: 'texts',
                      items: [
                        // Введённый текст.
                        PixelText(
                          text: _controller.text,
                          font: 'main',
                          x: 2,
                          y: 2,
                        ),
                        // Тот же шрифт разными цветами.
                        const PixelText(
                          text: 'Красный',
                          font: 'main',
                          x: 2,
                          y: 36,
                          color: Colors.redAccent,
                        ),
                        const PixelText(
                          text: 'Зелёный',
                          font: 'main',
                          x: 2,
                          y: 50,
                          color: Colors.greenAccent,
                        ),
                        // Полупрозрачный.
                        const PixelText(
                          text: 'Прозрачный',
                          font: 'main',
                          x: 2,
                          y: 64,
                          color: Color(0x80FFFFFF),
                        ),
                        // Шрифта "нет такого" в атласе нет: текст не рисуется.
                        const PixelText(
                          text: 'невидимка',
                          font: 'нет такого',
                          x: 2,
                          y: 78,
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
