import 'package:flutter/material.dart';
import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';

import 'atlas_loader.dart';
import 'demo_layers.dart';

/// Демонстрация 5: смена порядка слоёв.
///
/// Список сверху показывает слои так, как их видит человек: верхняя строка
/// это верхний слой. Слои можно перетаскивать за ручку справа или переносить
/// кнопками «наверх» и «вниз». Кнопка с глазом прячет слой и показывает
/// его снова (порядок слоёв при этом не меняется). Состояние (порядок слоёв) хранится здесь,
/// в самом экране, а холсту каждый раз передаётся новый список.
class LayerOrderDemo extends StatefulWidget {
  const LayerOrderDemo({super.key});

  @override
  State<LayerOrderDemo> createState() => _LayerOrderDemoState();
}

class _LayerOrderDemoState extends State<LayerOrderDemo> {
  // Слои снизу вверх (как их принимает холст).
  List<PixelLayer> _layers = demoLayers;

  // id слоёв, которые спрятаны кнопкой с глазом.
  final Set<String> _hidden = {};

  // Слои для холста: порядок из _layers, видимость из _hidden.
  List<PixelLayer> get _visibleLayers => [
        for (final layer in _layers)
          layer.copyWith(visible: !_hidden.contains(layer.id)),
      ];

  void _toggleVisible(String id) {
    setState(() {
      if (!_hidden.remove(id)) _hidden.add(id);
    });
  }

  // Перетаскивание. ReorderableListView показывает слои сверху вниз, а в
  // холсте порядок обратный, поэтому разворачиваем список туда и обратно.
  void _onReorder(int oldIndex, int newIndex) {
    // onReorderItem уже присылает newIndex с учётом удаления элемента из
    // старой позиции, поправка не нужна.
    final shown = _layers.reversed.toList(); // сверху вниз
    final moved = shown.removeAt(oldIndex);
    shown.insert(newIndex, moved);

    setState(() => _layers = shown.reversed.toList());
  }

  @override
  Widget build(BuildContext context) {
    // Те же слои в порядке "сверху вниз" для показа в списке.
    final shown = _layers.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Порядок слоёв')),
      body: AtlasLoader(
        builder: (context, atlas) => Column(
          children: [
            // Три строки по 56 пикселей. Высоту задаём явно: ReorderableListView
            // внутри Column сам размер не знает.
            SizedBox(
              height: 56.0 * shown.length,
              child: ReorderableListView(
                // Ручки делаем сами (ниже), стандартные отключаем.
                buildDefaultDragHandles: false,
                onReorderItem: _onReorder,
                children: [
                  for (var i = 0; i < shown.length; i++)
                    ListTile(
                      // Ключ нужен, чтобы список понимал, какая строка куда
                      // переехала.
                      key: ValueKey(shown[i].id),
                      title: Text('Слой ${shown[i].id}'),
                      subtitle: Text(
                        i == 0
                            ? 'самый верхний'
                            : i == shown.length - 1
                                ? 'самый нижний'
                                : 'посередине',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Глаз: спрятать слой или показать снова.
                          IconButton(
                            tooltip: _hidden.contains(shown[i].id)
                                ? 'Показать'
                                : 'Спрятать',
                            icon: Icon(
                              _hidden.contains(shown[i].id)
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => _toggleVisible(shown[i].id),
                          ),
                          IconButton(
                            tooltip: 'Наверх',
                            icon: const Icon(Icons.vertical_align_top),
                            onPressed: i == 0
                                ? null
                                : () => setState(() => _layers =
                                    _layers.movedToFront(shown[i].id)),
                          ),
                          IconButton(
                            tooltip: 'Вниз',
                            icon: const Icon(Icons.vertical_align_bottom),
                            onPressed: i == shown.length - 1
                                ? null
                                : () => setState(() => _layers =
                                    _layers.movedToBack(shown[i].id)),
                          ),
                          ReorderableDragStartListener(
                            index: i,
                            child: const Icon(Icons.drag_handle),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: PixelCanvas(
                  scale: 8,
                  background: const Color(0xFF202030),
                  atlas: atlas,
                  layers: _visibleLayers,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
