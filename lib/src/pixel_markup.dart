import 'dart:ui' show Color;

/// Результат разбора текста с тегами цвета: чистый текст и цвет каждого
/// символа.
class PixelMarkup {
  const PixelMarkup({required this.text, required this.colors});

  /// Текст без тегов.
  final String text;

  /// Цвет каждого символа ([text].runes по порядку). null значит «цвет по
  /// умолчанию», то есть цвет всего текста.
  final List<Color?> colors;
}

// Имена цветов, которые можно писать в теге вместо шестнадцатеричного кода.
const Map<String, Color> _namedColors = {
  'white': Color(0xFFFFFFFF),
  'black': Color(0xFF000000),
  'red': Color(0xFFE53935),
  'green': Color(0xFF43A047),
  'blue': Color(0xFF1E88E5),
  'yellow': Color(0xFFFDD835),
  'orange': Color(0xFFFB8C00),
  'gray': Color(0xFF9E9E9E),
};

/// Разбирает значение цвета из тега: имя (`red`), `#RGB`, `#RRGGBB` или
/// `#AARRGGBB`. Возвращает null, если значение непонятное.
Color? parsePixelColor(String value) {
  final v = value.trim().toLowerCase();
  final named = _namedColors[v];
  if (named != null) return named;
  if (!v.startsWith('#')) return null;
  var hex = v.substring(1);
  if (hex.length == 3) {
    // #RGB превращается в #RRGGBB: каждая цифра удваивается.
    hex = hex.split('').map((c) => '$c$c').join();
  }
  if (hex.length != 6 && hex.length != 8) return null;
  final n = int.tryParse(hex, radix: 16);
  if (n == null) return null;
  return Color(hex.length == 6 ? 0xFF000000 | n : n);
}

/// Разбирает текст с тегами `<color=#RRGGBB>…</color>`.
///
/// Правила:
/// * теги можно вкладывать: после закрытия внутреннего возвращается цвет
///   внешнего;
/// * `<<` даёт обычный символ `<`;
/// * непонятный тег (неизвестное имя цвета, нет `>`, лишний `</color>`)
///   остаётся в тексте как есть, ничего не ломая;
/// * незакрытый тег действует до конца текста.
///
/// Функция чистая: ничего не рисует и не хранит.
PixelMarkup parsePixelMarkup(String source) {
  final out = StringBuffer();
  final colors = <Color?>[];
  final stack = <Color>[]; // открытые теги, последний действует сейчас

  // Добавляет один символ с текущим цветом.
  void emit(int rune) {
    out.writeCharCode(rune);
    colors.add(stack.isEmpty ? null : stack.last);
  }

  final runes = source.runes.toList();
  var i = 0;
  while (i < runes.length) {
    final ch = runes[i];
    if (ch != 0x3C) {
      // Обычный символ.
      emit(ch);
      i++;
      continue;
    }
    // '<<' это один символ '<'.
    if (i + 1 < runes.length && runes[i + 1] == 0x3C) {
      emit(0x3C);
      i += 2;
      continue;
    }
    // Ищем закрывающую '>' и берём содержимое тега.
    final close = runes.indexOf(0x3E, i + 1);
    final tag = close < 0 ? null : String.fromCharCodes(runes.sublist(i + 1, close));
    if (tag != null && tag.startsWith('color=')) {
      final color = parsePixelColor(tag.substring(6));
      if (color != null) {
        stack.add(color);
        i = close + 1;
        continue;
      }
    } else if (tag == '/color' && stack.isNotEmpty) {
      stack.removeLast();
      i = close + 1;
      continue;
    }
    // Не наш тег: '<' остаётся обычным символом.
    emit(ch);
    i++;
  }
  return PixelMarkup(text: out.toString(), colors: colors);
}
