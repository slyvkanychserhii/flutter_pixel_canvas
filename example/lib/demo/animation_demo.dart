import 'package:flutter/material.dart';
import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';

import 'atlas_loader.dart';

/// Демонстрация 8: анимация по кадрам из атласа.
///
/// * Красный квадрат крутит зацикленную анимацию "cycle" (переключатель
///   включает и выключает её: без анимации показывается обычный кадр).
/// * Смайлик моргает один раз при появлении; нажмите на него, чтобы
///   моргнул снова.
/// * Цифра отсчитывает 3, 2, 1, 0 и замирает на последнем кадре. Кадрами
///   анимации служат глифы шрифта. Нажмите на цифру, чтобы начать заново.
/// * Сердце просит анимацию, которой нет в атласе, и просто стоит.
///
/// Когда все анимации доиграли, а зацикленной нет, холст перестаёт
/// перерисовываться сам.
class AnimationDemo extends StatefulWidget {
  const AnimationDemo({super.key});

  @override
  State<AnimationDemo> createState() => _AnimationDemoState();
}

class _AnimationDemoState extends State<AnimationDemo> {
  static const _minScale = 1;
  static const _maxScale = 12;

  int _scale = 4;
  bool _cycling = true;

  // Номера запусков: увеличили число, анимация стартует заново.
  int _blinkRun = 0;
  int _countRun = 0;

  void _changeScale(int delta) {
    setState(() {
      _scale = (_scale + delta).clamp(_minScale, _maxScale);
    });
  }

  // Нажатие: если попали в смайлик или цифру, перезапускаем их анимацию.
  void _onTap(PixelTap tap) {
    switch (tap.hit?.id) {
      case 'blink':
        setState(() => _blinkRun++);
      case 'count':
        setState(() => _countRun++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Анимация')),
      body: AtlasLoader(
        builder: (context, atlas) => Column(
          children: [
            SwitchListTile(
              title: const Text('Цикл играет'),
              value: _cycling,
              onChanged: (value) => setState(() => _cycling = value),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _scale > _minScale ? () => _changeScale(-1) : null,
                ),
                Text('Масштаб x$_scale'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _scale < _maxScale ? () => _changeScale(1) : null,
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: PixelCanvas(
                  scale: _scale,
                  background: const Color(0xFF202030),
                  atlas: atlas,
                  onTap: _onTap,
                  layers: [
                    PixelLayer(
                      id: 'anim',
                      items: [
                        PixelSprite(
                          id: 'loop',
                          frame: 'red', // кадр, когда анимация выключена
                          x: 2,
                          y: 16,
                          animation: _cycling ? 'cycle' : null,
                        ),
                        PixelSprite(
                          id: 'blink',
                          frame: 'smiley',
                          // Правая колонка: align прижимает объект к
                          // правому краю, x: -2 даёт отступ в 2 пикселя.
                          align: Alignment.topRight,
                          x: -2,
                          y: 16,
                          animation: 'blink',
                          animationRun: _blinkRun,
                        ),
                        PixelSprite(
                          id: 'count',
                          frame: 'main_0033',
                          x: 2,
                          y: 50,
                          animation: 'count',
                          animationRun: _countRun,
                        ),
                        const PixelSprite(
                          id: 'unknown',
                          frame: 'heart',
                          align: Alignment.topRight,
                          x: -2,
                          y: 50,
                          animation: 'нет такой',
                        ),
                        const PixelText(text: 'Цикл', font: 'main', x: 2, y: 2),
                        const PixelText(
                          text: 'Нажми',
                          font: 'main',
                          align: Alignment.topRight,
                          x: -2,
                          y: 2,
                        ),
                        const PixelText(
                            text: 'Отсчёт', font: 'main', x: 2, y: 36),
                        const PixelText(
                          text: 'Нет',
                          font: 'main',
                          align: Alignment.topRight,
                          x: -2,
                          y: 36,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
