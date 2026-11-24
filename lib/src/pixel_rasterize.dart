import 'package:flutter/painting.dart';

import 'pixel_objects.dart';

/// Превращает примитив в список прямоугольников, из которых он состоит
/// (чаще всего это отдельные пиксели 1x1, а у закрашенных фигур длинные
/// полоски). Каждый прямоугольник лежит строго на сетке пикселей сцены.
///
/// Функция чистая: ничего не рисует и ничего не хранит.
List<Rect> rasterize(PixelPrimitive primitive) {
  // switch-выражение по sealed-классу: компилятор следит, чтобы
  // были перечислены все наследники.
  return switch (primitive) {
    PixelPoint(:final x, :final y) => [_pixel(x, y)],
    PixelLine(:final x0, :final y0, :final x1, :final y1) =>
      _line(x0, y0, x1, y1),
    PixelRect(:final x, :final y, :final width, :final height, :final filled) =>
      _rect(x, y, width, height, filled),
    PixelCircle(:final cx, :final cy, :final radius, :final filled) =>
      _circle(cx, cy, radius, filled),
  };
}

// Прямоугольник из одного пикселя.
Rect _pixel(int x, int y) =>
    Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1);

// Прямоугольник по целым координатам (вспомогательная функция).
Rect _box(int x, int y, int width, int height) => Rect.fromLTWH(
    x.toDouble(), y.toDouble(), width.toDouble(), height.toDouble());

/// Линия по алгоритму Брезенхэма: идём по длинной оси на один пиксель и
/// следим за накопленной ошибкой, чтобы вовремя шагнуть по короткой оси.
/// Работает только с целыми числами, поэтому линия получается без разрывов.
List<Rect> _line(int x0, int y0, int x1, int y1) {
  final result = <Rect>[];

  final dx = (x1 - x0).abs();
  final dy = -(y1 - y0).abs();
  final sx = x0 < x1 ? 1 : -1; // направление по x
  final sy = y0 < y1 ? 1 : -1; // направление по y
  var err = dx + dy;
  var x = x0;
  var y = y0;

  while (true) {
    result.add(_pixel(x, y));
    if (x == x1 && y == y1) break;

    final e2 = 2 * err;
    if (e2 >= dy) {
      err += dy;
      x += sx;
    }
    if (e2 <= dx) {
      err += dx;
      y += sy;
    }
  }
  return result;
}

/// Прямоугольник. Контур собирается из четырёх полосок толщиной в пиксель.
List<Rect> _rect(int x, int y, int width, int height, bool filled) {
  if (width <= 0 || height <= 0) return const [];

  // Если фигура так тонка, что внутри контура ничего не остаётся,
  // контур и заливка совпадают.
  if (filled || width <= 2 || height <= 2) {
    return [_box(x, y, width, height)];
  }
  return [
    _box(x, y, width, 1), // верх
    _box(x, y + height - 1, width, 1), // низ
    _box(x, y + 1, 1, height - 2), // лево (без углов, они уже в верху и низу)
    _box(x + width - 1, y + 1, 1, height - 2), // право
  ];
}

/// Окружность по алгоритму средней точки: считаем только одну восьмую
/// окружности, остальные семь получаем симметрией.
List<Rect> _circle(int cx, int cy, int radius, bool filled) {
  if (radius < 0) return const [];
  if (radius == 0) return [_pixel(cx, cy)];

  final result = <Rect>[];
  var x = radius;
  var y = 0;
  var err = 1 - radius;

  while (x >= y) {
    if (filled) {
      // Горизонтальные полоски: строки cy±y шириной по x в обе стороны
      // от центра и строки cy±x шириной по y.
      result.add(_box(cx - x, cy + y, 2 * x + 1, 1));
      result.add(_box(cx - x, cy - y, 2 * x + 1, 1));
      result.add(_box(cx - y, cy + x, 2 * y + 1, 1));
      result.add(_box(cx - y, cy - x, 2 * y + 1, 1));
    } else {
      // Восемь симметричных пикселей контура.
      result.add(_pixel(cx + x, cy + y));
      result.add(_pixel(cx - x, cy + y));
      result.add(_pixel(cx + x, cy - y));
      result.add(_pixel(cx - x, cy - y));
      result.add(_pixel(cx + y, cy + x));
      result.add(_pixel(cx - y, cy + x));
      result.add(_pixel(cx + y, cy - x));
      result.add(_pixel(cx - y, cy - x));
    }

    // Переходим к следующей точке дуги.
    y++;
    if (err < 0) {
      err += 2 * y + 1;
    } else {
      x--;
      err += 2 * (y - x) + 1;
    }
  }
  return result;
}
