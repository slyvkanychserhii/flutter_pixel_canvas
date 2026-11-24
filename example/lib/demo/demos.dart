import 'package:flutter/widgets.dart';

import 'align_demo.dart';
import 'animation_demo.dart';
import 'canvas_scale_demo.dart';
import 'child_demo.dart';
import 'hit_test_demo.dart';
import 'layer_order_demo.dart';
import 'layers_demo.dart';
import 'markup_text_demo.dart';
import 'pixel_hit_demo.dart';
import 'primitives_demo.dart';
import 'sprite_props_demo.dart';
import 'sprites_demo.dart';
import 'stress_demo.dart';
import 'text_demo.dart';

/// Одна запись списка демонстраций.
class DemoEntry {
  const DemoEntry({
    required this.title,
    required this.description,
    required this.builder,
  });

  /// Название пункта на главном экране.
  final String title;

  /// Короткое пояснение, что именно показывает экран.
  final String description;

  /// Создаёт экран демонстрации.
  final WidgetBuilder builder;
}

/// Все демонстрации в порядке добавления фич.
///
/// Новая фича = новый файл *_demo.dart + одна запись в этом списке.
final List<DemoEntry> demos = [
  DemoEntry(
    title: '1. Холст и масштаб',
    description: 'Холст занимает всё место родителя; множитель масштаба.',
    builder: (_) => const CanvasScaleDemo(),
  ),
  DemoEntry(
    title: '2. Примитивы',
    description: 'Точка, линия, прямоугольник и окружность; контур и заливка.',
    builder: (_) => const PrimitivesDemo(),
  ),
  DemoEntry(
    title: '3. Атлас и спрайты',
    description: 'Кадры из PNG + JSON; порядок наложения спрайтов.',
    builder: (_) => const SpritesDemo(),
  ),
  DemoEntry(
    title: '4. Слои',
    description: 'Верхний слой перекрывает нижние; включение слоёв.',
    builder: (_) => const LayersDemo(),
  ),
  DemoEntry(
    title: '5. Порядок слоёв',
    description: 'Перетаскивание слоёв и перенос наверх или вниз.',
    builder: (_) => const LayerOrderDemo(),
  ),
  DemoEntry(
    title: '6. Нажатия',
    description: 'Какая графика и в каком слое нажата.',
    builder: (_) => const HitTestDemo(),
  ),
  DemoEntry(
    title: '7. Текст из атласа',
    description: 'Растровый шрифт: русские и латинские буквы, цвет, перенос строк.',
    builder: (_) => const TextDemo(),
  ),
  DemoEntry(
    title: '8. Анимация',
    description: 'Кадры анимации из атласа: цикл, однократная, перезапуск.',
    builder: (_) => const AnimationDemo(),
  ),
  DemoEntry(
    title: '9. Холст с дочерним виджетом',
    description: 'Графика поверх обычных виджетов; режимы нажатий.',
    builder: (_) => const ChildDemo(),
  ),
  DemoEntry(
    title: '10. Выравнивание',
    description: 'Привязка к краям холста и к другим объектам, цепочки.',
    builder: (_) => const AlignDemo(),
  ),
  DemoEntry(
    title: '11. Нагрузка',
    description: 'Тысячи объектов и счётчик FPS: проверка кэша сцены.',
    builder: (_) => const StressDemo(),
  ),
  DemoEntry(
    title: '12. Нажатия по пикселям',
    description: 'Прозрачные части спрайтов пропускают нажатие; текущий кадр анимации.',
    builder: (_) => const PixelHitDemo(),
  ),
  DemoEntry(
    title: '13. Свойства спрайта',
    description: 'Поворот, отражение, zoom, прозрачность и подкраска.',
    builder: (_) => const SpritePropsDemo(),
  ),
  DemoEntry(
    title: '14. Цветной текст',
    description: 'Теги <color=…> меняют цвет кусков текста внутри одной строки.',
    builder: (_) => const MarkupTextDemo(),
  ),
];
