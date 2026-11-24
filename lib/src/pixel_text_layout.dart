import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'pixel_atlas.dart';
import 'pixel_markup.dart';
import 'pixel_objects.dart';

/// Один символ после раскладки: какой кадр атласа и куда его поставить.
class PixelGlyph {
  const PixelGlyph({required this.source, required this.position, this.color});

  /// Прямоугольник глифа в картинке атласа.
  final Rect source;

  /// Левый верхний угол глифа ВНУТРИ ТЕКСТА (от левого верхнего угла текста).
  final Offset position;

  /// Цвет из тега разметки; null значит цвет всего текста.
  final Color? color;
}

/// Результат раскладки текста.
class PixelTextLayout {
  const PixelTextLayout({required this.glyphs, required this.size});

  /// Глифы по порядку (пробелы тоже: это прозрачные кадры).
  final List<PixelGlyph> glyphs;

  /// Размер текста в пикселях: самая длинная строка и все строки по высоте.
  final Size size;
}

/// Раскладывает [text] на глифы шрифта из [atlas]. Возвращает null, если
/// шрифта в атласе нет.
///
/// Алгоритм: идём по символам слева направо. Каждый глиф ставим в текущую
/// точку (x, y) и сдвигаем x на его ширину плюс зазор шрифта. Символ '\n'
/// возвращает x в начало и опускает y на высоту строки.
///
/// Функция чистая: ничего не рисует и не хранит.
PixelTextLayout? layoutText(PixelText text, PixelAtlas atlas) {
  final font = atlas.font(text.font);
  if (font == null) return null;

  // С разметкой убираем теги и запоминаем цвет каждого символа.
  final markup = text.markup ? parsePixelMarkup(text.text) : null;
  final source = markup?.text ?? text.text;

  final glyphs = <PixelGlyph>[];
  var index = -1; // номер символа в чистом тексте
  var x = 0.0; // текущая позиция по горизонтали внутри текста
  var y = 0.0; // верх текущей строки
  var width = 0.0; // ширина самой длинной из законченных строк

  for (final rune in source.runes) {
    index++;
    // Перенос строки: запоминаем ширину законченной строки.
    if (rune == 0x0A) {
      width = math.max(width, _lineWidth(x, font.spacing));
      x = 0;
      y += font.lineHeight;
      continue;
    }

    // Кадр глифа; если символа нет в шрифте, пробуем '?' (код 0x3F).
    final frameName = font.glyphs[rune] ?? font.glyphs[0x3F];
    if (frameName == null) continue;

    // Кадр точно есть: PixelAtlas.load это проверил при загрузке.
    final frame = atlas.frame(frameName)!;
    glyphs.add(PixelGlyph(
      source: frame,
      position: Offset(x, y),
      color: markup?.colors[index],
    ));
    x += frame.width + font.spacing;
  }

  // Последняя строка (на ней нет '\n', поэтому учитываем отдельно).
  width = math.max(width, _lineWidth(x, font.spacing));

  return PixelTextLayout(
    glyphs: glyphs,
    size: Size(width, y + font.lineHeight),
  );
}

// После последнего глифа строки x уже включает зазор: вычитаем его.
double _lineWidth(double x, int spacing) => x > 0 ? x - spacing : 0;
