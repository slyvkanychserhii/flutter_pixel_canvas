import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Анимация: последовательность кадров атласа.
///
/// Описывается в секции "animations" JSON атласа:
///
///     "animations": {
///       "cycle": {"frames": ["red", "green"], "fps": 4, "loop": true}
///     }
///
/// "fps" это число кадров в секунду (может быть дробным), "loop" говорит,
/// повторять ли анимацию (по умолчанию false).
class PixelAnimation {
  const PixelAnimation({
    required this.frames,
    required this.fps,
    required this.loop,
  });

  /// Имена кадров по порядку.
  final List<String> frames;
  final double fps;
  final bool loop;

  /// Длительность одного прохода по всем кадрам.
  Duration get duration => Duration(
        microseconds: (frames.length * Duration.microsecondsPerSecond / fps)
            .round(),
      );

  /// Закончилась ли анимация через время [elapsed] после старта.
  /// Зацикленная не заканчивается никогда.
  bool isFinished(Duration elapsed) => !loop && elapsed >= duration;

  /// Имя кадра, который нужно показывать через [elapsed] после старта.
  String frameAt(Duration elapsed) {
    if (elapsed.isNegative) return frames.first;
    // Сколько кадров сменилось с начала: время в секундах * кадров в секунду.
    final passed =
        (elapsed.inMicroseconds * fps / Duration.microsecondsPerSecond).floor();
    // Зацикленная идёт по кругу, обычная замирает на последнем кадре.
    final index = loop ? passed % frames.length : math.min(passed, frames.length - 1);
    return frames[index];
  }
}

/// Растровый шрифт: какой кадр атласа соответствует какому символу.
///
/// Описывается в секции "fonts" JSON атласа:
///
///     "fonts": {
///       "main": {
///         "lineHeight": 13,
///         "spacing": 0,
///         "glyphs": {"A": "main_0041", "Б": "main_0411"}
///       }
///     }
///
/// "glyphs" это символ -> имя кадра, "lineHeight" высота строки в пикселях
/// (на столько опускается текст после перевода строки), "spacing" зазор
/// между соседними символами (может быть 0 или отрицательным).
class PixelFont {
  const PixelFont({
    required this.glyphs,
    required this.lineHeight,
    required this.spacing,
  });

  /// Код символа (руна) -> имя кадра в атласе.
  final Map<int, String> glyphs;

  final int lineHeight;
  final int spacing;
}

/// Порог непрозрачности (0..255), с которого пиксель спрайта принимает
/// нажатие в режиме `PixelHitArea.pixels`: половина.
const int hitAlphaThreshold = 128;

/// Атлас текстур: одна картинка, в которой лежит много маленьких кадров,
/// и описание, где какой кадр находится.
///
/// Файл описания (JSON) выглядит так:
///
///     {
///       "image": "atlas.png",
///       "frames": {
///         "red":   {"x": 1,  "y": 1, "w": 16, "h": 16},
///         "heart": {"x": 69, "y": 1, "w": 9,  "h": 8}
///       },
///       "animations": { ... },
///       "fonts": { ... }
///     }
///
/// "image" это имя PNG рядом с JSON, "frames" это кадры: имя -> прямоугольник
/// (x, y левый верхний угол, w и h размер, всё в пикселях картинки).
/// Секции "animations" и "fonts" необязательны, см. [PixelAnimation]
/// и [PixelFont].
///
/// Создаётся только через [PixelAtlas.load]. Атлас владеет картинкой, поэтому
/// когда он больше не нужен, вызовите [dispose].
class PixelAtlas {
  PixelAtlas._(
    this.image,
    this._alpha,
    this._frames,
    this._animations,
    this._fonts,
  );

  /// Картинка атласа целиком. Её рисует холст, вырезая нужные кадры.
  final ui.Image image;

  // Прозрачность каждого пикселя картинки (0..255), по строкам. Копия
  // канала alpha, снятая при загрузке: читать пиксели из ui.Image на лету
  // нельзя (это асинхронно), а для проверки нажатий они нужны сразу.
  final Uint8List _alpha;

  final Map<String, Rect> _frames;
  final Map<String, PixelAnimation> _animations;
  final Map<String, PixelFont> _fonts;

  /// Непрозрачность пикселя (x, y) картинки атласа: 0 (прозрачный) ..
  /// 255 (непрозрачный). За границами картинки 0.
  int alphaAt(int x, int y) {
    if (x < 0 || y < 0 || x >= image.width || y >= image.height) return 0;
    return _alpha[y * image.width + x];
  }

  /// Считается ли пиксель (x, y) картинки атласа "твёрдым" для нажатий:
  /// его непрозрачность не меньше [hitAlphaThreshold].
  bool isSolid(int x, int y) => alphaAt(x, y) >= hitAlphaThreshold;

  /// Прямоугольник кадра в картинке атласа или null, если такого кадра нет.
  Rect? frame(String name) => _frames[name];

  /// Анимация по имени или null, если такой анимации нет.
  PixelAnimation? animation(String name) => _animations[name];

  /// Шрифт по имени или null, если такого шрифта в атласе нет.
  PixelFont? font(String name) => _fonts[name];

  /// Имена всех кадров.
  Iterable<String> get frameNames => _frames.keys;

  /// Освобождает память, занятую картинкой. После этого атлас использовать
  /// нельзя.
  void dispose() => image.dispose();

  /// Загружает атлас из ассетов.
  ///
  /// [jsonPath] путь к JSON в ассетах, например 'assets/atlas.json'.
  /// PNG ищется в той же папке. Оба файла должны быть перечислены
  /// в pubspec.yaml.
  ///
  /// Бросает [FormatException] с понятным сообщением, если описание
  /// составлено неверно (нет поля, кадр выходит за картинку и т.д.).
  static Future<PixelAtlas> load(AssetBundle bundle, String jsonPath) async {
    // --- 1. Читаем и разбираем JSON ---
    final Object? root = jsonDecode(await bundle.loadString(jsonPath));
    if (root is! Map<String, dynamic>) {
      throw FormatException('$jsonPath: ожидался JSON-объект {...}');
    }

    final imageName = root['image'];
    if (imageName is! String) {
      throw FormatException('$jsonPath: нет строкового поля "image"');
    }

    final framesJson = root['frames'];
    if (framesJson is! Map<String, dynamic>) {
      throw FormatException('$jsonPath: нет объекта "frames"');
    }

    // --- 2. Загружаем PNG из той же папки, что и JSON ---
    // 'assets/atlas.json' -> 'assets/'. Если слэша нет, папка пустая.
    final dir = jsonPath.substring(0, jsonPath.lastIndexOf('/') + 1);
    final bytes = (await bundle.load('$dir$imageName')).buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(bytes);
    final ui.Image image;
    try {
      image = (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }

    // --- 3. Проверяем кадры. Если что-то не так, освобождаем картинку ---
    try {
      // Запоминаем канал alpha всех пикселей (для нажатий по пикселям).
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) {
        throw FormatException('$jsonPath: не удалось прочитать пиксели PNG');
      }
      final alpha = Uint8List(image.width * image.height);
      for (var i = 0; i < alpha.length; i++) {
        alpha[i] = data.getUint8(i * 4 + 3); // порядок байт R, G, B, A
      }

      final frames = <String, Rect>{};
      for (final entry in framesJson.entries) {
        final name = entry.key;
        final data = entry.value;
        if (data is! Map<String, dynamic>) {
          throw FormatException('$jsonPath: кадр "$name" должен быть объектом');
        }

        final x = _intField(jsonPath, name, data, 'x');
        final y = _intField(jsonPath, name, data, 'y');
        final w = _intField(jsonPath, name, data, 'w');
        final h = _intField(jsonPath, name, data, 'h');

        if (w <= 0 || h <= 0) {
          throw FormatException('$jsonPath: кадр "$name": w и h должны быть > 0');
        }
        if (x < 0 || y < 0 || x + w > image.width || y + h > image.height) {
          throw FormatException(
            '$jsonPath: кадр "$name" выходит за границы картинки '
            '${image.width}x${image.height}',
          );
        }

        frames[name] = Rect.fromLTWH(
          x.toDouble(),
          y.toDouble(),
          w.toDouble(),
          h.toDouble(),
        );
      }
      final animations = _parseAnimations(jsonPath, root['animations'], frames);
      final fonts = _parseFonts(jsonPath, root['fonts'], frames);
      return PixelAtlas._(image, alpha, frames, animations, fonts);
    } catch (_) {
      image.dispose();
      rethrow;
    }
  }
}

// Достаёт из описания кадра целое число или бросает понятную ошибку.
int _intField(String file, String frame, Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! int) {
    throw FormatException('$file: у кадра "$frame" нет целого поля "$key"');
  }
  return value;
}

// Разбирает секцию "fonts" (она необязательна) и проверяет, что все кадры
// глифов существуют.
Map<String, PixelFont> _parseFonts(
  String file,
  Object? json,
  Map<String, Rect> frames,
) {
  if (json == null) return const {};
  if (json is! Map<String, dynamic>) {
    throw FormatException('$file: "fonts" должен быть объектом');
  }

  final fonts = <String, PixelFont>{};
  for (final entry in json.entries) {
    final name = entry.key;
    final data = entry.value;
    if (data is! Map<String, dynamic>) {
      throw FormatException('$file: шрифт "$name" должен быть объектом');
    }

    final lineHeight = data['lineHeight'];
    final spacing = data['spacing'] ?? 0;
    if (lineHeight is! int || lineHeight <= 0) {
      throw FormatException(
          '$file: у шрифта "$name" нет целого поля "lineHeight" > 0');
    }
    if (spacing is! int) {
      throw FormatException('$file: у шрифта "$name" "spacing" не целое');
    }

    final glyphsJson = data['glyphs'];
    if (glyphsJson is! Map<String, dynamic>) {
      throw FormatException('$file: у шрифта "$name" нет объекта "glyphs"');
    }

    final glyphs = <int, String>{};
    for (final glyph in glyphsJson.entries) {
      // Ключ должен быть ровно одним символом.
      final runes = glyph.key.runes.toList();
      if (runes.length != 1) {
        throw FormatException(
            '$file: шрифт "$name": ключ "${glyph.key}" должен быть одним символом');
      }
      final frame = glyph.value;
      if (frame is! String || !frames.containsKey(frame)) {
        throw FormatException(
            '$file: шрифт "$name": у символа "${glyph.key}" нет кадра "$frame"');
      }
      glyphs[runes.first] = frame;
    }

    fonts[name] = PixelFont(
      glyphs: glyphs,
      lineHeight: lineHeight,
      spacing: spacing,
    );
  }
  return fonts;
}

// Разбирает секцию "animations" (она необязательна) и проверяет, что все
// кадры анимаций существуют.
Map<String, PixelAnimation> _parseAnimations(
  String file,
  Object? json,
  Map<String, Rect> frames,
) {
  if (json == null) return const {};
  if (json is! Map<String, dynamic>) {
    throw FormatException('$file: "animations" должен быть объектом');
  }

  final animations = <String, PixelAnimation>{};
  for (final entry in json.entries) {
    final name = entry.key;
    final data = entry.value;
    if (data is! Map<String, dynamic>) {
      throw FormatException('$file: анимация "$name" должна быть объектом');
    }

    final frameNames = data['frames'];
    if (frameNames is! List || frameNames.isEmpty) {
      throw FormatException(
          '$file: у анимации "$name" нужен непустой список "frames"');
    }
    for (final frame in frameNames) {
      if (frame is! String || !frames.containsKey(frame)) {
        throw FormatException(
            '$file: анимация "$name": нет кадра "$frame" в "frames" атласа');
      }
    }

    final fps = data['fps'];
    if (fps is! num || fps <= 0) {
      throw FormatException('$file: у анимации "$name" "fps" должен быть > 0');
    }

    final loop = data['loop'] ?? false;
    if (loop is! bool) {
      throw FormatException('$file: у анимации "$name" "loop" не true/false');
    }

    animations[name] = PixelAnimation(
      frames: List<String>.unmodifiable(frameNames.cast<String>()),
      fps: fps.toDouble(),
      loop: loop,
    );
  }
  return animations;
}
