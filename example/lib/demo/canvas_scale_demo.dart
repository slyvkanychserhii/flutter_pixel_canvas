import 'package:flutter/material.dart';
import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';

/// Демонстрация 1: холст занимает всё место родителя, и работает масштаб.
///
/// Вокруг холста оставлен отступ, чтобы было видно его границы. При
/// увеличении масштаба картинка растёт, а число пикселей сцены уменьшается:
/// размер сцены = размер холста / масштаб.
class CanvasScaleDemo extends StatefulWidget {
  const CanvasScaleDemo({super.key});

  @override
  State<CanvasScaleDemo> createState() => _CanvasScaleDemoState();
}

class _CanvasScaleDemoState extends State<CanvasScaleDemo> {
  static const _minScale = 1;
  static const _maxScale = 16;

  int _scale = 4;

  void _changeScale(int delta) {
    setState(() {
      _scale = (_scale + delta).clamp(_minScale, _maxScale);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Холст и масштаб')),
      body: Column(
        children: [
          // Панель управления: − масштаб +
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
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
          ),
          // Холст получает всё оставшееся место. LayoutBuilder нужен только
          // чтобы показать на экране размер сцены.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = (constraints.maxWidth / _scale).floor();
                  final h = (constraints.maxHeight / _scale).floor();
                  return Stack(
                    children: [
                      PixelCanvas(
                        scale: _scale,
                        background: const Color(0xFF202030),
                        onPaint: _paintScene,
                      ),
                      // Обычный виджет поверх холста: показывает размер сцены.
                      Positioned(
                        left: 6,
                        bottom: 4,
                        child: Text(
                          'Сцена: $w x $h',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Рисуем в координатах сцены: 1 единица = 1 пиксель сцены.
  void _paintScene(Canvas canvas, Size scene) {
    // Один Paint без сглаживания на все пиксели; меняем только цвет.
    final paint = Paint()..isAntiAlias = false;

    // Закрашивает один пиксель сцены с координатами (x, y).
    void pixel(int x, int y, Color color) {
      paint.color = color;
      canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
    }

    final w = scene.width.toInt();
    final h = scene.height.toInt();
    if (w < 2 || h < 2) return;

    // Диагональ из левого верхнего угла.
    final diagonal = w < h ? w : h;
    for (var i = 0; i < diagonal; i++) {
      pixel(i, i, Colors.greenAccent);
    }

    // Цветные пиксели рядом с углами: видно, что "пиксель" это квадрат.
    pixel(2, 2, Colors.red);
    pixel(w - 3, 2, Colors.yellow);
    pixel(2, h - 3, Colors.cyan);
    pixel(w - 3, h - 3, Colors.orange);
  }
}
