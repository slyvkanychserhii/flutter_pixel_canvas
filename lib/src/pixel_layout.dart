import 'package:flutter/painting.dart';

import 'pixel_atlas.dart';
import 'pixel_layer.dart';
import 'pixel_objects.dart';
import 'pixel_text_layout.dart';

/// Объект (спрайт или текст) после раскладки: где он стоит и какой он по
/// размеру. Все координаты в пикселях сцены, целые.
class PixelPlaced {
  const PixelPlaced({
    required this.position,
    required this.size,
    this.source,
    this.text,
    this.zoom = 1,
    this.quarterTurns = 0,
    this.flipX = false,
    this.flipY = false,
    this.color = const Color(0xFFFFFFFF),
  });

  /// Левый верхний угол объекта на сцене.
  final Offset position;

  /// Размер объекта на сцене: у спрайта после поворота и увеличения, у
  /// текста прямоугольник всех строк.
  final Size size;

  /// Для спрайта: прямоугольник кадра в картинке атласа (для текста null).
  final Rect? source;

  /// Для текста: раскладка глифов (для спрайта null).
  final PixelTextLayout? text;

  // Для спрайта: преобразования (см. PixelSprite). quarterTurns уже
  // приведён к 0..3.
  final int zoom;
  final int quarterTurns;
  final bool flipX;
  final bool flipY;

  /// Для спрайта: итоговая подкраска (tint вместе с opacity).
  final Color color;

  /// Прямоугольник объекта на сцене.
  Rect get rect => position & size;

  /// Нужно ли отражение. Его нельзя выразить в drawRawAtlas (там только
  /// поворот, увеличение и сдвиг), такие спрайты рисуются отдельно.
  bool get isFlipped => flipX || flipY;

  /// Как кадр спрайта попадает на сцену: точка кадра (x, y) переходит в
  /// (a*x + c*y + tx, b*x + d*y + ty). Включает отражение, поворот,
  /// увеличение и положение. Только для спрайта.
  ({double a, double b, double c, double d, double tx, double ty}) get affine {
    final w = source!.width;
    final h = source!.height;
    final s = zoom.toDouble();

    // Поворот по часовой стрелке: (rc, rs) это косинус и синус угла,
    // (rtx, rty) сдвиг, возвращающий повёрнутый кадр в положительную
    // четверть (в единицах кадра).
    final (rc, rs, rtx, rty) = switch (quarterTurns) {
      1 => (0.0, 1.0, h, 0.0),
      2 => (-1.0, 0.0, w, h),
      3 => (0.0, -1.0, 0.0, w),
      _ => (1.0, 0.0, 0.0, 0.0),
    };

    // Отражение: x' = sx * x + ox, y' = sy * y + oy.
    final sx = flipX ? -1.0 : 1.0;
    final sy = flipY ? -1.0 : 1.0;
    final ox = flipX ? w : 0.0;
    final oy = flipY ? h : 0.0;

    return (
      a: s * rc * sx,
      b: s * rs * sx,
      c: -s * rs * sy,
      d: s * rc * sy,
      tx: position.dx + s * rtx + s * (rc * ox - rs * oy),
      ty: position.dy + s * rty + s * (rs * ox + rc * oy),
    );
  }

  /// Обратное преобразование: точка сцены [point] (внутри [rect]) ->
  /// точка внутри кадра (от его левого верхнего угла, в пикселях кадра).
  /// Нужно, чтобы нажатие по пикселям смотрело в правильный пиксель
  /// повёрнутого, отражённого и увеличенного спрайта. Только для спрайта.
  Offset frameLocal(Offset point) {
    final w = source!.width;
    final h = source!.height;
    final q = point - position;
    // Убираем увеличение, потом поворот, потом отражение.
    final ux = q.dx / zoom;
    final uy = q.dy / zoom;
    var (x, y) = switch (quarterTurns) {
      1 => (uy, h - ux),
      2 => (w - ux, h - uy),
      3 => (w - uy, ux),
      _ => (ux, uy),
    };
    if (flipX) x = w - x;
    if (flipY) y = h - y;
    return Offset(x, y);
  }
}

/// Результат раскладки всей сцены.
class PixelSceneLayout {
  const PixelSceneLayout(this.layers);

  /// По слоям и по объектам слоя, в том же порядке, что [PixelLayer.items].
  /// null у объекта, которого нет смысла размещать: примитив (у него свои
  /// абсолютные координаты) или спрайт/текст, который не рисуется
  /// (нет кадра в атласе, нет шрифта, нет атласа).
  final List<List<PixelPlaced?>> layers;
}

/// Расставляет спрайты и тексты по сцене.
///
/// Положение объекта задаётся двумя точками и смещением:
///
/// * [PixelSprite.align] (или [PixelText.align]): точка НА САМОМ ОБЪЕКТЕ.
///   Alignment(-1, -1) это левый верхний угол, (0, 0) центр, (1, 1)
///   правый нижний угол;
/// * anchorAlign: точка на ОПОРЕ, к которой объект крепится. Опора это весь
///   холст или другой объект (поле anchor с его id). Если anchorAlign не
///   задан, берётся та же точка, что align: объект вписывается в опору
///   (например, align: bottomRight прижимает объект к правому нижнему углу);
/// * (x, y): смещение в пикселях сцены от точки опоры.
///
/// Формула: левый верхний угол = (точка опоры) - (точка на объекте)
/// + смещение; результат округляется до целых пикселей сцены.
///
/// Примеры:
///   align: Alignment.topRight, x: -2     прижать к правому краю с отступом 2;
///   align: Alignment.center              по центру холста;
///   anchor: 'a', anchorAlign: bottomCenter, align: topCenter, y: 2
///   подпись под объектом 'a', по его центру.
///
/// Опора разрешается так: объекты размещаются в порядке списков, но если
/// опора ещё не размещена, она размещается первой (по цепочке). Если опоры
/// с таким id нет, она не рисуется или объект ссылается сам на себя, опорой
/// становится холст. Цикл (A крепится к B, B к A) разрывается так: тот
/// объект, до которого дошла очередь второй, крепится к холсту.
/// Если id у нескольких объектов совпадают, опорой служит первый
/// (нижний слой, раньше в списке). Опорой могут быть только спрайт и текст.
///
/// [frameOf] возвращает имя кадра спрайта на текущий момент (у
/// анимированного спрайта это кадр анимации): от размера кадра зависит
/// положение.
PixelSceneLayout layoutScene({
  required List<PixelLayer> layers,
  required PixelAtlas? atlas,
  required Size sceneSize,
  required String Function(PixelSprite sprite) frameOf,
}) {
  final resolver = _Resolver(layers, atlas, sceneSize, frameOf);
  return PixelSceneLayout([
    for (var l = 0; l < layers.length; l++)
      [
        for (var i = 0; i < layers[l].items.length; i++) resolver.resolve(l, i),
      ],
  ]);
}

// Позиция объекта в списке слоёв: номер слоя и номер объекта в слое.
typedef _Slot = (int, int);

// Считает положение объектов по требованию и запоминает результат.
class _Resolver {
  _Resolver(this.layers, this.atlas, this.sceneSize, this.frameOf) {
    // id -> первый объект с таким id (только спрайты и тексты).
    for (var l = 0; l < layers.length; l++) {
      for (var i = 0; i < layers[l].items.length; i++) {
        final object = layers[l].items[i];
        final id = object.id;
        if (id != null && object is! PixelPrimitive) {
          _byId.putIfAbsent(id, () => (l, i));
        }
      }
    }
  }

  final List<PixelLayer> layers;
  final PixelAtlas? atlas;
  final Size sceneSize;
  final String Function(PixelSprite sprite) frameOf;

  final Map<String, _Slot> _byId = {};
  final Map<_Slot, PixelPlaced?> _done = {}; // уже посчитанные
  final Set<_Slot> _inProgress = {}; // считаются прямо сейчас (для циклов)

  PixelPlaced? resolve(int l, int i) {
    final slot = (l, i);
    if (_done.containsKey(slot)) return _done[slot];

    final object = layers[l].items[i];

    // Размер объекта (и то, что нужно для рисования).
    final Size size;
    Rect? source;
    PixelTextLayout? text;
    var turns = 0;
    var color = const Color(0xFFFFFFFF);
    switch (object) {
      case PixelSprite():
        source = atlas?.frame(frameOf(object));
        if (source == null) return _done[slot] = null; // не рисуется
        // Размер на сцене: увеличенный, а при повороте на 90 или 270
        // градусов ширина и высота меняются местами.
        turns = object.quarterTurns % 4;
        final z = object.zoom.toDouble();
        size = turns.isOdd
            ? Size(source.height * z, source.width * z)
            : Size(source.width * z, source.height * z);
        // Прозрачность спрайта это альфа подкраски.
        color = object.tint
            .withValues(alpha: object.tint.a * object.opacity);
      case PixelText():
        text = atlas == null ? null : layoutText(object, atlas!);
        if (text == null) return _done[slot] = null; // не рисуется
        size = text.size;
      case PixelPrimitive():
        return _done[slot] = null; // у примитива свои координаты
    }

    // Читаем поля размещения (у спрайта и текста они одинаковые).
    final (anchorId, align, anchorAlign, dx, dy) = switch (object) {
      PixelSprite() => (
          object.anchor,
          object.align,
          object.anchorAlign,
          object.x,
          object.y
        ),
      PixelText() => (
          object.anchor,
          object.align,
          object.anchorAlign,
          object.x,
          object.y
        ),
      PixelPrimitive() => (null, Alignment.topLeft, null, 0, 0), // не бывает
    };

    // Опора: другой объект или (по умолчанию и при любой проблеме) холст.
    _inProgress.add(slot);
    Rect reference = Offset.zero & sceneSize;
    if (anchorId != null) {
      final anchorSlot = _byId[anchorId];
      if (anchorSlot != null && !_inProgress.contains(anchorSlot)) {
        final placed = resolve(anchorSlot.$1, anchorSlot.$2);
        if (placed != null) reference = placed.rect;
      }
    }
    _inProgress.remove(slot);

    // Левый верхний угол = точка опоры - точка на объекте + смещение.
    final point = reference.topLeft + (anchorAlign ?? align).alongSize(reference.size);
    final corner = point - align.alongSize(size) + Offset(dx.toDouble(), dy.toDouble());

    return _done[slot] = PixelPlaced(
      position: Offset(corner.dx.roundToDouble(), corner.dy.roundToDouble()),
      size: size,
      source: source,
      text: text,
      zoom: object is PixelSprite ? object.zoom : 1,
      quarterTurns: turns,
      flipX: object is PixelSprite && object.flipX,
      flipY: object is PixelSprite && object.flipY,
      color: color,
    );
  }
}
