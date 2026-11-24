import 'package:flutter/material.dart';
import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';

/// Демонстрация 2: примитивы.
///
/// Переключатель меняет прямоугольники и окружности между заливкой
/// и контуром. Масштаб фиксирован (8), чтобы отдельные пиксели
/// были хорошо видны.
class PrimitivesDemo extends StatefulWidget {
  const PrimitivesDemo({super.key});

  @override
  State<PrimitivesDemo> createState() => _PrimitivesDemoState();
}

class _PrimitivesDemoState extends State<PrimitivesDemo> {
  bool _filled = true;

  // Список примитивов собираем в отдельном методе: так проще читать build.
  // Координаты в пикселях сцены; все фигуры помещаются в область 40 x 56.
  List<PixelPrimitive> _buildPrimitives() {
    return [
      // Три отдельных пикселя.
      const PixelPoint(x: 2, y: 2, color: Colors.red),
      const PixelPoint(x: 4, y: 2, color: Colors.green),
      const PixelPoint(x: 6, y: 2, color: Colors.blue),

      // Линии: наклонная, горизонтальная и вертикальная.
      const PixelLine(x0: 2, y0: 6, x1: 36, y1: 18, color: Colors.yellow),
      const PixelLine(x0: 2, y0: 20, x1: 36, y1: 20, color: Colors.white),
      const PixelLine(x0: 38, y0: 2, x1: 38, y1: 20, color: Colors.cyan),

      // Прямоугольник и окружность, которые перекрываются. Окружность
      // добавлена позже, поэтому рисуется поверх. Она полупрозрачная:
      // сквозь неё виден прямоугольник.
      PixelRect(
        x: 4,
        y: 26,
        width: 20,
        height: 14,
        color: Colors.orange,
        filled: _filled,
      ),
      PixelCircle(
        cx: 24,
        cy: 36,
        radius: 9,
        color: const Color(0xAA40A0FF),
        filled: _filled,
      ),

      // Совсем маленькие фигуры: проверка граничных случаев.
      const PixelRect(x: 4, y: 48, width: 2, height: 2, color: Colors.pink),
      PixelCircle(cx: 12, cy: 49, radius: 1, color: Colors.lime, filled: _filled),
      const PixelCircle(cx: 18, cy: 49, radius: 0, color: Colors.white),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Примитивы')),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Заливка'),
            value: _filled,
            onChanged: (value) => setState(() => _filled = value),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PixelCanvas(
                scale: 8,
                background: const Color(0xFF202030),
                layers: [PixelLayer(id: 'shapes', items: _buildPrimitives())],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
