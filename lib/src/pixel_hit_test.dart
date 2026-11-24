import 'package:flutter/painting.dart';

import 'pixel_atlas.dart';
import 'pixel_layer.dart';
import 'pixel_layout.dart';
import 'pixel_objects.dart';
import 'pixel_scene.dart';

/// Результат попадания: в какой слой и в какой объект нажали.
class PixelHit {
  const PixelHit({required this.layerId, required this.object, this.bounds});

  /// id слоя, в котором лежит объект.
  final String layerId;

  /// Объект, в который попали.
  final PixelObject object;

  /// Где объект стоит на сцене (в пикселях сцены): прямоугольник кадра
  /// спрайта или текста. У примитивов null. Полезно, когда положение задано
  /// выравниванием и из полей объекта его не узнать.
  final Rect? bounds;

  /// id найденного объекта (может быть null, если id не задавали).
  String? get id => object.id;

  /// Объект как спрайт (или null, если это не спрайт).
  PixelSprite? get sprite => object is PixelSprite ? object as PixelSprite : null;

  /// Объект как текст (или null, если это не текст).
  PixelText? get text => object is PixelText ? object as PixelText : null;

  /// Объект как примитив (или null, если это не примитив).
  PixelPrimitive? get primitive =>
      object is PixelPrimitive ? object as PixelPrimitive : null;
}

/// Нажатие на холст: куда нажали и что там оказалось.
class PixelTap {
  const PixelTap({required this.x, required this.y, this.hit});

  /// Пиксель сцены, на который пришлось нажатие.
  final int x;
  final int y;

  /// Самая верхняя графика под пальцем, а если там пусто, то null.
  final PixelHit? hit;
}

/// Ищет самый верхний объект в пикселе сцены (x, y).
///
/// Обход идёт СВЕРХУ ВНИЗ, зеркально отрисовке: сначала самый верхний слой,
/// внутри слоя с конца списка объектов. Поэтому нажатие достаётся тому, что
/// человек видит на экране сверху.
///
/// Невидимые слои пропускаются. Спрайты по умолчанию проверяются по
/// непрозрачным пикселям текущего кадра, тексты по прямоугольнику, в который
/// помещаются все строки ([PixelHitArea] меняет это для каждого объекта),
/// примитивы по пикселям, из которых они состоят. Прозрачность примитива
/// не учитывается.
///
/// Где стоят спрайты и тексты и из каких пикселей состоят примитивы, берётся
/// из готовой [scene]: так нажатие и отрисовка пользуются одними и теми же
/// данными, и ничего не пересчитывается при каждом нажатии.
PixelHit? hitTestLayers(
  List<PixelLayer> layers,
  PixelScene scene,
  int x,
  int y,
) {
  // Проверяем центр пикселя, а не его угол: так попадание не зависит
  // от того, как округляются границы прямоугольников.
  final point = Offset(x + 0.5, y + 0.5);

  for (var l = layers.length - 1; l >= 0; l--) {
    final layer = layers[l];
    if (!layer.visible) continue;

    for (var i = layer.items.length - 1; i >= 0; i--) {
      final object = layer.items[i];
      final placed = scene.layout.layers[l][i];
      if (_contains(
            object, placed, scene.primitiveRects(l, i), scene.atlas, point)) {
        return PixelHit(layerId: layer.id, object: object, bounds: placed?.rect);
      }
    }
  }
  return null;
}

// Лежит ли точка внутри объекта. [placed] это положение спрайта или текста
// (null, если объект не рисуется), [pixels] пиксели примитива.
bool _contains(
  PixelObject object,
  PixelPlaced? placed,
  List<Rect>? pixels,
  PixelAtlas? atlas,
  Offset point,
) {
  // switch по sealed-классу: компилятор следит за полнотой.
  switch (object) {
    case PixelSprite():
      if (placed == null || !placed.rect.contains(point)) return false;
      if (object.hitArea == PixelHitArea.bounds) return true;
      // По пикселям: смотрим пиксель кадра (текущего кадра анимации) с
      // учётом поворота, отражения и увеличения спрайта.
      if (atlas == null) return false;
      final local = placed.frameLocal(point);
      return atlas.isSolid(
        placed.source!.left.toInt() + local.dx.floor(),
        placed.source!.top.toInt() + local.dy.floor(),
      );
    case PixelText():
      if (placed == null || !placed.rect.contains(point)) return false;
      if (object.hitArea == PixelHitArea.bounds) return true;
      // По пикселям: ищем глиф под точкой и смотрим его пиксель.
      for (final glyph in placed.text!.glyphs) {
        final origin = placed.position + glyph.position;
        if ((origin & glyph.source.size).contains(point) &&
            _solidAt(atlas, glyph.source, origin, point)) {
          return true;
        }
      }
      return false;
    case PixelPrimitive():
      for (final rect in pixels ?? const <Rect>[]) {
        if (rect.contains(point)) return true;
      }
      return false;
  }
}

// Непрозрачен ли пиксель кадра под точкой сцены. [source] это кадр в
// картинке атласа, [origin] его левый верхний угол на сцене.
bool _solidAt(PixelAtlas? atlas, Rect source, Offset origin, Offset point) {
  if (atlas == null) return false;
  final local = point - origin; // точка внутри кадра
  return atlas.isSolid(
    source.left.toInt() + local.dx.floor(),
    source.top.toInt() + local.dy.floor(),
  );
}
