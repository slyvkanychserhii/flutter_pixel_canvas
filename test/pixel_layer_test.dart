import 'package:flutter_pixel_canvas/flutter_pixel_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const a = PixelLayer(id: 'a');
  const b = PixelLayer(id: 'b');
  const c = PixelLayer(id: 'c');
  final layers = [a, b, c];

  List<String> ids(List<PixelLayer> list) => [for (final l in list) l.id];

  test('movedTo переносит слой и не меняет исходный список', () {
    expect(ids(layers.movedTo('a', 2)), ['b', 'c', 'a']);
    expect(ids(layers.movedTo('c', 0)), ['c', 'a', 'b']);
    expect(ids(layers), ['a', 'b', 'c']);
  });

  test('индекс приводится к допустимому', () {
    expect(ids(layers.movedTo('a', 99)), ['b', 'c', 'a']);
    expect(ids(layers.movedTo('c', -5)), ['c', 'a', 'b']);
  });

  test('movedToFront и movedToBack', () {
    expect(ids(layers.movedToFront('a')), ['b', 'c', 'a']);
    expect(ids(layers.movedToBack('c')), ['c', 'a', 'b']);
  });

  test('неизвестный слой это ошибка', () {
    expect(() => layers.movedTo('x', 0), throwsArgumentError);
  });

  test('copyWith меняет поля, id остаётся', () {
    final hidden = a.copyWith(visible: false);
    expect(hidden.id, 'a');
    expect(hidden.visible, isFalse);
    expect(a.visible, isTrue);
  });
}
