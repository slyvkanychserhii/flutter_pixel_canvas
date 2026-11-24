import 'package:flutter/material.dart';
import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';

import 'atlas_loader.dart';
import 'demo_layers.dart';

/// Демонстрация 4: слои.
///
/// Три слоя A (нижний), B и C (верхний). В каждом есть спрайты и примитивы,
/// и фигуры соседних слоёв перекрывают друг друга. Переключатели включают
/// и выключают слои: так видно, что именно лежит в каждом слое и что
/// верхний слой перекрывает нижний независимо от того, спрайт это или
/// примитив.
class LayersDemo extends StatefulWidget {
  const LayersDemo({super.key});

  @override
  State<LayersDemo> createState() => _LayersDemoState();
}

class _LayersDemoState extends State<LayersDemo> {
  // id скрытых слоёв.
  final Set<String> _hidden = {};

  // Слои снизу вверх; visible берём из переключателей.
  List<PixelLayer> _buildLayers() {
    return [
      for (final layer in demoLayers)
        layer.copyWith(visible: !_hidden.contains(layer.id)),
    ];
  }

  void _toggle(String id, bool visible) {
    setState(() {
      if (visible) {
        _hidden.remove(id);
      } else {
        _hidden.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Слои')),
      body: AtlasLoader(
        builder: (context, atlas) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final id in const ['A', 'B', 'C'])
                    FilterChip(
                      label: Text('Слой $id'),
                      selected: !_hidden.contains(id),
                      onSelected: (selected) => _toggle(id, selected),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: PixelCanvas(
                  scale: 8,
                  background: const Color(0xFF202030),
                  atlas: atlas,
                  layers: _buildLayers(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
