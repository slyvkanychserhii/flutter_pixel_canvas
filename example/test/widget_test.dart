import 'package:flutter_pixel_canvas_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

// Проверка, что пример запускается и показывает список экранов.
void main() {
  testWidgets('главный экран показывает список демонстраций', (tester) async {
    await tester.pumpWidget(const PixelDemoApp());

    expect(find.text('Pixel Canvas: демонстрации'), findsOneWidget);
    expect(find.text('1. Холст и масштаб'), findsOneWidget);
  });
}
