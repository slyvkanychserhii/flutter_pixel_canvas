import 'pixel_objects.dart';

/// Слой: упорядоченный набор объектов (спрайтов, текстов, примитивов),
/// который рисуется как одно целое.
///
/// Слои рисуются по порядку списка [PixelCanvas.layers]: первый внизу,
/// последний сверху. Всё, что нарисовано в верхнем слое, перекрывает
/// содержимое нижних слоёв.
///
/// Внутри слоя объекты рисуются по порядку списка [items]: первый внизу,
/// последний сверху. Типы можно смешивать как угодно: например, спрайт,
/// поверх него линия, а поверх линии ещё один спрайт.
///
/// Класс неизменяемый. Чтобы что-то изменить, соберите новый список слоёв
/// и передайте его холсту.
class PixelLayer {
  const PixelLayer({
    required this.id,
    this.items = const [],
    this.visible = true,
  });

  /// Название слоя. Не используется при рисовании, но по нему слой можно
  /// узнать при обработке нажатий и при перестановке слоёв.
  final String id;

  /// Объекты слоя от нижнего к верхнему.
  final List<PixelObject> items;

  /// Невидимый слой не рисуется и не реагирует на нажатия.
  final bool visible;

  /// Копия слоя с изменёнными полями. id менять нельзя: это идентичность слоя.
  PixelLayer copyWith({List<PixelObject>? items, bool? visible}) {
    return PixelLayer(
      id: id,
      items: items ?? this.items,
      visible: visible ?? this.visible,
    );
  }
}

/// Перестановка слоёв в списке.
///
/// Порядок слоёв это просто порядок в списке: первый внизу, последний сверху.
/// Методы ничего не меняют на месте, а возвращают новый список: его и нужно
/// передать холсту.
extension PixelLayerOrder on List<PixelLayer> {
  /// Переносит слой [id] на позицию [index] (0 = самый нижний,
  /// length - 1 = самый верхний). Слишком большой или маленький индекс
  /// приводится к допустимому. Бросает [ArgumentError], если слоя нет.
  List<PixelLayer> movedTo(String id, int index) {
    final from = indexWhere((layer) => layer.id == id);
    if (from < 0) throw ArgumentError('Слой "$id" не найден');

    final result = [...this];
    final layer = result.removeAt(from);
    // После удаления в списке на один элемент меньше, это учитываем.
    result.insert(index.clamp(0, result.length), layer);
    return result;
  }

  /// Переносит слой на самый верх.
  List<PixelLayer> movedToFront(String id) => movedTo(id, length - 1);

  /// Переносит слой в самый низ.
  List<PixelLayer> movedToBack(String id) => movedTo(id, 0);
}
