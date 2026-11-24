import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';

/// Демонстрация 3: атлас текстур и спрайты.
///
/// Атлас загружается из ассетов при открытии экрана. Переключатель меняет
/// порядок красного и жёлтого квадратов в списке: тот, что в списке позже,
/// лежит сверху. Белая линия это примитив: он всегда поверх спрайтов.
class SpritesDemo extends StatefulWidget {
  const SpritesDemo({super.key});

  @override
  State<SpritesDemo> createState() => _SpritesDemoState();
}

class _SpritesDemoState extends State<SpritesDemo> {
  static const _minScale = 1;
  static const _maxScale = 16;

  PixelAtlas? _atlas; // null, пока грузится или если была ошибка
  Object? _error;
  int _scale = 6;
  bool _yellowOnTop = true;

  @override
  void initState() {
    super.initState();
    _loadAtlas();
  }

  Future<void> _loadAtlas() async {
    try {
      final atlas = await PixelAtlas.load(rootBundle, 'assets/atlas.json');
      // Пока грузили, экран могли закрыть: тогда сразу освобождаем атлас.
      if (!mounted) {
        atlas.dispose();
        return;
      }
      setState(() => _atlas = atlas);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    // Атлас принадлежит этому экрану, поэтому освобождаем его здесь.
    _atlas?.dispose();
    super.dispose();
  }

  void _changeScale(int delta) {
    setState(() {
      _scale = (_scale + delta).clamp(_minScale, _maxScale);
    });
  }

  List<PixelSprite> _buildSprites() {
    const red = PixelSprite(frame: 'red', x: 4, y: 4);
    const yellow = PixelSprite(frame: 'yellow', x: 12, y: 10);
    return [
      // Порядок в списке = порядок наложения (последний сверху).
      if (_yellowOnTop) ...[red, yellow] else ...[yellow, red],
      const PixelSprite(frame: 'blue', x: 24, y: 4),
      const PixelSprite(frame: 'green', x: 30, y: 10),

      // Кадры разного размера.
      const PixelSprite(frame: 'heart', x: 4, y: 30),
      const PixelSprite(frame: 'heart', x: 16, y: 30),
      const PixelSprite(frame: 'heart', x: 28, y: 30),
      const PixelSprite(frame: 'smiley', x: 4, y: 42),

      // Кадра с таким именем нет: спрайт молча пропускается.
      const PixelSprite(frame: 'нет такого', x: 20, y: 42),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Атлас и спрайты')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Не удалось загрузить атлас:\n$error'),
      );
    }
    final atlas = _atlas;
    if (atlas == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
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
        ),
        SwitchListTile(
          title: const Text('Жёлтый выше красного'),
          value: _yellowOnTop,
          onChanged: (value) => setState(() => _yellowOnTop = value),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: PixelCanvas(
              scale: _scale,
              background: const Color(0xFF202030),
              atlas: atlas,
              layers: [
                PixelLayer(
                  id: 'main',
                  items: [
                    ..._buildSprites(),
                    // Линия идёт в списке последней, поэтому лежит поверх
                    // всех спрайтов.
                    const PixelLine(
                        x0: 2, y0: 24, x1: 40, y1: 8, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
