import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'pixel_hit_test.dart';
import 'pixel_atlas.dart';
import 'pixel_layer.dart';
import 'pixel_objects.dart';
import 'pixel_scene.dart';

/// Функция рисования в координатах сцены.
///
/// [canvas] уже масштабирован: 1 единица = 1 пиксель сцены (на экране это
/// [PixelCanvas.scale] x [PixelCanvas.scale] физических пикселей).
/// Начало координат (0, 0) это левый верхний угол холста.
/// [sceneSize] это размер холста в пикселях сцены (целые числа).
typedef PixelPaintCallback = void Function(Canvas canvas, Size sceneSize);

/// Как холст обращается с нажатиями. Имеет смысл, когда у холста есть
/// дочерний виджет ([PixelCanvas.child]): графика лежит поверх него, и
/// режим решает, кому достаются нажатия: графике или дочернему виджету.
enum PixelTouchMode {
  /// Холст принимает все нажатия на всей своей площади, дочерний виджет
  /// ничего не получает. Режим по умолчанию, если дочернего виджета нет.
  capture,

  /// Холст принимает только нажатия, попавшие в графику (спрайт, текст,
  /// примитив видимого слоя). Остальные достаются дочернему виджету. Но
  /// если графика закрывает кнопку, кнопка не нажмётся: нажатие достаётся
  /// графике. onTap вызывается только для нажатий на графику. Режим по
  /// умолчанию, если дочерний виджет есть.
  graphicsOnly,

  /// Холст не блокирует ничего: все нажатия достаются дочернему виджету,
  /// даже сквозь графику. Холст при этом всё равно узнаёт о нажатиях и
  /// сообщает о них в onTap (hit будет заполнен, если под пальцем графика).
  transparent,
}

/// Холст для пиксельной графики.
///
/// * Занимает всё место, которое дал родитель (как SizedBox.expand).
///   Родитель обязан задать конечные ограничения: внутри Column или ListView
///   оберните холст в Expanded или SizedBox.
/// * Рисует в "пикселях сцены". Один пиксель сцены на экране это квадрат
///   [scale] x [scale] физических пикселей, без сглаживания.
/// * Если задан [child], он занимает всю площадь холста, а графика рисуется
///   ПОВЕРХ него (фон холста лежит под ним). Чтобы графика была над целым
///   экраном, оберните холстом весь экран: PixelCanvas(child: Scaffold(...)).
/// * Если задан [onTap], сообщает, куда нажали и на какую графику
///   (спрайт или примитив) и в каком слое.
class PixelCanvas extends StatefulWidget {
  const PixelCanvas({
    super.key,
    this.scale = 1,
    this.background = const Color(0xFF000000),
    this.atlas,
    this.layers = const [],
    this.onTap,
    this.touchMode,
    this.child,
    this.onPaint,
  }) : assert(scale >= 1, 'scale должен быть не меньше 1');

  /// Целый множитель масштаба: 1, 2, 3... Целый, чтобы пиксели сцены
  /// всегда ложились ровно на физические пиксели экрана.
  final int scale;

  /// Цвет фона холста.
  final Color background;

  /// Атлас, из которого берутся кадры спрайтов. Холст его не освобождает:
  /// этим занимается тот, кто его загрузил. Без атласа спрайты не рисуются.
  final PixelAtlas? atlas;

  /// Слои снизу вверх: каждый следующий перекрывает предыдущие.
  /// См. [PixelLayer].
  final List<PixelLayer> layers;

  /// Вызывается при нажатии на холст. Нажатие сообщается всегда: если под
  /// пальцем пусто, [PixelTap.hit] равен null.
  final ValueChanged<PixelTap>? onTap;

  /// Как холст обращается с нажатиями, см. [PixelTouchMode]. Если не задан:
  /// capture, а когда есть [child], graphicsOnly.
  final PixelTouchMode? touchMode;

  /// Обычный виджет под графикой. Получает ограничения холста целиком
  /// (занимает всю площадь), а раскладка внутри на вашей стороне: например,
  /// Stack или Column. Графика рисуется поверх него.
  final Widget? child;

  /// Здесь приложение рисует свою графику (поверх всех слоёв).
  final PixelPaintCallback? onPaint;

  @override
  State<PixelCanvas> createState() => _PixelCanvasState();
}

// Одна запущенная анимация спрайта: какая, какой по счёту запуск
// и в какой момент по часам холста стартовала.
class _AnimationRun {
  const _AnimationRun(this.animation, this.run, this.start);

  final String animation;
  final int run;
  final Duration start;
}

/// Состояние холста: часы для анимаций и обработка нажатий.
///
/// Часы это Ticker: Flutter вызывает его перед каждым кадром экрана.
/// Он запущен только пока есть что анимировать, иначе холст не тратит
/// ресурсы на ненужные перерисовки.
class _PixelCanvasState extends State<PixelCanvas>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);

  // Время холста: сколько прошло, пока работали часы. Хранится отдельно
  // от Ticker, потому что при остановке и новом запуске Ticker считает
  // с нуля, а анимации нужно непрерывное время.
  Duration _time = Duration.zero;
  Duration _tickBase = Duration.zero; // _time на момент запуска Ticker

  // id спрайта -> его запущенная анимация. Нужны, чтобы понять, когда
  // анимация началась и когда её нужно перезапустить.
  final Map<String, _AnimationRun> _runs = {};

  // Ключ нужен, чтобы из состояния добраться до RenderObject: только он
  // знает размер сцены и текущие кадры анимаций, а значит, где что стоит.
  final GlobalKey _renderKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _syncRuns();
    _syncTicker();
  }

  @override
  void didUpdateWidget(PixelCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRuns();
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // Сверяем запущенные анимации со спрайтами. Новый спрайт, другое имя
  // анимации или другой animationRun означают запуск с этого момента.
  void _syncRuns() {
    final seen = <String>{};
    for (final layer in widget.layers) {
      for (final sprite in layer.items.whereType<PixelSprite>()) {
        final animation = sprite.animation;
        if (animation == null) continue;
        final id = sprite.id!; // PixelSprite гарантирует id при animation
        seen.add(id);

        final run = _runs[id];
        if (run == null ||
            run.animation != animation ||
            run.run != sprite.animationRun) {
          _runs[id] = _AnimationRun(animation, sprite.animationRun, _time);
        }
      }
    }
    // Спрайты, которых больше нет, забываем.
    _runs.removeWhere((id, _) => !seen.contains(id));
  }

  // Есть ли что-то, что сейчас движется: видимый спрайт с анимацией,
  // которая зациклена или ещё не дошла до конца.
  bool _needsTicker() {
    final atlas = widget.atlas;
    if (atlas == null) return false;

    for (final layer in widget.layers) {
      if (!layer.visible) continue;
      for (final sprite in layer.items.whereType<PixelSprite>()) {
        final name = sprite.animation;
        if (name == null) continue;
        final animation = atlas.animation(name);
        final run = _runs[sprite.id];
        if (animation == null || run == null) continue;
        if (!animation.isFinished(_time - run.start)) return true;
      }
    }
    return false;
  }

  // Включает или выключает часы в зависимости от того, нужны ли они.
  void _syncTicker() {
    final needed = _needsTicker();
    if (needed && !_ticker.isActive) {
      _tickBase = _time;
      _ticker.start();
    } else if (!needed && _ticker.isActive) {
      _ticker.stop();
    }
  }

  // Часы тикнули: обновляем время, и холст перерисуется с новыми кадрами.
  void _onTick(Duration elapsed) {
    setState(() => _time = _tickBase + elapsed);
    _syncTicker(); // если всё доиграло, часы выключатся
  }

  // Позиция нажатия в экранных пикселях относительно холста -> onTap.
  void _notifyTap(Offset localPosition, {bool requireHit = false}) {
    // Делим на масштаб и отбрасываем дробную часть, получаем пиксель сцены.
    final x = (localPosition.dx / widget.scale).floor();
    final y = (localPosition.dy / widget.scale).floor();
    // Спрашиваем RenderObject: он ищет по той же раскладке, что рисует.
    final render = _renderKey.currentContext?.findRenderObject();
    final hit = render is RenderPixelCanvas ? render.hitTestAt(x, y) : null;
    // requireHit: сообщаем только о нажатиях на графику.
    if (requireHit && hit == null) return;
    widget.onTap!(PixelTap(x: x, y: y, hit: hit));
  }

  // --- Режим transparent: слушаем указатель, не участвуя в жестах ---------
  //
  // Обычный GestureDetector вступает в "спор" жестов с кнопками под холстом
  // и обычно побеждает как верхний. Поэтому в режиме transparent вместо него
  // стоит Listener: он только наблюдает за касаниями и ни с кем не спорит.
  // Нажатием считаем касание, которое закончилось рядом с началом (палец
  // не уехал дальше kTouchSlop): иначе это был бы скролл.
  int? _pointer; // какое касание отслеживаем
  Offset _downPosition = Offset.zero;

  void _onPointerDown(PointerDownEvent event) {
    if (_pointer != null) return; // уже следим за другим пальцем
    _pointer = event.pointer;
    _downPosition = event.localPosition;
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    if ((event.localPosition - _downPosition).distance <= kTouchSlop) {
      _notifyTap(event.localPosition);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _pointer) _pointer = null;
  }

  @override
  Widget build(BuildContext context) {
    // Режим по умолчанию зависит от того, есть ли дочерний виджет.
    final mode = widget.touchMode ??
        (widget.child == null
            ? PixelTouchMode.capture
            : PixelTouchMode.graphicsOnly);

    final leaf = _PixelCanvasRenderWidget(
      key: _renderKey,
      scale: widget.scale,
      background: widget.background,
      atlas: widget.atlas,
      layers: widget.layers,
      time: _time,
      animationStarts: {
        for (final entry in _runs.entries) entry.key: entry.value.start,
      },
      touchMode: mode,
      onPaint: widget.onPaint,
      // RepaintBoundary: дочерний виджет рисуется в собственный слой и не
      // перерисовывается заново при каждом кадре анимации графики.
      child: widget.child == null ? null : RepaintBoundary(child: widget.child),
    );

    if (mode == PixelTouchMode.transparent) {
      // Без onTap слушать нечего: холст просто невидим для нажатий.
      if (widget.onTap == null) return leaf;
      return Listener(
        // translucent: Listener видит касания, но не заслоняет виджеты под ним.
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: leaf,
      );
    }

    return GestureDetector(
      // opaque (capture): нажатия ловятся по всей площади холста, даже там,
      // где ничего не нарисовано.
      // deferToChild (graphicsOnly): решает сам холст (см.
      // RenderPixelCanvas.hitTestSelf), и он берёт только нажатия, попавшие
      // в графику; остальные достаются виджетам под ним.
      behavior: mode == PixelTouchMode.graphicsOnly
          ? HitTestBehavior.deferToChild
          : HitTestBehavior.opaque,
      onTapUp: widget.onTap == null
          ? null
          : (details) => _notifyTap(
                details.localPosition,
                requireHit: mode == PixelTouchMode.graphicsOnly,
              ),
      child: leaf,
    );
  }
}

/// Внутренний виджет: создаёт RenderObject и обновляет его параметры.
/// Дочерний виджет (если есть) Flutter подключает к RenderObject сам.
class _PixelCanvasRenderWidget extends SingleChildRenderObjectWidget {
  const _PixelCanvasRenderWidget({
    super.key,
    super.child,
    required this.scale,
    required this.background,
    required this.atlas,
    required this.layers,
    required this.time,
    required this.animationStarts,
    required this.touchMode,
    required this.onPaint,
  });

  final int scale;
  final Color background;
  final PixelAtlas? atlas;
  final List<PixelLayer> layers;
  final Duration time;
  final Map<String, Duration> animationStarts;
  final PixelTouchMode touchMode;
  final PixelPaintCallback? onPaint;

  // Flutter вызывает это, когда нужно создать RenderObject в первый раз.
  @override
  RenderPixelCanvas createRenderObject(BuildContext context) {
    return RenderPixelCanvas(
      scale: scale,
      background: background,
      atlas: atlas,
      layers: layers,
      time: time,
      animationStarts: animationStarts,
      touchMode: touchMode,
      onPaint: onPaint,
    );
  }

  // Flutter вызывает это, когда виджет пересобрали с новыми параметрами.
  // RenderObject остаётся тем же, мы только обновляем его поля.
  @override
  void updateRenderObject(BuildContext context, RenderPixelCanvas renderObject) {
    renderObject
      ..scale = scale
      ..background = background
      ..atlas = atlas
      ..layers = layers
      ..time = time
      ..animationStarts = animationStarts
      ..touchMode = touchMode
      ..onPaint = onPaint;
  }
}

/// RenderObject холста: считает размер и рисует.
class RenderPixelCanvas extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  RenderPixelCanvas({
    required int scale,
    required Color background,
    required PixelAtlas? atlas,
    required List<PixelLayer> layers,
    required Duration time,
    required Map<String, Duration> animationStarts,
    required this.touchMode,
    required PixelPaintCallback? onPaint,
  })  : _scale = scale,
        _background = background,
        _atlas = atlas,
        _layers = layers,
        _time = time,
        _animationStarts = animationStarts,
        _onPaint = onPaint;

  // --- Поля с сеттерами ---------------------------------------------------
  // Сеттер сравнивает новое значение со старым и просит перерисовку
  // только если что-то правда изменилось.

  int _scale;
  int get scale => _scale;
  set scale(int value) {
    if (_scale == value) return;
    _scale = value;
    markNeedsPaint();
  }

  Color _background;
  Color get background => _background;
  set background(Color value) {
    if (_background == value) return;
    _background = value;
    markNeedsPaint();
  }

  PixelAtlas? _atlas;
  PixelAtlas? get atlas => _atlas;
  set atlas(PixelAtlas? value) {
    if (identical(_atlas, value)) return;
    _atlas = value;
    markNeedsPaint();
  }

  List<PixelLayer> _layers;
  List<PixelLayer> get layers => _layers;
  set layers(List<PixelLayer> value) {
    // Приложение обычно собирает новый список при каждой пересборке виджета,
    // поэтому сравнивать содержимое смысла нет: если это тот же самый
    // объект, ничего не изменилось, иначе просто перерисовываем.
    if (identical(_layers, value)) return;
    _layers = value;
    _animatedSprites = null; // список анимированных спрайтов устарел
    markNeedsPaint();
  }

  // Время холста и моменты старта анимаций (id спрайта -> время старта).
  // От них зависит, какой кадр анимации показывать.
  Duration _time;
  Duration get time => _time;
  set time(Duration value) {
    if (_time == value) return;
    _time = value;
    markNeedsPaint();
  }

  Map<String, Duration> _animationStarts;
  Map<String, Duration> get animationStarts => _animationStarts;
  set animationStarts(Map<String, Duration> value) {
    _animationStarts = value;
    markNeedsPaint();
  }

  // Режим обработки нажатий. Влияет только на нажатия, поэтому перерисовка
  // не нужна.
  PixelTouchMode touchMode;

  PixelPaintCallback? _onPaint;
  PixelPaintCallback? get onPaint => _onPaint;
  set onPaint(PixelPaintCallback? value) {
    // Приложение передаёт новую функцию при каждой пересборке виджета,
    // поэтому сравнивать смысла нет: просто перерисовываем.
    _onPaint = value;
    markNeedsPaint();
  }

  // --- Размер -------------------------------------------------------------

  // Размер зависит только от ограничений родителя (не от содержимого).
  // Тогда Flutter не пересчитывает раскладку лишний раз.
  @override
  bool get sizedByParent => true;

  // Занимаем максимум, что дал родитель.
  @override
  Size computeDryLayout(BoxConstraints constraints) {
    // Если родитель не ограничил размер (например, холст прямо в Column),
    // biggest бесконечный. Падаем с понятным сообщением.
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
      throw FlutterError(
        'PixelCanvas занимает всё место родителя, а родитель не задал '
        'размер ($constraints). Оберните холст в Expanded или SizedBox.',
      );
    }
    return constraints.biggest;
  }

  // Дочерний виджет занимает всю площадь холста.
  @override
  void performLayout() {
    child?.layout(BoxConstraints.tight(size));
  }

  // Размер сцены в пикселях сцены: целое число пикселей, остаток отбрасываем.
  Size get sceneSize => Size(
        (size.width / _scale).floorToDouble(),
        (size.height / _scale).floorToDouble(),
      );

  // --- Нажатия ------------------------------------------------------------

  // Куда попало нажатие: в графику холста или в дочерний виджет.
  //
  // Графика лежит ПОВЕРХ дочернего виджета, поэтому сначала спрашиваем
  // холст (hitTestSelf), и только если он не взял нажатие, дочерний виджет.
  // (Обычный RenderBox.hitTest спрашивает наоборот: сначала детей.)
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;

    if (hitTestSelf(position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }

    final child = this.child;
    if (child == null) return false;
    // Дочерний виджет лежит в точке (0, 0) холста.
    return result.addWithPaintOffset(
      offset: Offset.zero,
      position: position,
      hitTest: (result, transformed) =>
          child.hitTest(result, position: transformed),
    );
  }

  // Flutter спрашивает: "принадлежит ли точка нам?" (position это экранные
  // пиксели относительно левого верхнего угла холста).
  //
  // * capture: да, любая точка на площади холста;
  // * graphicsOnly: только точка, в которой есть графика;
  // * transparent: никогда, всё достаётся дочернему виджету.
  @override
  bool hitTestSelf(Offset position) {
    switch (touchMode) {
      case PixelTouchMode.capture:
        return true;
      case PixelTouchMode.transparent:
        return false;
      case PixelTouchMode.graphicsOnly:
        final x = (position.dx / _scale).floor();
        final y = (position.dy / _scale).floor();
        return hitTestAt(x, y) != null;
    }
  }

  // Что лежит сверху в пикселе сцены (x, y).
  PixelHit? hitTestAt(int x, int y) => hitTestLayers(_layers, _scene(), x, y);

  // --- Кэш сцены ----------------------------------------------------------
  //
  // Сцена (раскладка, растр примитивов, массивы для drawRawAtlas) строится
  // один раз и хранится, пока не изменится то, от чего она зависит: список
  // слоёв, атлас, размер сцены или текущие кадры анимаций. Обычная
  // перерисовка (например, смена кадра у соседнего виджета) и нажатия
  // берут готовую сцену.
  //
  // Список слоёв сравнивается по ссылке, а не по содержимому: если
  // приложение при каждой пересборке создаёт новый список (так обычно и
  // бывает), сцена пересоберётся, зато часы анимации холста, которые
  // пересобирают только сам холст, список не меняют и сцену не трогают,
  // пока не сменился кадр.

  PixelScene? _cachedScene;

  // Спрайты с анимацией (во всех слоях). Считаются один раз на список слоёв.
  List<PixelSprite>? _animatedSprites;
  List<PixelSprite> get _animated => _animatedSprites ??= [
        for (final layer in _layers)
          for (final object in layer.items)
            if (object is PixelSprite && object.animation != null) object,
      ];

  PixelScene _scene() {
    final size = sceneSize;
    // "Отпечаток" времени: имена текущих кадров анимированных спрайтов.
    // Пока он не изменился, ни один спрайт не поменял кадр.
    final frames = [for (final sprite in _animated) _currentFrame(sprite)];

    final cached = _cachedScene;
    if (cached != null &&
        identical(cached.layers, _layers) &&
        identical(cached.atlas, _atlas) &&
        cached.sceneSize == size &&
        listEquals(cached.frames, frames)) {
      return cached;
    }

    return _cachedScene = PixelScene.build(
      layers: _layers,
      atlas: _atlas,
      sceneSize: size,
      frames: frames,
      frameOf: _currentFrame,
    );
  }

  // --- Отрисовка ----------------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    final scene = sceneSize;

    // 1. Фон (под дочерним виджетом).
    _withSceneCanvas(context.canvas, offset, scene, (canvas) {
      // isAntiAlias=false: края строго по границам пикселей.
      canvas.drawRect(
        Offset.zero & scene,
        Paint()
          ..color = _background
          ..isAntiAlias = false,
      );
    });

    // 2. Дочерний виджет (если есть), на всю площадь холста.
    final child = this.child;
    if (child != null) context.paintChild(child, offset);

    // 3. Графика поверх. context.canvas берём заново: после paintChild
    // он мог смениться.
    _withSceneCanvas(context.canvas, offset, scene, (canvas) {
      // Слои снизу вверх, внутри слоя объекты по порядку списка. Всё
      // подготовлено заранее (см. PixelScene), здесь только рисование.
      final built = _scene();
      for (var l = 0; l < _layers.length; l++) {
        built.paintLayer(canvas, l);
      }

      _onPaint?.call(canvas, scene);
    });
  }

  // Готовит canvas к рисованию в координатах сцены и вызывает [draw].
  void _withSceneCanvas(
    Canvas canvas,
    Offset offset,
    Size scene,
    void Function(Canvas canvas) draw,
  ) {
    canvas.save();
    // Переходим в координаты виджета (offset это его позиция на экране).
    canvas.translate(offset.dx, offset.dy);
    // С этого момента 1 единица = scale физических пикселей.
    canvas.scale(_scale.toDouble());
    // Не даём рисовать за пределами сцены (остаток в 1 .. scale-1
    // физических пикселей по краям остаётся пустым).
    canvas.clipRect(Offset.zero & scene);
    draw(canvas);
    canvas.restore();
  }

  // Имя кадра, который сейчас нужно показать для спрайта: у неподвижного
  // это frame, у анимированного кадр анимации на текущий момент.
  String _currentFrame(PixelSprite sprite) {
    final name = sprite.animation;
    final atlas = _atlas;
    if (name == null || atlas == null) return sprite.frame;

    final animation = atlas.animation(name);
    if (animation == null) return sprite.frame; // такой анимации нет

    // Время, прошедшее со старта этого спрайта. Если старта нет в таблице
    // (так быть не должно), показываем первый кадр.
    final start = _animationStarts[sprite.id] ?? _time;
    return animation.frameAt(_time - start);
  }
}
