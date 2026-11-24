import 'package:flutter/material.dart';
import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';

/// Три слоя для демонстраций: A (нижний), B и C (верхний).
/// В каждом есть спрайты, текст и примитивы, и фигуры соседних слоёв
/// перекрывают друг друга. Внутри слоя объекты рисуются по порядку списка.
const List<PixelLayer> demoLayers = [
  PixelLayer(
    id: 'A',
    items: [
      PixelSprite(id: 'red', frame: 'red', x: 6, y: 6),
      // Круг лежит выше красного спрайта: он идёт в списке позже.
      PixelCircle(
        id: 'circle',
        cx: 26,
        cy: 16,
        radius: 10,
        color: Colors.orange,
      ),
    ],
  ),
  PixelLayer(
    id: 'B',
    items: [
      PixelSprite(id: 'blue', frame: 'blue', x: 18, y: 10),
      PixelSprite(id: 'smiley', frame: 'smiley', x: 4, y: 24),
      // Полупрозрачный прямоугольник: сквозь него видны нижние слои.
      PixelRect(
        id: 'glass',
        x: 10,
        y: 4,
        width: 24,
        height: 12,
        color: Color(0x8840A0FF),
      ),
    ],
  ),
  PixelLayer(
    id: 'C',
    items: [
      PixelSprite(id: 'green', frame: 'green', x: 28, y: 18),
      // Текст шрифтом из атласа.
      PixelText(
        id: 'label',
        text: 'Привет',
        font: 'main',
        x: 2,
        y: 38,
        color: Colors.yellow,
      ),
      PixelLine(
        id: 'line',
        x0: 2,
        y0: 2,
        x1: 44,
        y1: 34,
        color: Colors.white,
      ),
    ],
  ),
];
