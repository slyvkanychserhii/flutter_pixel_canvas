import 'package:flutter/painting.dart';

/// Что считается попаданием при нажатии на спрайт или текст.
enum PixelHitArea {
  /// Весь прямоугольник: кадр спрайта или прямоугольник текста, вместе с
  /// прозрачными пикселями. Нажать легко, даже на тонкие буквы.
  bounds,

  /// Только непрозрачные пиксели (alpha не меньше половины). Нажатие на
  /// прозрачный угол кадра или на просвет между буквами пролетает
  /// насквозь к объектам ниже.
  pixels,
}

/// Любой объект, который можно положить в слой ([PixelLayer.items]):
/// спрайт, текст или примитив.
///
/// Это sealed-класс: у него ровно три ветки ([PixelSprite], [PixelText] и
/// [PixelPrimitive], а у примитива свои четыре фигуры). Благодаря этому switch
/// по объекту компилятор проверяет на полноту: добавили новый вид объекта, и
/// он покажет все места, где его забыли обработать.
///
/// Все они лежат в одном файле, потому что sealed-класс разрешает наследников
/// только в своей библиотеке (файле).
///
/// Объекты неизменяемые: у всех полей final, конструкторы const.
sealed class PixelObject {
  const PixelObject({this.id});

  /// Необязательный идентификатор. По нему приложение узнаёт, на какой именно
  /// объект нажали ([PixelHit.id]). У разных объектов id лучше делать
  /// разными.
  final String? id;
}

/// Спрайт: кадр атласа, поставленный в точку сцены.
///
/// [frame] это имя кадра в атласе ([PixelAtlas.frame]). Если кадра с таким
/// именем в атласе нет, спрайт просто не рисуется.
///
/// Положение задаётся тремя вещами: точкой на спрайте [align], точкой на
/// опоре [anchorAlign] и смещением (x, y). Подробно, с формулой и
/// примерами, в описании функции `layoutScene` (pixel_layout.dart). В простейшем
/// случае (по умолчанию) (x, y) это левый верхний угол спрайта в пикселях
/// сцены.
///
/// Анимация. Если задано [animation] (имя из секции "animations" атласа),
/// спрайт сам меняет кадры: вместо [frame] рисуется текущий кадр анимации.
/// Холст запускает анимацию, когда спрайт с таким [id] и таким [animation]
/// впервые появляется на холсте. Нужно проиграть её заново: увеличьте
/// [animationRun]. Закончившаяся анимация без зацикливания остаётся на
/// последнем кадре. Если такой анимации в атласе нет, рисуется [frame].
/// У анимированного спрайта обязательно должен быть [id].
///
/// Кадры одной анимации лучше делать одного размера: положение отсчитывается
/// от левого верхнего угла кадра.
final class PixelSprite extends PixelObject {
  const PixelSprite({
    required this.frame,
    this.x = 0,
    this.y = 0,
    this.align = Alignment.topLeft,
    this.anchorAlign,
    this.anchor,
    super.id,
    this.animation,
    this.animationRun = 0,
    this.hitArea = PixelHitArea.pixels,
    this.quarterTurns = 0,
    this.flipX = false,
    this.flipY = false,
    this.zoom = 1,
    this.opacity = 1,
    this.tint = const Color(0xFFFFFFFF),
  })  : assert(
          animation == null || id != null,
          'у анимированного спрайта должен быть id',
        ),
        assert(zoom >= 1, 'zoom должен быть не меньше 1'),
        assert(opacity >= 0 && opacity <= 1, 'opacity от 0 до 1');

  final String frame;

  /// Смещение от точки привязки в пикселях сцены.
  final int x;
  final int y;

  /// Точка на самом спрайте, которой он крепится (см. `layoutScene`).
  final Alignment align;

  /// Точка на опоре (холсте или другом объекте), к которой крепится спрайт.
  /// Если null, берётся та же, что [align].
  final Alignment? anchorAlign;

  /// id объекта (спрайта или текста), относительно которого размещается
  /// спрайт. null = относительно всего холста.
  final String? anchor;

  /// Имя анимации в атласе или null (спрайт неподвижен).
  final String? animation;

  /// Номер запуска. Изменили число: анимация стартует заново.
  final int animationRun;

  /// Что считается попаданием при нажатии: весь прямоугольник кадра или
  /// только непрозрачные пиксели (по умолчанию). У анимированного спрайта
  /// проверяется кадр, который показан в момент нажатия.
  final PixelHitArea hitArea;

  // --- Преобразования -----------------------------------------------------
  //
  // Порядок: кадр отражается (flipX, flipY), потом поворачивается, потом
  // увеличивается (zoom). Все преобразования целочисленные: пиксели
  // остаются ровными квадратами, без размытия и "лесенки" от произвольного
  // угла. Размер спрайта для выравнивания и нажатий это размер после
  // поворота и увеличения.

  /// Поворот по часовой стрелке на столько четвертей оборота (90 градусов):
  /// 0, 1, 2, 3 (другие числа считаются по модулю 4, отрицательные
  /// вращают против часовой). Произвольные углы не поддерживаются
  /// намеренно: пиксельная графика при них теряет чёткость.
  final int quarterTurns;

  /// Зеркально по горизонтали / по вертикали (относительно самого кадра,
  /// до поворота).
  final bool flipX;
  final bool flipY;

  /// Целое увеличение спрайта: 1 (как есть), 2 (каждый пиксель кадра
  /// занимает 2x2 пикселя сцены) и так далее. Не путать с масштабом холста
  /// [PixelCanvas.scale]: он увеличивает всю сцену, а это только один спрайт.
  final int zoom;

  /// Непрозрачность от 0 (невидим) до 1 (как есть). Невидимый (0) спрайт
  /// всё равно принимает нажатия: спрячьте его слоем, если нужно иначе.
  final double opacity;

  /// Подкраска: цвет кадра умножается на этот цвет (белый ничего не
  /// меняет). Альфа-канал подкраски тоже работает как прозрачность.
  final Color tint;
}

/// Текст, нарисованный растровым шрифтом из атласа.
///
/// Положение задаётся так же, как у спрайта (см. `layoutScene` в
/// pixel_layout.dart): точка на тексте [align], точка на опоре [anchorAlign],
/// смещение (x, y). Размером текста считается прямоугольник, в который
/// помещаются все его строки. Символ '\n' переносит строку. Символ, которого нет в шрифте, заменяется на '?'
/// (если он есть в шрифте), иначе пропускается. Если шрифта с именем [font]
/// нет в атласе, текст не рисуется (как и спрайт с неизвестным кадром).
///
/// Глифы в атласе белые, а [color] подкрашивает их при рисовании: цвет
/// умножается на цвет глифа.
final class PixelText extends PixelObject {
  const PixelText({
    required this.text,
    required this.font,
    this.x = 0,
    this.y = 0,
    this.align = Alignment.topLeft,
    this.anchorAlign,
    this.anchor,
    this.color = const Color(0xFFFFFFFF),
    this.markup = false,
    this.hitArea = PixelHitArea.bounds,
    super.id,
  });

  final String text;

  /// Имя шрифта в секции "fonts" атласа.
  final String font;

  /// Смещение от точки привязки в пикселях сцены.
  final int x;
  final int y;

  /// Точка на самом тексте, которой он крепится (см. `layoutScene`).
  final Alignment align;

  /// Точка на опоре, к которой крепится текст. Если null, та же, что [align].
  final Alignment? anchorAlign;

  /// id объекта (спрайта или текста), относительно которого размещается
  /// текст. null = относительно всего холста.
  final String? anchor;

  final Color color;

  /// Включает теги цвета в тексте: `<color=#RRGGBB>красный</color>`.
  /// Можно писать `#RGB`, `#RRGGBB`, `#AARRGGBB` или имя (red, green, blue,
  /// yellow, orange, white, black, gray). Теги вкладываются, `<<` даёт
  /// символ `<`. Без тега буквы рисуются цветом [color]. По умолчанию
  /// выключено, поэтому обычный текст с `<` не меняется.
  final bool markup;

  /// Что считается попаданием: весь прямоугольник текста (по умолчанию:
  /// попасть в тонкие буквы пальцем трудно) или только пиксели самих букв.
  final PixelHitArea hitArea;
}

/// Примитив: простая фигура одного цвета.
///
/// Это sealed-класс: у него ровно четыре наследника (точка, линия,
/// прямоугольник, окружность).
///
/// Все координаты целые и заданы в пикселях сцены (от левого верхнего угла
/// холста). Прозрачность задаётся в цвете (альфа-канал).
sealed class PixelPrimitive extends PixelObject {
  const PixelPrimitive({required this.color, super.id});

  final Color color;
}

/// Один пиксель.
final class PixelPoint extends PixelPrimitive {
  const PixelPoint({
    required this.x,
    required this.y,
    required super.color,
    super.id,
  });

  final int x;
  final int y;
}

/// Линия толщиной в один пиксель от (x0, y0) до (x1, y1), оба конца включены.
final class PixelLine extends PixelPrimitive {
  const PixelLine({
    required this.x0,
    required this.y0,
    required this.x1,
    required this.y1,
    required super.color,
    super.id,
  });

  final int x0;
  final int y0;
  final int x1;
  final int y1;
}

/// Прямоугольник: закрашенный или только контур толщиной в один пиксель.
/// (x, y) это левый верхний пиксель, [width] и [height] в пикселях:
/// ширина 10 значит ровно 10 пикселей.
final class PixelRect extends PixelPrimitive {
  const PixelRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required super.color,
    super.id,
    this.filled = true,
  });

  final int x;
  final int y;
  final int width;
  final int height;
  final bool filled;
}

/// Окружность или круг с центром в пикселе (cx, cy) и радиусом [radius]
/// в пикселях (диаметр = 2 * radius + 1 пиксель).
final class PixelCircle extends PixelPrimitive {
  const PixelCircle({
    required this.cx,
    required this.cy,
    required this.radius,
    required super.color,
    super.id,
    this.filled = true,
  });

  final int cx;
  final int cy;
  final int radius;
  final bool filled;
}
