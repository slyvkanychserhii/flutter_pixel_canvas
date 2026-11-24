/// Пиксельный холст для Flutter: слои, атлас текстур, текст шрифтом из атласа,
/// анимация по кадрам атласа, нажатия на объекты и слои, примитивы.
///
/// Всё, что нужно приложению, импортируется одной строкой:
///
///     import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';
///
/// Здесь перечислено только публичное API. Внутренние детали (раскладка,
/// кэш сцены, растеризация) лежат рядом в lib/src и снаружи не нужны.
library;

// Атлас текстур: кадры, анимации, шрифты.
export 'src/pixel_atlas.dart' show PixelAtlas, PixelAnimation, PixelFont, hitAlphaThreshold;

// Холст и режимы нажатий.
export 'src/pixel_canvas.dart' show PixelCanvas, PixelTouchMode, PixelPaintCallback;

// Что нажали.
export 'src/pixel_hit_test.dart' show PixelHit, PixelTap;

// Слои и их перестановка.
export 'src/pixel_layer.dart' show PixelLayer, PixelLayerOrder;

// Объекты слоёв: спрайт, текст, примитивы.
export 'src/pixel_objects.dart' show PixelObject, PixelSprite, PixelText, PixelHitArea, PixelPrimitive, PixelPoint, PixelLine, PixelRect, PixelCircle;

// Текст: теги цвета и размер текста до рисования.
export 'src/pixel_markup.dart' show PixelMarkup, parsePixelMarkup, parsePixelColor;
export 'src/pixel_text_layout.dart' show layoutText, PixelTextLayout, PixelGlyph;
