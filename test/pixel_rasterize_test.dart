import 'package:flutter/painting.dart';
import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';
import 'package:flutter_pixel_canvas/src/pixel_rasterize.dart';
import 'package:flutter_test/flutter_test.dart';

// Множество закрашенных пикселей (x, y) по списку прямоугольников.
Set<(int, int)> pixelsOf(PixelPrimitive primitive) {
  final result = <(int, int)>{};
  for (final rect in rasterize(primitive)) {
    for (var y = rect.top.toInt(); y < rect.bottom.toInt(); y++) {
      for (var x = rect.left.toInt(); x < rect.right.toInt(); x++) {
        result.add((x, y));
      }
    }
  }
  return result;
}

const _c = Color(0xFFFFFFFF);

void main() {
  test('точка это один пиксель', () {
    expect(pixelsOf(const PixelPoint(x: 3, y: 4, color: _c)), {(3, 4)});
  });

  group('линия', () {
    test('горизонтальная включает оба конца', () {
      final pixels =
          pixelsOf(const PixelLine(x0: 1, y0: 2, x1: 5, y1: 2, color: _c));
      expect(pixels, {(1, 2), (2, 2), (3, 2), (4, 2), (5, 2)});
    });

    test('диагональная без разрывов', () {
      final pixels =
          pixelsOf(const PixelLine(x0: 0, y0: 0, x1: 3, y1: 3, color: _c));
      expect(pixels, {(0, 0), (1, 1), (2, 2), (3, 3)});
    });

    test('одинакова в обе стороны', () {
      final forward =
          pixelsOf(const PixelLine(x0: 0, y0: 0, x1: 9, y1: 4, color: _c));
      final back =
          pixelsOf(const PixelLine(x0: 9, y0: 4, x1: 0, y1: 0, color: _c));
      expect(forward, back);
      // Ровно по одному пикселю на каждый столбец длинной оси.
      expect(forward.length, 10);
    });
  });

  group('прямоугольник', () {
    test('заливка', () {
      final pixels = pixelsOf(
          const PixelRect(x: 2, y: 3, width: 4, height: 2, color: _c));
      expect(pixels.length, 8);
      expect(pixels, contains((2, 3)));
      expect(pixels, contains((5, 4)));
    });

    test('контур не закрашивает середину', () {
      final pixels = pixelsOf(const PixelRect(
          x: 0, y: 0, width: 5, height: 5, filled: false, color: _c));
      expect(pixels.length, 16);
      expect(pixels, isNot(contains((2, 2))));
      expect(pixels, contains((0, 0)));
      expect(pixels, contains((4, 4)));
    });

    test('тонкий контур совпадает с заливкой', () {
      final outline = pixelsOf(const PixelRect(
          x: 0, y: 0, width: 2, height: 6, filled: false, color: _c));
      expect(outline.length, 12);
    });

    test('пустой размер даёт пустой результат', () {
      expect(
          pixelsOf(const PixelRect(x: 0, y: 0, width: 0, height: 5, color: _c)),
          isEmpty);
    });
  });

  group('окружность', () {
    test('радиус 0 это точка', () {
      expect(pixelsOf(const PixelCircle(cx: 5, cy: 5, radius: 0, color: _c)),
          {(5, 5)});
    });

    test('контур симметричен и проходит через крайние точки', () {
      final pixels = pixelsOf(const PixelCircle(
          cx: 10, cy: 10, radius: 4, filled: false, color: _c));
      for (final p in [(14, 10), (6, 10), (10, 14), (10, 6)]) {
        expect(pixels, contains(p));
      }
      expect(pixels, isNot(contains((10, 10))));
      for (final (x, y) in pixels) {
        expect(pixels, contains((20 - x, y)), reason: 'зеркало по x');
        expect(pixels, contains((x, 20 - y)), reason: 'зеркало по y');
      }
    });

    test('круг закрашен целиком', () {
      final pixels = pixelsOf(
          const PixelCircle(cx: 10, cy: 10, radius: 4, color: _c));
      expect(pixels, contains((10, 10)));
      expect(pixels, contains((14, 10)));
      expect(pixels, isNot(contains((15, 10))));
    });
  });
}
