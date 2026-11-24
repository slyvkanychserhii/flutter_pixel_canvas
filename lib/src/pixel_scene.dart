import 'dart:typed_data';
import 'dart:ui';

import 'pixel_atlas.dart';
import 'pixel_layer.dart';
import 'pixel_layout.dart';
import 'pixel_objects.dart';
import 'pixel_rasterize.dart';

/// Готовая к рисованию сцена: раскладка и всё, что можно подготовить заранее.
///
/// Раньше при каждой перерисовке (до 60 раз в секунду) и при каждом нажатии
/// заново раскладывался текст, растеризовались примитивы и собирались
/// массивы для drawRawAtlas. Но пока слои, атлас, размер сцены и кадры
/// анимаций те же, результат тот же. Поэтому всё это делается один раз при
/// создании [PixelScene], а холст хранит последнюю сцену и строит новую
/// только когда что-то из перечисленного изменилось.
///
/// Сцена неизменяемая: после создания только читается.
class PixelScene {
  PixelScene._({
    required this.layers,
    required this.atlas,
    required this.sceneSize,
    required this.frames,
    required this.layout,
    required List<List<_Op>?> ops,
    required List<List<List<Rect>?>> primitiveRects,
  })  : _ops = ops,
        _primitiveRects = primitiveRects;

  /// Строит сцену. [frames] это "отпечаток" текущих кадров анимированных
  /// спрайтов: он только сохраняется, чтобы холст мог сравнить его со
  /// следующим (см. `RenderPixelCanvas`). [frameOf] даёт имя текущего кадра
  /// спрайта.
  factory PixelScene.build({
    required List<PixelLayer> layers,
    required PixelAtlas? atlas,
    required Size sceneSize,
    required List<String> frames,
    required String Function(PixelSprite sprite) frameOf,
  }) {
    // 1. Положение спрайтов и текстов (в том числе в невидимых слоях:
    // к ним могут быть привязаны объекты видимых слоёв).
    final layout = layoutScene(
      layers: layers,
      atlas: atlas,
      sceneSize: sceneSize,
      frameOf: frameOf,
    );

    // 2. Для видимых слоёв: растр примитивов и готовые команды рисования.
    final ops = <List<_Op>?>[];
    final primitiveRects = <List<List<Rect>?>>[];
    for (var l = 0; l < layers.length; l++) {
      final layer = layers[l];
      if (!layer.visible) {
        ops.add(null); // невидимый слой не рисуется и не нажимается
        primitiveRects.add(const []);
        continue;
      }

      final layerOps = <_Op>[];
      final rects = <List<Rect>?>[];
      var batch = _AtlasBatch();

      // Рисует накопленную пачку и начинает новую: нужно перед всем, что
      // не входит в пачку (примитив, отражённый спрайт), чтобы сохранить
      // порядок объектов.
      void flush() {
        final done = batch.build();
        if (done != null) layerOps.add(done);
        batch = _AtlasBatch();
      }

      for (var i = 0; i < layer.items.length; i++) {
        final object = layer.items[i];
        final placed = layout.layers[l][i];
        rects.add(null);
        // switch по sealed-классу: компилятор следит за полнотой.
        switch (object) {
          case PixelSprite():
            if (placed == null) continue; // не рисуется
            if (placed.isFlipped) {
              // Отражение не выражается в drawRawAtlas: рисуем отдельно.
              flush();
              layerOps.add(_ImageOp(placed));
            } else {
              final t = placed.affine;
              batch.add(t.a, t.b, t.tx, t.ty, placed.source!, placed.color);
            }
          case PixelText():
            if (placed == null) continue; // не рисуется
            for (final glyph in placed.text!.glyphs) {
              final at = placed.position + glyph.position;
              batch.add(1, 0, at.dx, at.dy, glyph.source, glyph.color ?? object.color);
            }
          case PixelPrimitive():
            // Всё, что накопилось ниже примитива, рисуем до него: так
            // сохраняется порядок объектов в слое.
            flush();

            // Примитив это набор прямоугольников на сетке пикселей. Они
            // нужны и для рисования (один Path), и для проверки нажатий.
            final pixels = rasterize(object);
            rects[i] = pixels;
            final path = Path();
            for (final rect in pixels) {
              path.addRect(rect);
            }
            layerOps.add(_PathOp(path, object.color));
        }
      }
      final last = batch.build();
      if (last != null) layerOps.add(last);

      ops.add(layerOps);
      primitiveRects.add(rects);
    }

    return PixelScene._(
      layers: layers,
      atlas: atlas,
      sceneSize: sceneSize,
      frames: frames,
      layout: layout,
      ops: ops,
      primitiveRects: primitiveRects,
    );
  }

  // Из чего сцена построена. Холст сравнивает это с текущим состоянием,
  // чтобы понять, годится ли сцена ещё.
  final List<PixelLayer> layers;
  final PixelAtlas? atlas;
  final Size sceneSize;
  final List<String> frames;

  /// Где стоят спрайты и тексты.
  final PixelSceneLayout layout;

  // По слоям: команды рисования (null у невидимого слоя).
  final List<List<_Op>?> _ops;

  // По слоям и объектам: прямоугольники пикселей примитива (null у остальных
  // объектов и во всех невидимых слоях).
  final List<List<List<Rect>?>> _primitiveRects;

  /// Прямоугольники, из которых состоит примитив слоя [l] под номером [i]
  /// (null, если это не примитив или слой невидим).
  List<Rect>? primitiveRects(int l, int i) {
    final rects = _primitiveRects[l];
    return i < rects.length ? rects[i] : null;
  }

  /// Рисует слой [l] (невидимый слой не рисуется). Холст [canvas] уже в
  /// координатах сцены.
  void paintLayer(Canvas canvas, int l) {
    final ops = _ops[l];
    if (ops == null) return;
    final atlas = this.atlas;
    for (final op in ops) {
      switch (op) {
        case _AtlasOp():
          if (atlas != null) op.paint(canvas, atlas);
        case _PathOp():
          op.paint(canvas);
        case _ImageOp():
          if (atlas != null) op.paint(canvas, atlas);
      }
    }
  }
}

// Одна готовая команда рисования. Sealed: ровно два вида.
sealed class _Op {
  const _Op();
}

// Пачка кадров атласа для одного вызова drawRawAtlas.
//
// drawRawAtlas принимает плоские массивы чисел: для каждой картинки
// "куда поставить" (transforms: по 4 числа), "какой кусок атласа вырезать"
// (rects: по 4 числа) и цвет подкраски (colors).
final class _AtlasOp extends _Op {
  const _AtlasOp(this.transforms, this.rects, this.colors);

  final Float32List transforms;
  final Float32List rects;
  final Int32List colors;

  // Одна и та же кисть на все пачки: она ни от чего не зависит.
  static final Paint _paint = Paint()
    // FilterQuality.none: ближайший пиксель, без размытия при увеличении.
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  void paint(Canvas canvas, PixelAtlas atlas) {
    canvas.drawRawAtlas(
      atlas.image,
      transforms,
      rects,
      colors,
      // modulate: цвет картинки умножается на цвет из colors. Белый глиф
      // становится цветом текста, прозрачные пиксели остаются прозрачными.
      BlendMode.modulate,
      null, // cullRect: без отсечения
      _paint,
    );
  }
}

// Примитив: один Path и кисть с его цветом. Path целиком рисуется одним
// вызовом, поэтому полупрозрачный примитив получает одинаковый цвет по всей
// площади, даже там, где его части перекрываются.
final class _PathOp extends _Op {
  _PathOp(this.path, Color color)
      : _paint = Paint()
          ..color = color
          ..isAntiAlias = false;

  final Path path;
  final Paint _paint;

  void paint(Canvas canvas) => canvas.drawPath(path, _paint);
}

// Один отражённый спрайт: рисуется отдельно через матрицу, потому что
// drawRawAtlas не умеет отражать.
final class _ImageOp extends _Op {
  _ImageOp(PixelPlaced placed)
      : source = placed.source!,
        matrix = _matrix(placed),
        _paint = Paint()
          ..filterQuality = FilterQuality.none
          ..isAntiAlias = false
          // modulate: цвет кадра умножается на подкраску (и на прозрачность),
          // так же как в пачке drawRawAtlas.
          ..colorFilter = ColorFilter.mode(placed.color, BlendMode.modulate);

  final Rect source;
  final Float64List matrix;
  final Paint _paint;

  // Матрица 4x4 (по столбцам) из аффинного преобразования спрайта.
  static Float64List _matrix(PixelPlaced placed) {
    final t = placed.affine;
    return Float64List.fromList([
      t.a, t.b, 0, 0, //
      t.c, t.d, 0, 0, //
      0, 0, 1, 0, //
      t.tx, t.ty, 0, 1, //
    ]);
  }

  void paint(Canvas canvas, PixelAtlas atlas) {
    canvas.save();
    canvas.transform(matrix);
    // Кадр рисуется в начало координат: матрица уже переносит его на место.
    canvas.drawImageRect(
      atlas.image,
      source,
      Offset.zero & source.size,
      _paint,
    );
    canvas.restore();
  }
}

// Накапливает кадры будущей пачки и превращает их в [_AtlasOp].
class _AtlasBatch {
  // По 4 числа на кадр: scos, ssin, tx, ty (преобразование вида "увеличить
  // в s раз, повернуть, сдвинуть": scos = s*cos, ssin = s*sin).
  final List<double> _transforms = [];
  final List<Rect> _sources = [];
  final List<Color> _colors = [];

  void add(
    double scos,
    double ssin,
    double tx,
    double ty,
    Rect source,
    Color color,
  ) {
    _transforms
      ..add(scos)
      ..add(ssin)
      ..add(tx)
      ..add(ty);
    _sources.add(source);
    _colors.add(color);
  }

  /// Готовая пачка или null, если в ней ничего нет.
  _AtlasOp? build() {
    final count = _sources.length;
    if (count == 0) return null;

    final transforms = Float32List(count * 4);
    final rects = Float32List(count * 4);
    final argb = Int32List(count);
    for (var i = 0; i < count; i++) {
      final k = i * 4;
      transforms[k] = _transforms[k];
      transforms[k + 1] = _transforms[k + 1];
      transforms[k + 2] = _transforms[k + 2];
      transforms[k + 3] = _transforms[k + 3];
      // Какой кусок картинки вырезаем: left, top, right, bottom.
      rects[k] = _sources[i].left;
      rects[k + 1] = _sources[i].top;
      rects[k + 2] = _sources[i].right;
      rects[k + 3] = _sources[i].bottom;
      argb[i] = _colors[i].toARGB32();
    }
    return _AtlasOp(transforms, rects, argb);
  }
}
