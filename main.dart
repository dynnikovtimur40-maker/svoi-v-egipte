import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const SvoiApp());
}

// =====================================================================
// Палитра (из утверждённого макета)
// =====================================================================

const teal = Color(0xFF0B6770);
const tealDeep = Color(0xFF084F56);

class Pal {
  const Pal({
    required this.dark,
    required this.accent,
    required this.bg,
    required this.card,
    required this.soft,
    required this.seg,
    required this.line,
    required this.line2,
    required this.line3,
    required this.text,
    required this.text2,
    required this.muted,
    required this.body,
    required this.brown,
    required this.warnbg,
    required this.warn,
    required this.sel,
    required this.okbg,
    required this.ok,
    required this.avatar,
    required this.infobg,
    required this.info,
    required this.bad,
    required this.input,
    required this.hint,
  });

  final bool dark;
  final Color accent, bg, card, soft, seg, line, line2, line3, text, text2, muted;
  final Color body, brown, warnbg, warn, sel, okbg, ok, avatar, infobg, info, bad;
  final Color input, hint;

  static const light = Pal(
    dark: false,
    accent: Color(0xFF0B6770),
    bg: Color(0xFFF5EFE4),
    card: Color(0xFFFFFFFF),
    soft: Color(0xFFEEF2F3),
    seg: Color(0xFFE3E8EA),
    line: Color(0xFFE3E8EA),
    line2: Color(0xFFCFD8DB),
    line3: Color(0xFFEEF2F3),
    text: Color(0xFF13262B),
    text2: Color(0xFF3D4F54),
    muted: Color(0xFF4E5E63),
    body: Color(0xFF263A3F),
    brown: Color(0xFF6B3F1D),
    warnbg: Color(0xFFFFF3DC),
    warn: Color(0xFF6B4500),
    sel: Color(0xFFEEF7F8),
    okbg: Color(0xFFE2F4E7),
    ok: Color(0xFF17703A),
    avatar: Color(0xFFD6EEF0),
    infobg: Color(0xFFE4E7FB),
    info: Color(0xFF2E3790),
    bad: Color(0xFFA33A2B),
    input: Color(0xFFFFFFFF),
    hint: Color(0xFF8A989C),
  );

  static const darkPal = Pal(
    dark: true,
    accent: Color(0xFF6FD6DE),
    bg: Color(0xFF0B1416),
    card: Color(0xFF152225),
    soft: Color(0xFF1E2E32),
    seg: Color(0xFF1E2E32),
    line: Color(0xFF24363A),
    line2: Color(0xFF34494E),
    line3: Color(0xFF1E2E32),
    text: Color(0xFFFFFFFF),
    text2: Color(0xFFE3EAEC),
    muted: Color(0xFFB8C5C8),
    body: Color(0xFFF0F4F5),
    brown: Color(0xFFFFFFFF),
    warnbg: Color(0xFF33290F),
    warn: Color(0xFFF5DFA8),
    sel: Color(0xFF1B3236),
    okbg: Color(0xFF163A22),
    ok: Color(0xFF8EE0A8),
    avatar: Color(0xFF123A3E),
    infobg: Color(0xFF22264A),
    info: Color(0xFFC3C8F7),
    bad: Color(0xFFF5A99C),
    input: Color(0xFF1E2E32),
    hint: Color(0xFF8FA0A4),
  );

  static Pal of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkPal : light;
}

/// Пары «фон / цвет значка» для плашек и их тёмные версии.
const sectionTint = {
  Section.ads: [0xFFDDF0F2, 0xFF0B6770],
  Section.services: [0xFFFCE9D9, 0xFF9A4A0C],
  Section.jobs: [0xFFE4E7FB, 0xFF3A44A8],
};

const catColors = [
  [0xFFDDF0F2, 0xFF0B6770],
  [0xFFFCE9D9, 0xFF9A4A0C],
  [0xFFE4E7FB, 0xFF3A44A8],
  [0xFFE2F4E7, 0xFF17703A],
  [0xFFFBE1DD, 0xFFA33A2B],
  [0xFFF3E6FA, 0xFF7A3A96],
  [0xFFFFF3DC, 0xFF8A5A00],
];

const _darkTints = {
  0xFFDDF0F2: [0xFF123A3E, 0xFF7FD6DC],
  0xFFFCE9D9: [0xFF3E2716, 0xFFF5B98A],
  0xFFE4E7FB: [0xFF22264A, 0xFFAEB5F5],
  0xFFE2F4E7: [0xFF163A22, 0xFF8EE0A8],
  0xFFFBE1DD: [0xFF45201B, 0xFFF5A99C],
  0xFFF3E6FA: [0xFF33203D, 0xFFD9A8EE],
  0xFFFFF3DC: [0xFF3A2E10, 0xFFF5D58A],
};

List<int> tint(List<int> pair, bool dark) =>
    dark && _darkTints.containsKey(pair[0]) ? _darkTints[pair[0]]! : pair;

Color withAlpha(int argb, double a) =>
    Color(((a * 255).round().clamp(0, 255) << 24) | (argb & 0xFFFFFF));

TextStyle heading(double size, {FontWeight weight = FontWeight.w700, Color? color, double height = 1.3}) =>
    GoogleFonts.manrope(fontSize: size, fontWeight: weight, color: color, height: height);

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Pal.darkPal : Pal.light;
  final scheme = ColorScheme.fromSeed(seedColor: teal, brightness: b)
      .copyWith(primary: p.accent, surface: p.card, onSurface: p.text, error: p.bad);
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    splashColor: withAlpha(0xFF0B6770, 0.08),
    highlightColor: withAlpha(0xFF0B6770, 0.05),
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: p.text, displayColor: p.text),
    textSelectionTheme: TextSelectionThemeData(cursorColor: p.accent),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
  );
}

// =====================================================================
// Иконки макета: рисуем SVG-контуры напрямую
// =====================================================================

const ic = <String, String>{
  'tag': 'M3 12V4h8l10 10-8 8L3 12z M7.5 8.5h.01',
  'home': 'M3 11l9-7 9 7 M5 10v10h14V10 M10 20v-6h4v6',
  'phone': 'M7 3h10v18H7z M11 18h2',
  'sofa': 'M4 11V8a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v3 M2 12h20v5H2z M5 17v2 M19 17v2',
  'car': 'M5 16l1.5-5h11l1.5 5 M3 16h18v3H3z M7 19v1 M17 19v1',
  'gift': 'M4 10h16v10H4z M3 7h18v3H3z M12 7v13 M12 7c-2-3-5-3-5-1s3 1 5 1c2 0 5 1 5-1s-3-2-5 1',
  'tool': 'M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 0 0 5.4-5.4l-2.5 2.5-2.4-.6-.6-2.4z',
  'doc': 'M6 3h9l4 4v14H6z M14 3v5h5 M9 13h7 M9 17h5',
  'book': 'M4 5a2 2 0 0 1 2-2h13v16H6a2 2 0 0 0-2 2z M4 19V5',
  'bag': 'M3 7h18v13H3z M8 7V4h8v3 M3 12h18',
  'news': 'M4 5h13v14H5a1 1 0 0 1-1-1z M17 9h3v9a1 1 0 0 1-1 1 M7 9h7 M7 13h7 M7 16h4',
  'menu': 'M4 6h16 M4 12h16 M4 18h16',
  'grid': 'M4 4h7v7H4z M13 4h7v7h-7z M4 13h7v7H4z M13 13h7v7h-7z',
  'key': 'M8 15a4 4 0 1 1 3.5-6 M11.5 9H21 M18 9v3 M15 9v2',
  'scissors': 'M6 9a3 3 0 1 0 0-6 3 3 0 0 0 0 6z M6 21a3 3 0 1 0 0-6 3 3 0 0 0 0 6z M8.5 7.5L20 18 M8.5 16.5L20 6',
  'truck': 'M2 6h12v10H2z M14 10h4l3 3v3h-7 M6 19a2 2 0 1 0 0-4 2 2 0 0 0 0 4z M17 19a2 2 0 1 0 0-4 2 2 0 0 0 0 4z',
  'chat': 'M4 5h16v11H9l-5 4z',
  'laptop': 'M5 5h14v10H5z M2 19h20',
  'coin': 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z M15 9c-.5-1-1.6-1.5-3-1.5-1.7 0-3 .8-3 2s1.3 1.7 3 2 3 .8 3 2-1.3 2-3 2c-1.4 0-2.5-.5-3-1.5 M12 6v1.5 M12 16.5V18',
  'people': 'M9 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6z M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6 M16 11a2.5 2.5 0 1 0 0-5 M18 14c2 .6 3 2.6 3 5',
  'alert': 'M12 3l10 18H2z M12 10v5 M12 18h.01',
  'sun': 'M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8z M12 2v2 M12 20v2 M4 12H2 M22 12h-2 M5 5l1.5 1.5 M17.5 17.5L19 19 M5 19l1.5-1.5 M17.5 6.5L19 5',
  'moon': 'M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z',
  'shirt': 'M8 4L3 7l2 4 3-1v10h8V10l3 1 2-4-5-3c-.6 1.5-2.1 2.5-4 2.5S8.6 5.5 8 4z',
  'camera': 'M4 8h4l2-3h4l2 3h4v11H4z M12 17a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z',
  'pin': 'M12 21s-7-6.2-7-11.5A7 7 0 0 1 19 9.5C19 14.8 12 21 12 21z M12 12a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z',
  'search': 'M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14z M20 20l-4-4',
  'filter': 'M4 6h10 M18 6h2 M4 12h4 M12 12h8 M4 18h12 M20 18h0 M16 4v4 M10 10v4 M18 16v4',
  'heart': 'M12 20s-7.5-4.6-9.3-9.2C1.5 7.6 3.6 4.5 7 4.5c2 0 3.6 1.1 5 3 1.4-1.9 3-3 5-3 3.4 0 5.5 3.1 4.3 6.3C19.5 15.4 12 20 12 20z',
  'back': 'M15 5l-7 7 7 7',
  'close': 'M6 6l12 12 M18 6L6 18',
  'plus': 'M12 5v14 M5 12h14',
  'send': 'M4 12l16-8-6 16-2-7z',
  'chevron': 'M9 5l7 7-7 7',
  'down': 'M6 9l6 6 6-6',
  'edit': 'M4 20h4L19 9l-4-4L4 16z M14 6l4 4',
  'user': 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8z M4 21c0-4 3.6-7 8-7s8 3 8 7',
  'logout': 'M15 4h4v16h-4 M10 8l-4 4 4 4 M6 12h10',
  'lock': 'M6 11h12v10H6z M8 11V8a4 4 0 0 1 8 0v3',
  'eye': 'M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
  'eyeOff': 'M3 3l18 18 M10.6 5.1C11 5 11.5 5 12 5c6.5 0 10 7 10 7a17 17 0 0 1-3.2 4 M6.6 6.6C3.7 8.5 2 12 2 12s3.5 7 10 7c1.8 0 3.4-.5 4.7-1.3 M9.9 9.9a3 3 0 0 0 4.2 4.2',
  'mail': 'M3 5h18v14H3z M3 6l9 7 9-7',
  'check': 'M5 12l5 5 9-10',
  'star': 'M12 3l2.8 5.7 6.2.9-4.5 4.4 1.1 6.2L12 17.3 6.4 20.2l1.1-6.2L3 9.6l6.2-.9z',
  'trash': 'M4 7h16 M9 7V4h6v3 M6 7l1 13h10l1-13',
  'globe': 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z M3 12h18 M12 3c2.5 2.5 3.5 5.5 3.5 9s-1 6.5-3.5 9c-2.5-2.5-3.5-5.5-3.5-9s1-6.5 3.5-9z',
  'help': 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.6v.6 M12 17h.01',
  'palette': 'M12 21a9 9 0 1 1 9-9c0 2-1.5 3-3 3h-2a2 2 0 0 0-1.5 3.3c.4.5.5 1 .5 1.4 0 .8-1.2 1.3-3 1.3z M7.5 11.5h.01 M10 7.5h.01 M14.5 7.5h.01 M17 11h.01',
  'phoneCall': 'M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z',
  'copy': 'M9 9h11v11H9z M5 15H4V4h11v1',
  'shield': 'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z M8.5 12l2.5 2.5 4.5-5',
  'image': 'M3 5h18v14H3z M3 16l5-5 4 4 3-3 6 6 M15.5 9.5h.01',
};

const catIcon = {
  'Все': 'grid',
  'Аренда жилья': 'home',
  'Продажа жилья': 'key',
  'Электроника': 'phone',
  'Мебель': 'sofa',
  'Авто': 'car',
  'Одежда': 'shirt',
  'Отдам даром': 'gift',
  'Ремонт': 'tool',
  'Визы и документы': 'doc',
  'Репетиторы': 'book',
  'Красота': 'scissors',
  'Перевозки': 'truck',
  'Переводчики': 'chat',
  'Фото и видео': 'camera',
  'Вакансии': 'bag',
  'Резюме': 'doc',
  'Удалёнка': 'laptop',
  'Туризм': 'sun',
};

String iconForPost(Post p) {
  final c = catIcon[p.category];
  if (c != null) return c;
  switch (p.section) {
    case Section.ads:
      return 'tag';
    case Section.services:
      return 'tool';
    case Section.jobs:
      return 'bag';
  }
}

final _pathCache = <String, Path>{};

/// Небольшой разборщик SVG-контуров (M L H V C S Q A Z и их строчные версии).
Path svgPath(String d) {
  final cached = _pathCache[d];
  if (cached != null) return cached;
  final path = Path();
  final re = RegExp(r'[MmLlHhVvCcSsQqAaZz]|-?(?:\d*\.\d+|\d+\.?\d*)(?:[eE][-+]?\d+)?');
  final t = re.allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  var cmd = '';
  double x = 0, y = 0, sx = 0, sy = 0, cx2 = 0, cy2 = 0;
  var lastWasCubic = false;
  bool isCmd(String s) => s.length == 1 && RegExp(r'[A-Za-z]').hasMatch(s);
  double n() => double.parse(t[i++]);
  while (i < t.length) {
    if (isCmd(t[i])) {
      cmd = t[i++];
    } else if (cmd == '' || cmd == 'Z' || cmd == 'z') {
      i++;
      continue;
    }
    final rel = cmd == cmd.toLowerCase();
    final ox = rel ? x : 0.0, oy = rel ? y : 0.0;
    var cubic = false;
    switch (cmd.toUpperCase()) {
      case 'M':
        x = ox + n();
        y = oy + n();
        path.moveTo(x, y);
        sx = x;
        sy = y;
        cmd = rel ? 'l' : 'L';
        break;
      case 'L':
        x = ox + n();
        y = oy + n();
        path.lineTo(x, y);
        break;
      case 'H':
        x = ox + n();
        path.lineTo(x, y);
        break;
      case 'V':
        y = oy + n();
        path.lineTo(x, y);
        break;
      case 'C':
        final x1 = ox + n(), y1 = oy + n();
        cx2 = ox + n();
        cy2 = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, cx2, cy2, x, y);
        cubic = true;
        break;
      case 'S':
        final x1 = lastWasCubic ? 2 * x - cx2 : x;
        final y1 = lastWasCubic ? 2 * y - cy2 : y;
        cx2 = ox + n();
        cy2 = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, cx2, cy2, x, y);
        cubic = true;
        break;
      case 'Q':
        final qx = ox + n(), qy = oy + n();
        x = ox + n();
        y = oy + n();
        path.quadraticBezierTo(qx, qy, x, y);
        break;
      case 'A':
        final rx = n(), ry = n(), rot = n(), large = n(), sweep = n();
        x = ox + n();
        y = oy + n();
        path.arcToPoint(Offset(x, y),
            radius: Radius.elliptical(rx, ry),
            rotation: rot,
            largeArc: large != 0,
            clockwise: sweep != 0);
        break;
      case 'Z':
        path.close();
        x = sx;
        y = sy;
        break;
      default:
        i++;
    }
    lastWasCubic = cubic;
  }
  _pathCache[d] = path;
  return path;
}

class Ico extends StatelessWidget {
  const Ico(this.name, {super.key, this.size = 22, this.color, this.stroke = 2, this.fill});
  final String name;
  final double size;
  final Color? color;
  final double stroke;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _IcoPainter(ic[name] ?? ic['tag']!, color ?? Pal.of(context).text, stroke, fill),
    );
  }
}

class _IcoPainter extends CustomPainter {
  _IcoPainter(this.d, this.color, this.stroke, this.fill);
  final String d;
  final Color color;
  final double stroke;
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);
    final p = svgPath(d);
    if (fill != null) canvas.drawPath(p, Paint()..color = fill!);
    canvas.drawPath(
        p,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IcoPainter o) =>
      o.d != d || o.color != color || o.stroke != stroke || o.fill != fill;
}

// =====================================================================
// Пейзаж с пирамидами (шапки экранов)
// =====================================================================

/// Тёмная тема: как в макете — яркость .45 и чуть меньше насыщенности.
Color sceneColor(int v, bool dark) {
  if (!dark) return Color(v);
  final r = (v >> 16) & 255, g = (v >> 8) & 255, b = v & 255;
  int cl(double x) => x.round().clamp(0, 255);
  final nr = cl(.3792 * r + .0644 * g + .0065 * b);
  final ng = cl(.0192 * r + .4244 * g + .0065 * b);
  final nb = cl(.0192 * r + .0644 * g + .3665 * b);
  return Color(0xFF000000 | (nr << 16) | (ng << 8) | nb);
}

void _fill(Canvas c, String d, Color col) => c.drawPath(svgPath(d), Paint()..color = col);

const _palmTrunk = 'M62 162 C60 140 58 125 64 106';
const _palmLeaves =
    'M64 106 C50 96 36 100 28 110 C42 104 54 106 64 106z M64 106 C74 92 90 92 100 100 C86 98 74 102 64 106z M64 106 C58 90 62 80 72 76 C68 88 68 96 64 106z M64 106 C76 104 92 110 96 122 C86 112 74 110 64 106z M64 106 C52 108 40 116 38 128 C46 118 56 112 64 106z';

/// Большая сцена: шапка ленты и экран входа (viewBox 390×vbH, xMidYMin slice).
class BigScene extends CustomPainter {
  BigScene({required this.dark, required this.bottom, this.vbH = 314});
  final bool dark;
  final Color bottom;
  final double vbH;

  @override
  void paint(Canvas canvas, Size size) {
    Color c(int v) => sceneColor(v, dark);
    final s = math.max(size.width / 390, size.height / vbH);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate((size.width - 390 * s) / 2, 0);
    canvas.scale(s);
    final rect = Rect.fromLTWH(0, 0, 390, vbH);
    canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c(0xFFFBE7C6), c(0xFFF4BC80)],
          ).createShader(rect));
    canvas.drawCircle(const Offset(322, 96), 26, Paint()..color = c(0xFFF7A956));
    _fill(canvas, 'M0 140 C60 120 120 128 180 136 C240 144 300 122 390 132 V160 H0z', c(0xFFEDB97C));
    _fill(canvas, 'M250 80 L312 152 H188z', c(0xFFE09A55));
    _fill(canvas, 'M250 80 L312 152 H262z', c(0xFFBF7638));
    _fill(canvas, 'M338 112 L368 152 H308z', c(0xFFE09A55));
    _fill(canvas, 'M338 112 L368 152 H344z', c(0xFFBF7638));
    _fill(canvas, 'M182 116 L212 152 H152z', c(0xFFE7A867));
    _fill(canvas, 'M182 116 L212 152 H188z', c(0xFFC7813F));
    canvas.drawRect(const Rect.fromLTWH(0, 150, 390, 18), Paint()..color = c(0xFF1E8A93));
    canvas.drawPath(
        svgPath('M30 160 h40 M200 157 h40 M300 162 h50'),
        Paint()
          ..color = c(0xFF7FD0D4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round);
    _fill(canvas, 'M140 161 h26 l-4 5 h-18z', c(0xFF5A3B22));
    _fill(canvas, 'M152 160 V134 L167 157z', c(0xFFFFFFFF));
    void palm(int leaf) {
      canvas.drawPath(
          svgPath(_palmTrunk),
          Paint()
            ..color = c(0xFF7A5532)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round);
      _fill(canvas, _palmLeaves, c(leaf));
    }

    palm(0xFF2F6B4F);
    canvas.save();
    canvas.translate(66, 32);
    canvas.scale(0.75);
    palm(0xFF3A7D5C);
    canvas.restore();
    // Нижний край сливается с фоном экрана (не затемняем).
    final bottomPath = Path()
      ..moveTo(0, 166)
      ..cubicTo(90, 158, 200, 170, 390, 162)
      ..lineTo(390, math.max(vbH, size.height / s) + 2)
      ..lineTo(0, math.max(vbH, size.height / s) + 2)
      ..close();
    canvas.drawPath(bottomPath, Paint()..color = bottom);
    canvas.restore();
  }

  @override
  bool shouldRepaint(BigScene o) => o.dark != dark || o.bottom != bottom || o.vbH != vbH;
}

/// Узкая сцена для шапок внутренних экранов (viewBox 390×72, xMaxYMax slice).
class SmallScene extends CustomPainter {
  SmallScene({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    Color c(int v) => sceneColor(v, dark);
    final s = math.max(size.width / 390, size.height / 72);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width - 390 * s, size.height - 72 * s);
    canvas.scale(s);
    const rect = Rect.fromLTWH(0, 0, 390, 72);
    canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c(0xFFFBE7C6), c(0xFFF6C894)],
          ).createShader(rect));
    canvas.drawCircle(const Offset(300, 30), 13, Paint()..color = c(0xFFF7A956));
    _fill(canvas, 'M0 58 C80 50 160 56 240 54 C300 52 340 48 390 52 V72 H0z', c(0xFFEDB97C));
    _fill(canvas, 'M330 22 L368 64 H292z', c(0xFFE09A55));
    _fill(canvas, 'M330 22 L368 64 H337z', c(0xFFBF7638));
    _fill(canvas, 'M262 38 L284 64 H240z', c(0xFFE7A867));
    _fill(canvas, 'M262 38 L284 64 H266z', c(0xFFC7813F));
    canvas.drawRect(const Rect.fromLTWH(0, 64, 390, 8), Paint()..color = c(0xFF1E8A93));
    canvas.restore();
  }

  @override
  bool shouldRepaint(SmallScene o) => o.dark != dark;
}

/// Узоры на цветных плашках (новости, карточка без фото).
class BannerDeco extends CustomPainter {
  BannerDeco({required this.ink, required this.big});
  final int ink;
  final bool big;

  @override
  void paint(Canvas canvas, Size size) {
    final w = big ? 358.0 : 358.0, h = big ? 210.0 : 96.0;
    final s = math.max(size.width / w, size.height / h);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate((size.width - w * s) / 2, size.height - h * s);
    canvas.scale(s);
    if (big) {
      canvas.drawCircle(const Offset(300, 50), 22, Paint()..color = withAlpha(0xFFFFFFFF, .55));
      canvas.drawCircle(const Offset(40, 40), 10, Paint()..color = withAlpha(0xFFFFFFFF, .45));
      _fill(canvas, 'M0 170 C80 155 170 175 358 160 V210 H0z', withAlpha(ink, .12));
      _fill(canvas, 'M280 120 L330 180 H230z', withAlpha(ink, .16));
      _fill(canvas, 'M60 140 L92 180 H28z', withAlpha(ink, .12));
    } else {
      _fill(canvas, 'M300 30 L344 96 H256z', withAlpha(ink, .14));
      _fill(canvas, 'M240 54 L268 96 H212z', withAlpha(ink, .10));
      _fill(canvas, 'M0 84 C90 74 200 90 358 80 V96 H0z', withAlpha(ink, .10));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BannerDeco o) => o.ink != ink || o.big != big;
}

class DashedBorder extends CustomPainter {
  DashedBorder(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(1), const Radius.circular(14));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final m in (Path()..addRRect(rr)).computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 6, m.length)), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorder o) => o.color != color;
}

// =====================================================================
// Общие элементы интерфейса
// =====================================================================

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

void toast(BuildContext context, String text) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF13262B),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    duration: const Duration(milliseconds: 2400),
  ));
}

Future<T?> push<T>(BuildContext context, Widget page) =>
    Navigator.push<T>(context, MaterialPageRoute(builder: (_) => page));

/// Просим войти: закрываем все экраны и показываем вход.
Future<void> askLogin(BuildContext context, String why) async {
  final p = Pal.of(context);
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: p.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Нужен вход', style: heading(19, color: p.text)),
      content: Text(why, style: TextStyle(fontSize: 15, color: p.text2, height: 1.45)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Не сейчас', style: TextStyle(color: p.muted))),
        FilledButton(
            style: FilledButton.styleFrom(backgroundColor: teal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Войти')),
      ],
    ),
  );
  if (go == true && context.mounted) {
    final app = AppScope.of(context);
    Navigator.of(context).popUntil((r) => r.isFirst);
    app.setGuest(false);
  }
}

class Box extends StatelessWidget {
  const Box({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.radius = 16, this.color, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final br = BorderRadius.circular(radius);
    return Material(
      color: color ?? p.card,
      shape: RoundedRectangleBorder(borderRadius: br, side: BorderSide(color: p.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, required this.onPressed, this.busy = false, this.height = 52, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final double height;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: withAlpha(0xFF0B6770, .55),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: busy
            ? const SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Ico(icon!, size: 20, color: Colors.white), const SizedBox(width: 8)],
                Text(label),
              ]),
      ),
    );
  }
}

class OutlineBtn extends StatelessWidget {
  const OutlineBtn(this.label, {super.key, required this.onPressed, this.color, this.height = 46, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final double height;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final fg = color ?? p.accent;
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: p.card,
          side: BorderSide(color: p.line2),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Ico(icon!, size: 18, color: fg), const SizedBox(width: 6)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

OutlineInputBorder _border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));

InputDecoration fieldDecoration(Pal p, {String? hint, Widget? suffix, bool enabled = true}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: p.hint, fontSize: 15),
      isDense: true,
      filled: true,
      fillColor: enabled ? p.input : p.soft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      suffixIcon: suffix,
      border: _border(p.line2),
      enabledBorder: _border(p.line2),
      disabledBorder: _border(p.line),
      focusedBorder: _border(p.accent, 1.6),
      errorBorder: _border(p.bad),
      focusedErrorBorder: _border(p.bad, 1.6),
      errorStyle: TextStyle(color: p.bad, fontSize: 12),
    );

/// Поле с подписью СВЕРХУ (без плавающих подписей).
class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.keyboard,
    this.maxLines = 1,
    this.validator,
    this.obscure = false,
    this.suffix,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.capitalization = TextCapitalization.none,
    this.autocorrect = true,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboard;
  final int maxLines;
  final String? Function(String?)? validator;
  final bool obscure;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final TextCapitalization capitalization;
  final bool autocorrect;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontSize: 13, color: p.text2, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: obscure ? 1 : maxLines,
        minLines: maxLines > 1 ? maxLines : null,
        obscureText: obscure,
        validator: validator,
        onFieldSubmitted: onSubmitted,
        onChanged: onChanged,
        enabled: enabled,
        autocorrect: autocorrect,
        textCapitalization: capitalization,
        style: TextStyle(fontSize: 15, color: enabled ? p.text : p.muted),
        decoration: fieldDecoration(p, hint: hint, suffix: suffix, enabled: enabled),
      ),
    ]);
  }
}

/// Выбор из списка в стиле поля (открывает нижнюю панель).
class PickField extends StatelessWidget {
  const PickField({super.key, required this.label, required this.value, required this.options, required this.onChanged});
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontSize: 13, color: p.text2, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      Material(
        color: p.input,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: p.line2)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final v = await pickOption(context, label, options, value);
            if (v != null) onChanged(v);
          },
          child: SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Expanded(
                    child: Text(value,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: p.text))),
                Ico('down', size: 18, color: p.muted),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

Future<String?> pickOption(BuildContext context, String title, List<String> options, String current) {
  final p = Pal.of(context);
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: p.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .75),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(title, style: heading(18, color: p.text)),
          ),
          Flexible(
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(8, 0, 8, 12), children: [
              for (final o in options)
                OptionRow(label: o, selected: o == current, onTap: () => Navigator.pop(ctx, o)),
            ]),
          ),
        ]),
      ),
    ),
  );
}

class OptionRow extends StatelessWidget {
  const OptionRow({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Material(
      color: selected ? p.sel : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: p.text))),
              if (selected) Ico('check', size: 20, color: p.accent, stroke: 2.4),
            ]),
          ),
        ),
      ),
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 10),
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: Pal.of(context).line2, borderRadius: BorderRadius.circular(2)),
        ),
      );
}

/// Переключатель как в макете.
class Toggle extends StatelessWidget {
  const Toggle({super.key, required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 46,
      height: 28,
      padding: const EdgeInsets.all(3),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(color: value ? teal : p.line2, borderRadius: BorderRadius.circular(14)),
      child: Container(
          width: 22, height: 22, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
    );
  }
}

/// Сегменты («Объявление / Услуга / Работа», тема и т. п.).
class Segments<T> extends StatelessWidget {
  const Segments({super.key, required this.values, required this.labels, required this.selected, required this.onChanged});
  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.seg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(values[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: values[i] == selected ? p.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: values[i] == selected
                      ? [BoxShadow(color: withAlpha(0xFF000000, .06), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Text(labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: values[i] == selected ? p.accent : p.text2)),
              ),
            ),
          ),
      ]),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.bg, required this.fg, this.big = false});
  final String text;
  final Color bg, fg;
  final bool big;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: big ? 12 : 8, vertical: big ? 6 : 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(big ? 14 : 8)),
        child: Text(text, style: TextStyle(fontSize: 13, color: fg, fontWeight: FontWeight.w600, height: 1.2)),
      );
}

class VerifiedPill extends StatelessWidget {
  const VerifiedPill({super.key, this.big = false, this.text = '✓ Проверен'});
  final bool big;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Pill(text, bg: p.okbg, fg: p.ok, big: big);
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.size = 44, this.bg, this.fg});
  final String name;
  final String? url;
  final double size;
  final Color? bg, fg;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final letter = Center(
      child: Text(initialOf(name),
          style: TextStyle(
              fontSize: size * .4, fontWeight: size > 60 ? FontWeight.w800 : FontWeight.w700, color: fg ?? p.accent)),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg ?? p.avatar, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: (url == null || url!.isEmpty)
          ? letter
          : Image.network(url!, fit: BoxFit.cover, width: size, height: size, errorBuilder: (_, __, ___) => letter),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 0),
      child: Row(children: [
        Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: p.text))),
        if (action != null)
          TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: p.accent, visualDensity: VisualDensity.compact),
              child: Text(action!, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text, this.action, this.onAction});
  final String icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: p.avatar, shape: BoxShape.circle),
          child: Center(child: Ico(icon, size: 32, color: p.accent, stroke: 1.8)),
        ),
        const SizedBox(height: 14),
        Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: p.muted, height: 1.5)),
        if (action != null) ...[
          const SizedBox(height: 16),
          SizedBox(width: 240, child: PrimaryButton(action!, onPressed: onAction, height: 48)),
        ],
      ]),
    );
  }
}

/// Шапка внутренних экранов: пейзаж + «назад» + заголовок.
class SubHeader extends StatelessWidget {
  const SubHeader({super.key, required this.title, this.leading = 'back', this.trailing, this.center = false});
  final String title;
  final String leading;
  final Widget? trailing;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final top = MediaQuery.of(context).padding.top;
    final titleW = Text(title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: center ? FontWeight.w600 : FontWeight.w700, fontSize: center ? 16 : 17, color: p.text));
    return Stack(children: [
      Positioned.fill(child: CustomPaint(painter: SmallScene(dark: p.dark))),
      Padding(
        padding: EdgeInsets.fromLTRB(8, 8 + top, 8, 8),
        child: Row(children: [
          IconBtn(leading, onTap: () => Navigator.maybePop(context), label: leading == 'close' ? 'Закрыть' : 'Назад'),
          const SizedBox(width: 4),
          Expanded(child: center ? Center(child: titleW) : titleW),
          trailing ?? const SizedBox(width: 44),
        ]),
      ),
    ]);
  }
}

class IconBtn extends StatelessWidget {
  const IconBtn(this.icon, {super.key, required this.onTap, this.label, this.color, this.fill, this.size = 22});
  final String icon;
  final VoidCallback? onTap;
  final String? label;
  final Color? color;
  final Color? fill;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: Ico(icon, size: size, color: color ?? Pal.of(context).text, stroke: 2.2, fill: fill)),
        ),
      ),
    );
  }
}

Future<void> openUrl(BuildContext context, String url, String fallbackCopy) async {
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && context.mounted) {
    Clipboard.setData(ClipboardData(text: fallbackCopy));
    toast(context, 'Не удалось открыть. Контакт скопирован: $fallbackCopy');
  }
}

String contactDigits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

String? telegramUser(String s) {
  final m = RegExp(r'(?:t\.me/|@)([A-Za-z0-9_]{4,})').firstMatch(s);
  return m?.group(1);
}

Future<Uint8List?> pickOneImage({double maxWidth = 1600}) async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: maxWidth, imageQuality: 82);
  if (x == null) return null;
  return x.readAsBytes();
}

Future<List<Uint8List>> pickManyImages(int limit) async {
  if (limit <= 0) return [];
  final xs = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 82);
  final out = <Uint8List>[];
  for (final x in xs.take(limit)) {
    out.add(await x.readAsBytes());
  }
  return out;
}

// =====================================================================
// Приложение
// =====================================================================

class SvoiApp extends StatefulWidget {
  const SvoiApp({super.key});

  @override
  State<SvoiApp> createState() => _SvoiAppState();
}

class _SvoiAppState extends State<SvoiApp> {
  final state = AppState();

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: AnimatedBuilder(
        animation: state,
        builder: (_, __) => MaterialApp(
          title: 'Свои в Египте',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: state.themeMode,
          home: const AuthGate(),
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? sub;
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    final app = AppScope.of(context);
    app.loadSettings();
    app.load();
    app.onAuthChanged();
    sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      app.onAuthChanged();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (app.user != null || app.guest) return const HomeShell();
    return const AuthScreen();
  }
}

// =====================================================================
// Вход и регистрация
// =====================================================================

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool register = false;
  bool busy = false;
  bool hide = true;
  String? message;
  final name = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  String translate(String m) {
    final l = m.toLowerCase();
    if (l.contains('invalid login')) return 'Неверная почта или пароль';
    if (l.contains('already registered') || l.contains('already been registered')) {
      return 'Эта почта уже зарегистрирована — войдите';
    }
    if (l.contains('password should be')) return 'Пароль должен быть не короче 6 символов';
    if (l.contains('invalid') && l.contains('email')) return 'Проверьте адрес почты';
    if (l.contains('rate limit')) return 'Слишком много попыток, подождите минуту';
    return m;
  }

  Future<void> submit() async {
    final e = email.text.trim();
    final p = pass.text;
    if (!e.contains('@') || p.length < 6 || (register && name.text.trim().isEmpty)) {
      setState(() => message = register
          ? 'Заполните имя, почту и пароль (от 6 символов)'
          : 'Введите почту и пароль (от 6 символов)');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    final auth = Supabase.instance.client.auth;
    try {
      if (register) {
        final res = await auth.signUp(email: e, password: p, data: {'name': name.text.trim()});
        if (res.session == null && mounted) {
          setState(() => message = 'Готово! Проверьте почту и подтвердите адрес, затем войдите.');
        }
      } else {
        await auth.signInWithPassword(email: e, password: p);
      }
    } on AuthException catch (err) {
      if (mounted) setState(() => message = translate(err.message));
    } catch (_) {
      if (mounted) setState(() => message = 'Нет связи с сервером, попробуйте ещё раз');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> resetPassword() async {
    final e = email.text.trim();
    if (!e.contains('@')) {
      setState(() => message = 'Введите почту, и мы пришлём ссылку для сброса пароля');
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(e);
      if (mounted) setState(() => message = 'Письмо для сброса пароля отправлено');
    } catch (_) {
      if (mounted) setState(() => message = 'Не удалось отправить письмо, попробуйте позже');
    }
  }

  Widget authField(String label, TextEditingController c,
      {String? hint, TextInputType? kb, bool obscure = false, Widget? suffix, ValueChanged<String>? onSubmit,
      TextCapitalization cap = TextCapitalization.none}) {
    OutlineInputBorder b(Color col, double w) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: col, width: w));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFFD6EEF0), fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      TextField(
        controller: c,
        keyboardType: kb,
        obscureText: obscure,
        autocorrect: false,
        textCapitalization: cap,
        onSubmitted: onSubmit,
        style: const TextStyle(fontSize: 17, color: Color(0xFF13262B)),
        cursorColor: teal,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF8A989C), fontSize: 16),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          suffixIcon: suffix,
          border: b(Colors.transparent, 0),
          enabledBorder: b(Colors.transparent, 0),
          focusedBorder: b(const Color(0xFFF6C894), 2),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: teal,
      body: ListView(padding: EdgeInsets.zero, children: [
        SizedBox(
          height: 230 + top,
          child: CustomPaint(painter: BigScene(dark: false, bottom: teal, vbH: 230)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Свои в Египте', style: heading(30, weight: FontWeight.w800, color: Colors.white, height: 1.1)),
            const SizedBox(height: 10),
            const Text('Объявления, услуги, работа и новости для русскоязычных в Египте',
                style: TextStyle(fontSize: 16, height: 1.45, color: Color(0xFFD6EEF0))),
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: const Color(0xFF0E7C86), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                for (final r in [false, true])
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() {
                        register = r;
                        message = null;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: register == r ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(r ? 'Регистрация' : 'Вход',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: register == r ? teal : Colors.white)),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 18),
            if (register) ...[
              authField('Ваше имя', name, hint: 'Например: Тимур', cap: TextCapitalization.words),
              const SizedBox(height: 12),
            ],
            authField('Электронная почта', email, hint: 'name@mail.com', kb: TextInputType.emailAddress),
            const SizedBox(height: 12),
            authField('Пароль', pass,
                hint: 'Не короче 6 символов',
                obscure: hide,
                onSubmit: (_) => submit(),
                suffix: IconButton(
                  onPressed: () => setState(() => hide = !hide),
                  icon: Ico(hide ? 'eye' : 'eyeOff', size: 20, color: const Color(0xFF4E5E63)),
                )),
            if (message != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: tealDeep, borderRadius: BorderRadius.circular(12)),
                child: Text(message!, style: const TextStyle(color: Color(0xFFFFE3B0), fontSize: 14, height: 1.4)),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: busy ? null : submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: teal,
                  disabledBackgroundColor: const Color(0xFFD6EEF0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                child: busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: teal))
                    : Text(register ? 'Зарегистрироваться' : 'Войти'),
              ),
            ),
            if (!register)
              TextButton(
                onPressed: resetPassword,
                style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                child: const Text('Забыли пароль?', style: TextStyle(color: Color(0xFFD6EEF0), fontSize: 14)),
              ),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () => AppScope.of(context).setGuest(true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF8CC9CE)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                child: const Text('Пропустить, просто посмотреть'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// =====================================================================
// Каркас с нижним меню
// =====================================================================

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;

  static const pages = <Widget>[
    ListTab(section: Section.ads),
    ListTab(section: Section.services),
    ListTab(section: Section.jobs),
    NewsTab(),
    MoreTab(),
  ];

  static const tabDefs = [
    ['Объявления', 'tag'],
    ['Услуги', 'tool'],
    ['Работа', 'bag'],
    ['Новости', 'news'],
    ['Ещё', 'menu'],
  ];

  void openAdd() {
    final app = AppScope.of(context);
    if (app.user == null) {
      askLogin(context, 'Чтобы разместить объявление, войдите или зарегистрируйтесь — это займёт минуту.');
      return;
    }
    push(context, AddPostScreen(section: Section.values[tab]));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      floatingActionButton: tab <= 2
          ? FloatingActionButton.extended(
              onPressed: openAdd,
              backgroundColor: teal,
              foregroundColor: Colors.white,
              elevation: 6,
              shape: const StadiumBorder(),
              icon: const Ico('plus', size: 20, color: Colors.white, stroke: 2.4),
              label: const Text('Разместить', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            )
          : null,
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(4, 6, 4, 10 + bottom),
        decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.line))),
        child: Row(children: [
          for (var i = 0; i < tabDefs.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: tab == i,
                label: tabDefs[i][0],
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => tab = i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Stack(clipBehavior: Clip.none, children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 56,
                          height: 30,
                          decoration: BoxDecoration(
                              color: tab == i ? p.avatar : Colors.transparent, borderRadius: BorderRadius.circular(15)),
                          child: Center(child: Ico(tabDefs[i][1], size: 22, color: tab == i ? p.accent : p.muted)),
                        ),
                        if (i == 4 && app.unreadTotal > 0)
                          Positioned(
                            right: 8,
                            top: -2,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 18),
                              height: 18,
                              padding: const EdgeInsets.symmetric(horizontal: 5),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFD93D3D), borderRadius: BorderRadius.circular(9)),
                              child: Center(
                                child: Text('${app.unreadTotal}',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(tabDefs[i][0],
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600, color: tab == i ? p.accent : p.muted)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// =====================================================================
// Лента: объявления / услуги / работа
// =====================================================================

class ListTab extends StatefulWidget {
  const ListTab({super.key, required this.section});
  final Section section;

  @override
  State<ListTab> createState() => _ListTabState();
}

class _ListTabState extends State<ListTab> {
  String? cat;
  String query = '';
  final filters = Filters();

  Future<void> pickCity() async {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final top = MediaQuery.of(context).padding.top;
    final v = await showDialog<String>(
      context: context,
      barrierColor: withAlpha(0xFF13262B, .35),
      useSafeArea: false,
      builder: (ctx) => Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, top + 64, 16, 0),
          child: Material(
            color: p.card,
            elevation: 12,
            shadowColor: withAlpha(0xFF000000, .3),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Text('Ваш город', style: TextStyle(fontSize: 13, color: p.muted)),
                ),
                for (final c in cities)
                  OptionRow(label: c, selected: app.city == c, onTap: () => Navigator.pop(ctx, c)),
              ]),
            ),
          ),
        ),
      ),
    );
    if (v != null) app.setCity(v);
  }

  Future<void> openFilters() async {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final tmp = Filters()
      ..sort = filters.sort
      ..priceFrom = filters.priceFrom
      ..priceTo = filters.priceTo
      ..verifiedOnly = filters.verifiedOnly;
    final from = TextEditingController(text: filters.priceFrom?.toString() ?? '');
    final to = TextEditingController(text: filters.priceTo?.toString() ?? '');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final n = app.filter(widget.section, cat, query, tmp).length;
        Widget sortChip(SortMode m, String label) {
          final on = tmp.sort == m;
          return GestureDetector(
            onTap: () => setSheet(() => tmp.sort = m),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? teal : p.card,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: on ? teal : p.line2),
              ),
              child: Text(label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: on ? Colors.white : p.text)),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SheetHandle(),
            Row(children: [
              Expanded(child: Text('Фильтры', style: heading(18, color: p.text))),
              if (tmp.active)
                TextButton(
                  onPressed: () => setSheet(() {
                    tmp.sort = SortMode.fresh;
                    tmp.priceFrom = null;
                    tmp.priceTo = null;
                    tmp.verifiedOnly = false;
                    from.clear();
                    to.clear();
                  }),
                  child: Text('Сбросить', style: TextStyle(color: p.accent, fontWeight: FontWeight.w600)),
                ),
            ]),
            const SizedBox(height: 10),
            Text('Сортировка', style: TextStyle(fontSize: 13, color: p.text2, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              sortChip(SortMode.fresh, 'Сначала новые'),
              sortChip(SortMode.cheap, 'Дешевле'),
              sortChip(SortMode.expensive, 'Дороже'),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: Field(
                  label: 'Цена от, EGP',
                  controller: from,
                  hint: '0',
                  keyboard: TextInputType.number,
                  onChanged: (v) => setSheet(() => tmp.priceFrom = int.tryParse(v.replaceAll(' ', ''))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Field(
                  label: 'до, EGP',
                  controller: to,
                  hint: 'любая',
                  keyboard: TextInputType.number,
                  onChanged: (v) => setSheet(() => tmp.priceTo = int.tryParse(v.replaceAll(' ', ''))),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Box(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              radius: 14,
              onTap: () => setSheet(() => tmp.verifiedOnly = !tmp.verifiedOnly),
              child: Row(children: [
                Expanded(child: Text('Только проверенные', style: TextStyle(fontSize: 15, color: p.text))),
                Toggle(value: tmp.verifiedOnly),
              ]),
            ),
            const SizedBox(height: 16),
            PrimaryButton('Показать $n ${plural(n, 'объявление', 'объявления', 'объявлений')}',
                onPressed: () => Navigator.pop(ctx, true)),
          ]),
        );
      }),
    );
    if (ok == true) {
      setState(() {
        filters.sort = tmp.sort;
        filters.priceFrom = tmp.priceFrom;
        filters.priceTo = tmp.priceTo;
        filters.verifiedOnly = tmp.verifiedOnly;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final items = app.filter(widget.section, cat, query, filters);
    final catNames = <String?>[null, ...categories[widget.section]!];
    final top = MediaQuery.of(context).padding.top;
    final title = sectionNames[widget.section]!;

    final header = Stack(children: [
      Positioned.fill(child: CustomPaint(painter: BigScene(dark: p.dark, bottom: p.bg))),
      Padding(
        padding: EdgeInsets.only(top: 16 + top, bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Spacer(),
              Semantics(
                button: true,
                label: 'Сменить тему',
                child: GestureDetector(
                  onTap: () => app.toggleTheme(Theme.of(context).brightness),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: p.card, shape: BoxShape.circle, border: Border.all(color: p.line2)),
                    child: Center(child: Ico(p.dark ? 'sun' : 'moon', size: 18, color: p.accent)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Выбрать город',
                child: GestureDetector(
                  onTap: pickCity,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                        color: p.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.line2)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Ico('pin', size: 16, color: p.accent),
                      const SizedBox(width: 6),
                      Text(app.city, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: p.text)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 88),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: withAlpha(0xFF6B3F1D, .12), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(children: [
                    Ico('search', size: 18, color: p.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => query = v),
                        style: TextStyle(fontSize: 15, color: p.text),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration.collapsed(
                          hintText: 'Поиск: ${title.toLowerCase()}',
                          hintStyle: TextStyle(fontSize: 15, color: p.hint),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Фильтры',
                child: GestureDetector(
                  onTap: openFilters,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: filters.active ? teal : p.card,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: withAlpha(0xFF6B3F1D, .12), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Center(child: Ico('filter', size: 20, color: filters.active ? Colors.white : p.text)),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: catNames.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = catNames[i];
                final on = cat == c;
                final name = c ?? 'Все';
                final col = tint(catColors[i % catColors.length], p.dark);
                return GestureDetector(
                  onTap: () => setState(() => cat = c),
                  child: SizedBox(
                    width: 72,
                    child: Column(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: on ? teal : Color(col[0]),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: withAlpha(0xFF6B3F1D, .12), blurRadius: 6, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Center(
                          child: Ico(catIcon[name] ?? 'tag',
                              size: 26, stroke: 1.9, color: on ? Colors.white : Color(col[1])),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Builder(builder: (_) {
                        final st = TextStyle(
                            fontSize: 12, height: 1.2, color: p.text, fontWeight: on ? FontWeight.w700 : FontWeight.w500);
                        // Одно слово — не переносим посреди слова, а слегка уменьшаем.
                        if (!name.contains(' ')) {
                          return FittedBox(
                              fit: BoxFit.scaleDown, child: Text(name, maxLines: 1, style: st));
                        }
                        return Text(name,
                            textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: st);
                      }),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    ]);

    return RefreshIndicator(
      color: p.accent,
      onRefresh: app.load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: header),
          if (app.loading && app.posts.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
            ),
          if (app.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: p.warnbg, borderRadius: BorderRadius.circular(14)),
                  child: Text(app.error!, style: TextStyle(color: p.warn, fontSize: 13, height: 1.45)),
                ),
              ),
            ),
          if (items.isEmpty && !(app.loading && app.posts.isEmpty))
            SliverToBoxAdapter(
              child: EmptyState(
                icon: catIcon[cat ?? 'Все'] ?? 'tag',
                text: query.isNotEmpty || filters.active || cat != null || app.city != cities.first
                    ? 'Ничего не нашлось.\nПопробуйте изменить поиск, город или фильтры.'
                    : 'Здесь пока пусто.\nСтаньте первым — нажмите «Разместить».',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 110),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => PostCard(post: items[i]),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> favOrLogin(BuildContext context, String id) async {
  final app = AppScope.of(context);
  final was = app.favorites.contains(id);
  final ok = await app.toggleFav(id);
  if (!context.mounted) return;
  if (!ok) {
    askLogin(context, 'Войдите, чтобы сохранять объявления в избранное.');
  } else if (!was) {
    toast(context, 'Добавлено в избранное');
  }
}

class PostThumb extends StatelessWidget {
  const PostThumb({super.key, required this.post, this.size = 76, this.height, this.radius = 12, this.iconSize = 34});
  final Post post;
  final double size;
  final double? height;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final t = tint(sectionTint[post.section]!, p.dark);
    final fallback = Container(
      color: Color(t[0]),
      child: Center(child: Ico(iconForPost(post), size: iconSize, color: Color(t[1]), stroke: 1.8)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: height ?? size,
        child: post.photos.isEmpty
            ? fallback
            : Image.network(post.photos.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
      ),
    );
  }
}

class HeartIcon extends StatelessWidget {
  const HeartIcon({super.key, required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) => Ico('heart',
      size: 22,
      stroke: 2,
      color: on ? const Color(0xFFD93D3D) : Pal.of(context).muted,
      fill: on ? const Color(0xFFD93D3D) : null);
}

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final fav = app.favorites.contains(post.id);
    final rating = app.ratings[post.userId];
    final rub = priceRub(post.priceEgp);

    return Box(
      padding: const EdgeInsets.all(12),
      onTap: () => push(context, PostDetailScreen(post: post)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PostThumb(post: post),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(post.title,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: heading(16, color: p.text)),
            const SizedBox(height: 4),
            Text(priceMain(post.priceEgp),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.accent)),
            if (rub.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(rub, style: TextStyle(fontSize: 13, color: p.muted)),
            ],
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('${post.city} · ${post.category}', style: TextStyle(fontSize: 13, color: p.muted)),
              if (post.verified) const VerifiedPill(),
              if (rating != null)
                Text('★ ${rating.toStringAsFixed(1)}',
                    style: TextStyle(fontSize: 13, color: p.warn, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
        IconBtn('heart',
            label: 'В избранное',
            onTap: () => favOrLogin(context, post.id),
            color: fav ? const Color(0xFFD93D3D) : p.muted,
            fill: fav ? const Color(0xFFD93D3D) : null),
      ]),
    );
  }
}

// =====================================================================
// Карточка объявления
// =====================================================================

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.post});
  final Post post;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  int page = 0;

  Post get post => widget.post;

  void contact(String kind) {
    final c = post.contact.trim();
    final d = contactDigits(c);
    final tg = telegramUser(c);
    final hasPhone = d.length >= 8;
    final plus = c.contains('+') || d.startsWith('20') ? '+' : '';
    if (kind == 'wa') {
      if (!hasPhone) {
        Clipboard.setData(ClipboardData(text: c));
        toast(context, 'Номер WhatsApp не указан. Контакт скопирован: $c');
        return;
      }
      openUrl(context, 'https://wa.me/$d', c);
    } else if (kind == 'tg') {
      if (tg != null) {
        openUrl(context, 'https://t.me/$tg', c);
      } else if (hasPhone) {
        openUrl(context, 'https://t.me/+$d', c);
      } else {
        Clipboard.setData(ClipboardData(text: c));
        toast(context, 'Контакт скопирован: $c');
      }
    } else {
      if (!hasPhone) {
        Clipboard.setData(ClipboardData(text: c));
        toast(context, 'Телефон не указан. Контакт скопирован: $c');
        return;
      }
      openUrl(context, 'tel:$plus$d', c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final fav = app.favorites.contains(post.id);
    final t = tint(sectionTint[post.section]!, p.dark);
    final rating = app.ratings[post.userId];
    final mine = app.user?.id == post.userId;
    final since = post.authorSince != null ? ' · на сайте с ${post.authorSince!.year}' : '';
    final rub = priceRub(post.priceEgp);

    Widget gallery;
    if (post.photos.isEmpty) {
      gallery = Container(
        height: 210,
        decoration: BoxDecoration(color: Color(t[0]), borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: BannerDeco(ink: t[1], big: true))),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: p.card,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: withAlpha(0xFF000000, .10), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Center(child: Ico(iconForPost(post), size: 52, color: Color(t[1]), stroke: 1.5)),
            ),
          ),
        ]),
      );
    } else {
      gallery = ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 260,
          child: Stack(children: [
            PageView.builder(
              itemCount: post.photos.length,
              onPageChanged: (i) => setState(() => page = i),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => push(context, PhotoViewer(photos: post.photos, start: i)),
                child: Container(
                  color: Color(t[0]),
                  child: Image.network(post.photos[i],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) =>
                          Center(child: Ico('image', size: 40, color: Color(t[1]), stroke: 1.6))),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(10)),
                  child: Text('Фото ${page + 1} из ${post.photos.length}',
                      style: TextStyle(fontSize: 13, color: p.text2)),
                ),
              ),
            ),
          ]),
        ),
      );
    }

    Widget contactBtn(String label, Color bg, Color fg, VoidCallback onTap, {bool outline = false}) => SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              padding: EdgeInsets.zero,
              side: outline ? BorderSide(color: p.line2) : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            child: Text(label),
          ),
        );

    return Scaffold(
      body: Column(children: [
        SubHeader(
          title: sectionNames[post.section]!,
          center: true,
          trailing: IconBtn('heart',
              label: 'В избранное',
              onTap: () => favOrLogin(context, post.id),
              color: fav ? const Color(0xFFD93D3D) : p.text,
              fill: fav ? const Color(0xFFD93D3D) : null),
        ),
        Expanded(
          child: ListView(padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom), children: [
            gallery,
            const SizedBox(height: 14),
            Text(post.title, style: heading(22, weight: FontWeight.w800, color: p.text, height: 1.25)),
            const SizedBox(height: 8),
            Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
              Text(priceMain(post.priceEgp),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.accent)),
              if (rub.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(rub, style: TextStyle(fontSize: 14, color: p.muted)),
                ),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _Chip(post.city),
              _Chip(post.category),
              _Chip(dateText(post.date)),
              if (post.verified) const VerifiedPill(big: true),
            ]),
            const SizedBox(height: 12),
            Text(post.description.isEmpty ? 'Без описания' : post.description,
                style: TextStyle(fontSize: 16, height: 1.6, color: p.body)),
            const SizedBox(height: 14),
            Box(
              padding: const EdgeInsets.all(12),
              onTap: () => push(context, SellerScreen(userId: post.userId, name: post.author, fromPost: post)),
              child: Row(children: [
                Avatar(name: post.author, url: post.authorAvatar, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(post.author, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: p.text)),
                    const SizedBox(height: 2),
                    Text(
                        rating != null
                            ? 'Рейтинг ${rating.toStringAsFixed(1)} ★$since'
                            : 'Новый пользователь$since',
                        style: TextStyle(fontSize: 13, color: p.muted)),
                  ]),
                ),
                Ico('chevron', size: 20, color: p.muted),
              ]),
            ),
            const SizedBox(height: 12),
            if (mine) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: p.sel, borderRadius: BorderRadius.circular(14)),
                child: Text('Это ваше объявление. Контакт для связи: ${post.contact}',
                    style: TextStyle(fontSize: 14, color: p.accent, fontWeight: FontWeight.w600, height: 1.4)),
              ),
              const SizedBox(height: 10),
              PrimaryButton('Изменить объявление', icon: 'edit', onPressed: () async {
                final changed = await push<bool>(context, AddPostScreen(section: post.section, edit: post));
                if (changed == true && context.mounted) Navigator.pop(context);
              }),
            ] else ...[
              Row(children: [
                Expanded(child: contactBtn('WhatsApp', const Color(0xFF1B8F4A), Colors.white, () => contact('wa'))),
                const SizedBox(width: 8),
                Expanded(child: contactBtn('Telegram', const Color(0xFF1F6FB2), Colors.white, () => contact('tg'))),
                const SizedBox(width: 8),
                Expanded(child: contactBtn('Позвонить', p.card, p.text, () => contact('call'), outline: true)),
              ]),
              const SizedBox(height: 8),
              OutlineBtn('Написать в чат', icon: 'chat', height: 48, onPressed: () {
                if (app.user == null) {
                  askLogin(context, 'Войдите, чтобы переписываться с продавцами.');
                  return;
                }
                push(
                    context,
                    ChatScreen(
                        otherId: post.userId,
                        otherName: post.author,
                        otherAvatar: post.authorAvatar,
                        postId: post.id,
                        postTitle: '${post.title} · ${priceMain(post.priceEgp)}'));
              }),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.warnbg, borderRadius: BorderRadius.circular(14)),
              child: Text('Не переводите предоплату до встречи. Выбирайте продавцов с отметкой «Проверен».',
                  style: TextStyle(fontSize: 13, color: p.warn, height: 1.45)),
            ),
            if (!mine)
              Center(
                child: TextButton(
                  onPressed: () {
                    if (app.user == null) {
                      askLogin(context, 'Войдите, чтобы отправить жалобу модератору.');
                      return;
                    }
                    app.report(post.id);
                    toast(context, 'Спасибо! Модератор проверит объявление.');
                  },
                  style: TextButton.styleFrom(foregroundColor: p.bad, minimumSize: const Size(0, 44)),
                  child: const Text('Пожаловаться на объявление', style: TextStyle(fontSize: 14)),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: p.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.line)),
      child: Text(text, style: TextStyle(fontSize: 13, color: p.text, height: 1.2)),
    );
  }
}

class PhotoViewer extends StatelessWidget {
  const PhotoViewer({super.key, required this.photos, this.start = 0});
  final List<String> photos;
  final int start;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        PageView.builder(
          controller: PageController(initialPage: start),
          itemCount: photos.length,
          itemBuilder: (_, i) => InteractiveViewer(
            maxScale: 4,
            child: Center(child: Image.network(photos[i], fit: BoxFit.contain)),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          child: IconBtn('close', label: 'Закрыть', color: Colors.white, onTap: () => Navigator.pop(context)),
        ),
      ]),
    );
  }
}

// =====================================================================
// Размещение и редактирование
// =====================================================================

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key, required this.section, this.edit});
  final Section section;
  final Post? edit;

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final formKey = GlobalKey<FormState>();
  late Section section = widget.edit?.section ?? widget.section;
  late String category = widget.edit?.category ?? categories[section]!.first;
  late String city;
  late final title = TextEditingController(text: widget.edit?.title ?? '');
  late final desc = TextEditingController(text: widget.edit?.description ?? '');
  late final price = TextEditingController(text: widget.edit?.priceEgp?.toString() ?? '');
  late final contact = TextEditingController(text: widget.edit?.contact ?? '');
  late List<String> photos = [...?widget.edit?.photos];
  bool busy = false;
  bool uploading = false;
  bool inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (inited) return;
    inited = true;
    final app = AppScope.of(context);
    final prof = app.profile;
    final e = widget.edit;
    city = e?.city ?? (cities.contains(prof?.city) && prof?.city != cities.first ? prof!.city : cities[1]);
    if (e == null && (prof?.phone ?? '').isNotEmpty) contact.text = prof!.phone!;
  }

  @override
  void dispose() {
    for (final c in [title, desc, price, contact]) {
      c.dispose();
    }
    super.dispose();
  }

  String? notEmpty(String? v) => (v == null || v.trim().isEmpty) ? 'Заполните поле' : null;

  Future<void> addPhotos() async {
    final app = AppScope.of(context);
    try {
      final picked = await pickManyImages(5 - photos.length);
      if (picked.isEmpty) return;
      setState(() => uploading = true);
      for (final b in picked) {
        final url = await app.uploadImage(b, 'post');
        if (!mounted) return;
        setState(() => photos.add(url));
      }
    } catch (_) {
      if (mounted) toast(context, 'Не удалось загрузить фото. Попробуйте ещё раз.');
    }
    if (mounted) setState(() => uploading = false);
  }

  Future<void> save() async {
    final app = AppScope.of(context);
    if (app.user == null) {
      askLogin(context, 'Войдите или зарегистрируйтесь, чтобы разместить объявление.');
      return;
    }
    if (!formKey.currentState!.validate()) return;
    if (title.text.trim().length < 3) {
      toast(context, 'Заголовок должен быть не короче 3 символов');
      return;
    }
    setState(() => busy = true);
    try {
      await app.savePost(
        id: widget.edit?.id,
        section: section,
        category: category,
        title: title.text.trim(),
        description: desc.text.trim(),
        city: city,
        contact: contact.text.trim(),
        photos: photos,
        priceEgp: int.tryParse(price.text.replaceAll(RegExp(r'[^0-9]'), '')),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      toast(context, widget.edit == null ? 'Опубликовано!' : 'Изменения сохранены');
    } catch (_) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, 'Не удалось сохранить. Проверьте интернет.');
    }
  }

  Future<void> remove() async {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Удалить объявление?', style: heading(19, color: p.text)),
        content: Text('Его нельзя будет восстановить.', style: TextStyle(color: p.text2, fontSize: 15)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Отмена', style: TextStyle(color: p.muted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Удалить', style: TextStyle(color: p.bad, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await app.deletePost(widget.edit!.id);
      if (!mounted) return;
      Navigator.pop(context, true);
      toast(context, 'Объявление удалено');
    } catch (_) {
      if (mounted) toast(context, 'Не удалось удалить. Проверьте интернет.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    const gap = SizedBox(height: 14);
    final cats = categories[section]!;
    if (!cats.contains(category)) category = cats.first;

    Widget photoTile(int i) => Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(photos[i],
                width: 88,
                height: 88,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(width: 88, height: 88, color: p.soft, child: Center(child: Ico('image', color: p.muted)))),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: () => setState(() => photos.removeAt(i)),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: withAlpha(0xFF13262B, .7), shape: BoxShape.circle),
                child: const Center(child: Ico('close', size: 14, color: Colors.white, stroke: 2.6)),
              ),
            ),
          ),
          if (i == 0)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: withAlpha(0xFF13262B, .7), borderRadius: BorderRadius.circular(6)),
                child: const Text('Главное', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
        ]);

    final addTile = GestureDetector(
      onTap: uploading ? null : addPhotos,
      child: CustomPaint(
        painter: DashedBorder(const Color(0xFFA9B8BC)),
        child: Container(
          width: photos.isEmpty ? double.infinity : 88,
          height: photos.isEmpty ? 96 : 88,
          alignment: Alignment.center,
          child: uploading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Ico('camera', size: 20, color: p.text2),
                  if (photos.isEmpty) ...[
                    const SizedBox(width: 8),
                    Text('Добавить фото (до 5)', style: TextStyle(fontSize: 14, color: p.text2)),
                  ],
                ]),
        ),
      ),
    );

    return Scaffold(
      body: Column(children: [
        SubHeader(title: widget.edit == null ? 'Новое объявление' : 'Редактирование', leading: 'close'),
        Expanded(
          child: Form(
            key: formKey,
            child: ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
                children: [
                  Segments<Section>(
                    values: Section.values,
                    labels: Section.values.map((s) => sectionSingle[s]!).toList(),
                    selected: section,
                    onChanged: (s) => setState(() {
                      section = s;
                      category = categories[s]!.first;
                    }),
                  ),
                  gap,
                  if (photos.isEmpty)
                    addTile
                  else
                    SizedBox(
                      height: 88,
                      child: ListView(scrollDirection: Axis.horizontal, children: [
                        for (var i = 0; i < photos.length; i++) ...[photoTile(i), const SizedBox(width: 8)],
                        if (photos.length < 5) addTile,
                      ]),
                    ),
                  gap,
                  PickField(
                      label: 'Категория',
                      value: category,
                      options: cats,
                      onChanged: (v) => setState(() => category = v)),
                  gap,
                  Field(
                    label: 'Заголовок',
                    controller: title,
                    hint: 'Например: Квартира 2 комнаты у моря',
                    validator: notEmpty,
                    capitalization: TextCapitalization.sentences,
                  ),
                  gap,
                  Field(
                    label: 'Описание',
                    controller: desc,
                    hint: 'Подробности, состояние, условия',
                    maxLines: 4,
                    capitalization: TextCapitalization.sentences,
                  ),
                  gap,
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Field(
                        label: 'Цена, EGP',
                        controller: price,
                        hint: 'Пусто — договорная',
                        keyboard: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PickField(
                          label: 'Город',
                          value: city,
                          options: cities.sublist(1),
                          onChanged: (v) => setState(() => city = v)),
                    ),
                  ]),
                  gap,
                  Field(
                    label: 'Контакт (WhatsApp, Telegram или телефон)',
                    controller: contact,
                    hint: '@username или +20…',
                    validator: notEmpty,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 6),
                  Text('Цена 0 — «Бесплатно». Покупатели увидят примерную цену в рублях.',
                      style: TextStyle(fontSize: 12, color: p.muted, height: 1.4)),
                  const SizedBox(height: 20),
                  PrimaryButton(widget.edit == null ? 'Опубликовать' : 'Сохранить изменения',
                      busy: busy, onPressed: uploading ? null : save),
                  if (widget.edit != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: busy ? null : remove,
                      style: TextButton.styleFrom(foregroundColor: p.bad, minimumSize: const Size.fromHeight(44)),
                      child: const Text('Удалить объявление', style: TextStyle(fontSize: 15)),
                    ),
                  ],
                ]),
          ),
        ),
      ]),
    );
  }
}

// =====================================================================
// Новости
// =====================================================================

class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final top = MediaQuery.of(context).padding.top;
    return Stack(children: [
      Positioned.fill(child: CustomPaint(painter: SmallScene(dark: p.dark))),
      Padding(padding: EdgeInsets.fromLTRB(16, 16 + top, 16, 16), child: child),
    ]);
  }
}

class NewsTab extends StatelessWidget {
  const NewsTab({super.key});

  static const tagColors = {
    'Визы': [0xFFE4E7FB, 0xFF3A44A8],
    'Курс': [0xFFDDF0F2, 0xFF0B6770],
    'События': [0xFFFCE9D9, 0xFF9A4A0C],
    'Важно': [0xFFFBE1DD, 0xFFA33A2B],
  };
  static const tagIcons = {'Визы': 'doc', 'Курс': 'coin', 'События': 'people', 'Важно': 'alert'};

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(children: [
      TabHeader(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Новости', style: heading(22, weight: FontWeight.w800, color: p.text)),
          Text('Важное для русскоязычных в Египте',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.brown)),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: demoNews.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final n = demoNews[i];
            final c = tint(tagColors[n.tag] ?? catColors[0], p.dark);
            return Container(
              decoration: BoxDecoration(
                  color: p.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line)),
              clipBehavior: Clip.antiAlias,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  height: 96,
                  color: Color(c[0]),
                  child: Stack(children: [
                    Positioned.fill(child: CustomPaint(painter: BannerDeco(ink: c[1], big: false))),
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(color: p.card, shape: BoxShape.circle),
                        child: Center(child: Ico(tagIcons[n.tag] ?? 'news', size: 28, stroke: 1.9, color: Color(c[1]))),
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Pill(n.tag, bg: Color(c[0]), fg: Color(c[1])),
                      const Spacer(),
                      Text(n.date, style: TextStyle(fontSize: 13, color: p.muted)),
                    ]),
                    const SizedBox(height: 8),
                    Text(n.title, style: heading(17, color: p.text)),
                    const SizedBox(height: 6),
                    Text(n.summary, style: TextStyle(fontSize: 15, color: p.text2, height: 1.5)),
                  ]),
                ),
              ]),
            );
          },
        ),
      ),
    ]);
  }
}

// =====================================================================
// Ещё
// =====================================================================

class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final logged = app.user != null;
    final prof = app.profile;
    final active = app.myPosts.where((x) => x.status == 'active').length;
    final dark = Theme.of(context).brightness == Brightness.dark;

    void needLogin(String why, VoidCallback go) {
      if (logged) {
        go();
      } else {
        askLogin(context, why);
      }
    }

    return Column(children: [
      GestureDetector(
        onTap: () => needLogin('Войдите, чтобы открыть профиль и размещать объявления.',
            () => push(context, const ProfileScreen())),
        child: TabHeader(
          child: Row(children: [
            Avatar(name: logged ? app.userName : '?', url: prof?.avatarUrl, size: 48, bg: p.card),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(logged ? app.userName : 'Гость',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: p.text)),
                Text(
                    logged
                        ? '${prof?.city ?? 'Каир'} · Мои объявления: $active'
                        : 'Войдите, чтобы размещать объявления',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.brown)),
              ]),
            ),
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(17)),
              child: Center(
                child: Text(logged ? 'Профиль' : 'Войти',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.accent)),
              ),
            ),
          ]),
        ),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          const ConverterCard(),
          const SizedBox(height: 12),
          MenuGroup(rows: [
            MenuRow(
                icon: 'user',
                label: 'Мой профиль',
                onTap: () => needLogin('Войдите, чтобы открыть профиль.', () => push(context, const ProfileScreen()))),
            MenuRow(
                icon: 'tag',
                label: 'Мои объявления',
                right: logged ? '${app.myPosts.length}' : null,
                onTap: () => needLogin('Войдите, чтобы видеть свои объявления.', () => push(context, const MyAdsScreen()))),
            MenuRow(
                icon: 'heart',
                label: 'Избранное',
                right: '${app.favorites.length}',
                onTap: () => needLogin('Войдите, чтобы сохранять избранное.', () => push(context, const FavoritesScreen()))),
            MenuRow(
                icon: 'chat',
                label: 'Сообщения',
                right: app.unreadTotal > 0 ? '${app.unreadTotal} ${plural(app.unreadTotal, 'новое', 'новых', 'новых')}' : null,
                rightAccent: app.unreadTotal > 0,
                onTap: () => needLogin('Войдите, чтобы переписываться.', () => push(context, const ChatsScreen()))),
            MenuRow(
                icon: dark ? 'moon' : 'sun',
                label: 'Тема',
                right: dark ? 'Тёмная' : 'Светлая',
                onTap: () => app.toggleTheme(Theme.of(context).brightness)),
            MenuRow(icon: 'globe', label: 'Язык', right: 'Русский', onTap: () => toast(context, 'Другие языки появятся позже')),
            MenuRow(
                icon: 'help',
                label: 'Поддержка',
                onTap: () => toast(context, 'Раздел поддержки скоро появится')),
          ]),
          const SizedBox(height: 4),
          const SectionTitle('Справочник'),
          const SizedBox(height: 8),
          MenuGroup(rows: [
            for (final d in demoDirectory)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.name, style: TextStyle(fontSize: 15, color: p.text)),
                      Text(d.note, style: TextStyle(fontSize: 13, color: p.muted)),
                    ]),
                  ),
                  SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      onPressed: () => openUrl(context, 'tel:${d.phone.replaceAll(' ', '')}', d.phone),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.accent,
                        backgroundColor: p.card,
                        side: BorderSide(color: p.line2),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Ico('phoneCall', size: 15, color: p.accent),
                        const SizedBox(width: 6),
                        Text(d.phone),
                      ]),
                    ),
                  ),
                ]),
              ),
          ]),
          const SizedBox(height: 16),
          Center(child: Text('Свои в Египте · версия 0.3', style: TextStyle(fontSize: 13, color: p.muted))),
        ]),
      ),
    ]);
  }
}

class MenuGroup extends StatelessWidget {
  const MenuGroup({super.key, required this.rows});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i < rows.length - 1) Divider(height: 1, thickness: 1, color: p.line3),
        ],
      ]),
    );
  }
}

class MenuRow extends StatelessWidget {
  const MenuRow({super.key, required this.label, this.icon, this.right, this.onTap, this.rightAccent = false, this.danger = false});
  final String label;
  final String? icon;
  final String? right;
  final VoidCallback? onTap;
  final bool rightAccent;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final fg = danger ? p.bad : p.text;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            if (icon != null) ...[
              Ico(icon!, size: 20, color: danger ? p.bad : p.accent, stroke: 1.9),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: fg))),
            if (right != null)
              Text(right!,
                  style: TextStyle(
                      fontSize: 15,
                      color: rightAccent ? p.accent : p.muted,
                      fontWeight: rightAccent ? FontWeight.w700 : FontWeight.w400)),
            if (onTap != null && !danger) ...[const SizedBox(width: 6), Ico('chevron', size: 16, color: p.muted)],
          ]),
        ),
      ),
    );
  }
}

class ConverterCard extends StatefulWidget {
  const ConverterCard({super.key});

  @override
  State<ConverterCard> createState() => _ConverterCardState();
}

class _ConverterCardState extends State<ConverterCard> {
  final ctl = TextEditingController(text: '1000');
  double egp = 1000;

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget cell(String label, String v) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 13, color: p.muted)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(v, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.text)),
              ),
            ]),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Конвертер валют', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: p.text)),
        const SizedBox(height: 10),
        Field(
          label: 'Сумма в египетских фунтах (EGP)',
          controller: ctl,
          keyboard: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => setState(() => egp = double.tryParse(v.replaceAll(',', '.').replaceAll(' ', '')) ?? 0),
        ),
        const SizedBox(height: 10),
        Row(children: [
          cell('Рубли', '${fmt(egp * rubPerEgp)} ₽'),
          const SizedBox(width: 8),
          cell('Доллары', '${(egp / egpPerUsd).toStringAsFixed(2)} \$'),
          const SizedBox(width: 8),
          cell('Евро', '${(egp / egpPerEur).toStringAsFixed(2)} €'),
        ]),
        const SizedBox(height: 8),
        Text('Примерный курс, для ориентира', style: TextStyle(fontSize: 13, color: p.muted)),
      ]),
    );
  }
}

// =====================================================================
// Профиль
// =====================================================================

const _monthsGen = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
];

String sinceText(DateTime d) => 'На сайте с ${_monthsGen[d.month - 1]} ${d.year}';

Future<void> changeAvatar(BuildContext context) async {
  final app = AppScope.of(context);
  final p = Pal.of(context);
  final hasPhoto = (app.profile?.avatarUrl ?? '').isNotEmpty;
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: p.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text('Фото профиля', style: heading(18, color: p.text)),
          ),
          MenuRow(icon: 'image', label: 'Выбрать из галереи', onTap: () => Navigator.pop(ctx, 'pick')),
          if (hasPhoto)
            MenuRow(icon: 'trash', label: 'Удалить фото', danger: true, onTap: () => Navigator.pop(ctx, 'remove')),
        ]),
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  try {
    if (action == 'remove') {
      await app.removeAvatar();
      if (context.mounted) toast(context, 'Фото удалено');
      return;
    }
    final bytes = await pickOneImage(maxWidth: 600);
    if (bytes == null) return;
    if (context.mounted) toast(context, 'Загружаем фото…');
    await app.updateAvatar(bytes);
    if (context.mounted) toast(context, 'Фото профиля обновлено');
  } catch (_) {
    if (context.mounted) toast(context, 'Не удалось обновить фото. Попробуйте ещё раз.');
  }
}

class AvatarEditable extends StatelessWidget {
  const AvatarEditable({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    return Semantics(
      button: true,
      label: 'Изменить фото профиля',
      child: GestureDetector(
        onTap: () => changeAvatar(context),
        child: Stack(clipBehavior: Clip.none, children: [
          Avatar(name: app.userName, url: app.profile?.avatarUrl, size: size),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: size * .36,
              height: size * .36,
              decoration: BoxDecoration(color: teal, shape: BoxShape.circle, border: Border.all(color: p.card, width: 3)),
              child: Center(child: Ico('camera', size: size * .17, color: Colors.white, stroke: 2.2)),
            ),
          ),
        ]),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final prof = app.profile;
    final email = app.user?.email ?? '';
    final active = app.myPosts.where((x) => x.status == 'active').length;
    final rating = app.user == null ? null : app.ratings[app.user!.id];
    final reviews = app.user == null ? 0 : (app.reviewCounts[app.user!.id] ?? 0);
    final mode = app.themeMode;

    Widget stat(String v, String label) => Expanded(
          child: Column(children: [
            Text(v, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: p.text)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: p.muted)),
          ]),
        );

    Widget infoRow(String icon, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Ico(icon, size: 20, color: p.accent, stroke: 1.9),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 15, color: p.muted)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, color: p.text, fontWeight: FontWeight.w500)),
            ),
          ]),
        );

    if (app.user == null) {
      return Scaffold(
        body: Column(children: [
          const SubHeader(title: 'Профиль'),
          Expanded(
            child: EmptyState(
              icon: 'user',
              text: 'Войдите, чтобы видеть свой профиль, объявления и избранное.',
              action: 'Войти',
              onAction: () {
                Navigator.of(context).popUntil((r) => r.isFirst);
                app.setGuest(false);
              },
            ),
          ),
        ]),
      );
    }

    return Scaffold(
      body: Column(children: [
        SubHeader(
          title: 'Профиль',
          trailing: IconBtn('edit', label: 'Редактировать', onTap: () => push(context, const EditProfileScreen())),
        ),
        Expanded(
          child: RefreshIndicator(
            color: p.accent,
            onRefresh: app.onAuthChanged,
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 16, 16, 28 + MediaQuery.of(context).padding.bottom),
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                    decoration: BoxDecoration(
                        color: p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.line)),
                    child: Column(children: [
                      const AvatarEditable(size: 88),
                      const SizedBox(height: 12),
                      Text(app.userName,
                          textAlign: TextAlign.center, style: heading(20, weight: FontWeight.w800, color: p.text)),
                      const SizedBox(height: 2),
                      Text(email, style: TextStyle(fontSize: 13, color: p.muted)),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: p.sel, borderRadius: BorderRadius.circular(12)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Ico('pin', size: 14, color: p.accent),
                            const SizedBox(width: 4),
                            Text(prof?.city ?? 'Каир',
                                style: TextStyle(fontSize: 13, color: p.accent, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                        if (prof?.verified == true)
                          const VerifiedPill(big: true, text: '✓ Документы проверены')
                        else
                          Pill('Не проверен', bg: p.soft, fg: p.muted, big: true),
                      ]),
                      if (prof != null) ...[
                        const SizedBox(height: 8),
                        Text(sinceText(prof.createdAt), style: TextStyle(fontSize: 13, color: p.muted)),
                      ],
                      const SizedBox(height: 14),
                      Divider(height: 1, color: p.line3),
                      const SizedBox(height: 14),
                      Row(children: [
                        stat('$active', plural(active, 'объявление', 'объявления', 'объявлений')),
                        stat('${app.favorites.length}', 'в избранном'),
                        stat(rating == null ? '—' : rating.toStringAsFixed(1),
                            reviews == 0 ? 'нет отзывов' : '$reviews ${plural(reviews, 'отзыв', 'отзыва', 'отзывов')}'),
                      ]),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton('Редактировать профиль',
                            icon: 'edit', height: 48, onPressed: () => push(context, const EditProfileScreen())),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 4),
                  const SectionTitle('Мои данные'),
                  const SizedBox(height: 8),
                  MenuGroup(rows: [
                    infoRow('user', 'Имя', app.userName),
                    infoRow('pin', 'Город', prof?.city ?? 'Каир'),
                    infoRow('phoneCall', 'Телефон', (prof?.phone ?? '').isEmpty ? 'Не указан' : prof!.phone!),
                    infoRow('mail', 'Почта', email),
                  ]),
                  const SizedBox(height: 4),
                  SectionTitle('Мои объявления',
                      action: app.myPosts.isEmpty ? null : 'Все',
                      onAction: () => push(context, const MyAdsScreen())),
                  const SizedBox(height: 8),
                  if (app.myPosts.isEmpty)
                    Box(
                      onTap: () => push(context, const AddPostScreen(section: Section.ads)),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: p.avatar, shape: BoxShape.circle),
                          child: Center(child: Ico('plus', size: 22, color: p.accent, stroke: 2.4)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('У вас пока нет объявлений.\nРазместите первое — это бесплатно.',
                              style: TextStyle(fontSize: 14, color: p.text2, height: 1.4)),
                        ),
                      ]),
                    )
                  else
                    MenuGroup(rows: [
                      for (final x in app.myPosts.take(3)) MyPostRow(post: x),
                    ]),
                  const SizedBox(height: 4),
                  SectionTitle('Избранное',
                      action: app.favorites.isEmpty ? null : 'Все',
                      onAction: () => push(context, const FavoritesScreen())),
                  const SizedBox(height: 8),
                  if (app.favoritePosts.isEmpty)
                    Box(
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: withAlpha(0xFFD93D3D, .12), shape: BoxShape.circle),
                          child: const Center(child: Ico('heart', size: 22, color: Color(0xFFD93D3D))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('Нажмите ♡ на объявлении, чтобы сохранить его здесь.',
                              style: TextStyle(fontSize: 14, color: p.text2, height: 1.4)),
                        ),
                      ]),
                    )
                  else
                    SizedBox(
                      height: 150,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: app.favoritePosts.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => FavMiniCard(post: app.favoritePosts[i]),
                      ),
                    ),
                  const SizedBox(height: 4),
                  const SectionTitle('Настройки'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: p.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Ico('palette', size: 20, color: p.accent, stroke: 1.9),
                        const SizedBox(width: 12),
                        Text('Оформление', style: TextStyle(fontSize: 15, color: p.text)),
                      ]),
                      const SizedBox(height: 10),
                      Segments<ThemeMode>(
                        values: const [ThemeMode.light, ThemeMode.dark, ThemeMode.system],
                        labels: const ['Светлая', 'Тёмная', 'Как в системе'],
                        selected: mode,
                        onChanged: app.setTheme,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  MenuGroup(rows: [
                    MenuRow(
                        icon: 'pin',
                        label: 'Город в ленте',
                        right: app.city,
                        onTap: () async {
                          final v = await pickOption(context, 'Город в ленте', cities, app.city);
                          if (v != null) app.setCity(v);
                        }),
                    MenuRow(icon: 'lock', label: 'Сменить пароль', onTap: () => showPasswordSheet(context)),
                    MenuRow(icon: 'chat', label: 'Сообщения', right: app.unreadTotal > 0 ? '${app.unreadTotal}' : null,
                        rightAccent: app.unreadTotal > 0, onTap: () => push(context, const ChatsScreen())),
                    MenuRow(icon: 'globe', label: 'Язык', right: 'Русский', onTap: () => toast(context, 'Другие языки появятся позже')),
                  ]),
                  const SizedBox(height: 10),
                  MenuGroup(rows: [
                    MenuRow(
                      icon: 'logout',
                      label: 'Выйти из аккаунта',
                      danger: true,
                      onTap: () async {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                        await app.signOut();
                      },
                    ),
                  ]),
                ]),
          ),
        ),
      ]),
    );
  }
}

class FavMiniCard extends StatelessWidget {
  const FavMiniCard({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return SizedBox(
      width: 140,
      child: Box(
        padding: const EdgeInsets.all(8),
        onTap: () => push(context, PostDetailScreen(post: post)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PostThumb(post: post, size: 124, height: 70, radius: 10, iconSize: 30),
          const SizedBox(height: 6),
          Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.text, height: 1.25)),
          const Spacer(),
          Text(priceMain(post.priceEgp), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.accent)),
        ]),
      ),
    );
  }
}

class MyPostRow extends StatelessWidget {
  const MyPostRow({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final st = statusStyle(post.status, p);
    return InkWell(
      onTap: () => push(context, PostDetailScreen(post: post)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          PostThumb(post: post, size: 48, radius: 10, iconSize: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text)),
              const SizedBox(height: 2),
              Text('${priceMain(post.priceEgp)} · ${dateText(post.date)}', style: TextStyle(fontSize: 13, color: p.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Pill(st[0] as String, bg: st[1] as Color, fg: st[2] as Color),
        ]),
      ),
    );
  }
}

List<Object> statusStyle(String s, Pal p) {
  switch (s) {
    case 'active':
      return ['Активно', p.okbg, p.ok];
    case 'pending':
      return ['На проверке', p.warnbg, p.warn];
    case 'blocked':
      return ['Заблокировано', withAlpha(0xFFA33A2B, .14), p.bad];
    default:
      return ['Снято', p.soft, p.muted];
  }
}

Future<void> showPasswordSheet(BuildContext context) async {
  final app = AppScope.of(context);
  final p = Pal.of(context);
  final a = TextEditingController();
  final b = TextEditingController();
  String? err;
  var busy = false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetHandle(),
          Text('Сменить пароль', style: heading(18, color: p.text)),
          const SizedBox(height: 14),
          Field(label: 'Новый пароль', controller: a, obscure: true, hint: 'Не короче 6 символов', autocorrect: false),
          const SizedBox(height: 12),
          Field(label: 'Повторите пароль', controller: b, obscure: true, hint: 'Ещё раз', autocorrect: false),
          if (err != null) ...[
            const SizedBox(height: 10),
            Text(err!, style: TextStyle(color: p.bad, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          PrimaryButton('Сохранить пароль', busy: busy, onPressed: () async {
            if (a.text.length < 6) {
              setSheet(() => err = 'Пароль должен быть не короче 6 символов');
              return;
            }
            if (a.text != b.text) {
              setSheet(() => err = 'Пароли не совпадают');
              return;
            }
            setSheet(() {
              err = null;
              busy = true;
            });
            try {
              await app.changePassword(a.text);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) toast(context, 'Пароль изменён');
            } catch (_) {
              setSheet(() {
                busy = false;
                err = 'Не удалось сменить пароль. Попробуйте позже.';
              });
            }
          }),
        ]),
      ),
    ),
  );
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  String city = cities[1];
  bool busy = false;
  bool inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (inited) return;
    inited = true;
    final app = AppScope.of(context);
    name.text = app.userName;
    phone.text = app.profile?.phone ?? '';
    final c = app.profile?.city;
    if (c != null && cities.sublist(1).contains(c)) city = c;
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    final app = AppScope.of(context);
    setState(() => busy = true);
    try {
      await app.updateProfile(name: name.text.trim(), city: city, phone: phone.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, 'Профиль сохранён');
    } catch (_) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, 'Не удалось сохранить. Проверьте интернет.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    return Scaffold(
      body: Column(children: [
        const SubHeader(title: 'Редактировать профиль'),
        Expanded(
          child: Form(
            key: formKey,
            child: ListView(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + MediaQuery.of(context).padding.bottom),
                children: [
                  const Center(child: AvatarEditable(size: 96)),
                  Center(
                    child: TextButton(
                      onPressed: () => changeAvatar(context),
                      style: TextButton.styleFrom(foregroundColor: p.accent),
                      child: const Text('Изменить фото', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: p.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Field(
                        label: 'Имя',
                        controller: name,
                        hint: 'Как к вам обращаться',
                        capitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите имя' : null,
                      ),
                      const SizedBox(height: 14),
                      PickField(
                          label: 'Город',
                          value: city,
                          options: cities.sublist(1),
                          onChanged: (v) => setState(() => city = v)),
                      const SizedBox(height: 14),
                      Field(
                        label: 'Телефон (WhatsApp)',
                        controller: phone,
                        hint: '+20 1XX XXX XXXX',
                        keyboard: TextInputType.phone,
                        autocorrect: false,
                      ),
                      const SizedBox(height: 6),
                      Text('Подставится в новые объявления как контакт.',
                          style: TextStyle(fontSize: 12, color: p.muted)),
                      const SizedBox(height: 14),
                      Field(label: 'Почта', controller: TextEditingController(text: app.user?.email ?? ''), enabled: false),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton('Сохранить', busy: busy, onPressed: save),
                ]),
          ),
        ),
      ]),
    );
  }
}

// =====================================================================
// Мои объявления, избранное
// =====================================================================

class MyAdsScreen extends StatelessWidget {
  const MyAdsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final list = app.myPosts;

    Future<void> setStatus(Post x, String s, String msg) async {
      try {
        await app.setPostStatus(x.id, s);
        if (context.mounted) toast(context, msg);
      } catch (_) {
        if (context.mounted) toast(context, 'Не удалось изменить. Проверьте интернет.');
      }
    }

    Widget smallBtn(String label, VoidCallback? onTap, {bool primary = false, Color? fg}) => SizedBox(
          height: 40,
          child: FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: primary ? teal : p.card,
              foregroundColor: primary ? Colors.white : (fg ?? p.text),
              disabledBackgroundColor: p.soft,
              side: primary ? null : BorderSide(color: p.line2),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: Text(label),
          ),
        );

    return Scaffold(
      body: Column(children: [
        const SubHeader(title: 'Мои объявления'),
        Expanded(
          child: RefreshIndicator(
            color: p.accent,
            onRefresh: app.loadMyPosts,
            child: list.isEmpty
                ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                    EmptyState(
                      icon: 'tag',
                      text: 'У вас пока нет объявлений.\nРазместите первое — это бесплатно.',
                      action: 'Разместить',
                      onAction: () => push(context, const AddPostScreen(section: Section.ads)),
                    ),
                  ])
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.of(context).padding.bottom),
                    itemCount: list.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      if (i == list.length) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: p.infobg, borderRadius: BorderRadius.circular(14)),
                          child: Text('«Поднять» — объявление на 3 дня наверху списка. Функция скоро появится.',
                              style: TextStyle(fontSize: 13, color: p.info, height: 1.45)),
                        );
                      }
                      final x = list[i];
                      final st = statusStyle(x.status, p);
                      final closed = x.status == 'closed';
                      return Box(
                        onTap: () => push(context, PostDetailScreen(post: x)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            PostThumb(post: x, size: 56, radius: 10, iconSize: 26),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(x.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text)),
                                const SizedBox(height: 4),
                                Text('${priceMain(x.priceEgp)} · ${x.city} · ${dateText(x.date)}',
                                    style: TextStyle(fontSize: 13, color: p.muted)),
                              ]),
                            ),
                            const SizedBox(width: 8),
                            Pill(st[0] as String, bg: st[1] as Color, fg: st[2] as Color),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: smallBtn('Поднять', x.status == 'active' ? () => toast(context, 'Поднятие объявлений скоро появится') : null,
                                  primary: true),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: smallBtn('Изменить',
                                  () => push(context, AddPostScreen(section: x.section, edit: x))),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: closed
                                  ? smallBtn('Вернуть', () => setStatus(x, 'active', 'Объявление снова опубликовано'),
                                      fg: p.accent)
                                  : smallBtn(
                                      'Снять',
                                      x.status == 'blocked'
                                          ? null
                                          : () => setStatus(x, 'closed', 'Объявление снято с публикации'),
                                      fg: p.bad),
                            ),
                          ]),
                        ]),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final list = app.favoritePosts;
    return Scaffold(
      body: Column(children: [
        const SubHeader(title: 'Избранное'),
        Expanded(
          child: list.isEmpty
              ? const SingleChildScrollView(
                  child: EmptyState(icon: 'heart', text: 'Здесь пока пусто.\nНажмите ♡ на объявлении, чтобы сохранить его.'))
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.of(context).padding.bottom),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => PostCard(post: list[i]),
                ),
        ),
      ]),
    );
  }
}

// =====================================================================
// Сообщения
// =====================================================================

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    AppScope.of(context).loadThreads();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final list = app.threads;
    return Scaffold(
      body: Column(children: [
        const SubHeader(title: 'Сообщения'),
        Expanded(
          child: RefreshIndicator(
            color: p.accent,
            onRefresh: app.loadThreads,
            child: list.isEmpty
                ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
                    EmptyState(
                        icon: 'chat',
                        text: 'Сообщений пока нет.\nОткройте объявление и нажмите «Написать в чат».'),
                  ])
                : Container(
                    color: p.card,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => Divider(height: 1, thickness: 1, color: p.line3),
                      itemBuilder: (_, i) {
                        final t = list[i];
                        final mine = t.last.senderId == app.user?.id;
                        return InkWell(
                          onTap: () => push(
                              context,
                              ChatScreen(
                                  otherId: t.otherId,
                                  otherName: t.otherName,
                                  otherAvatar: t.otherAvatar,
                                  postId: t.postId,
                                  postTitle: t.postTitle)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(children: [
                              Avatar(name: t.otherName, url: t.otherAvatar, size: 48),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Expanded(
                                      child: Text(t.otherName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: p.text)),
                                    ),
                                    Text(timeText(t.last.date), style: TextStyle(fontSize: 13, color: p.muted)),
                                  ]),
                                  if (t.postTitle.isNotEmpty)
                                    Text(t.postTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 13, color: p.accent)),
                                  Text('${mine ? 'Вы: ' : ''}${t.last.text}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: p.text2,
                                          fontWeight: t.unread > 0 ? FontWeight.w600 : FontWeight.w400)),
                                ]),
                              ),
                              if (t.unread > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  constraints: const BoxConstraints(minWidth: 22),
                                  height: 22,
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  decoration: BoxDecoration(color: teal, borderRadius: BorderRadius.circular(11)),
                                  child: Center(
                                    child: Text('${t.unread}',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ],
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ]),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.otherId,
    required this.otherName,
    this.otherAvatar,
    this.postId,
    this.postTitle = '',
  });
  final String otherId;
  final String otherName;
  final String? otherAvatar;
  final String? postId;
  final String postTitle;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final draft = TextEditingController();
  List<ChatMessage> msgs = [];
  bool loading = true;
  bool sending = false;
  Timer? timer;
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    refresh();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
  }

  Future<void> refresh() async {
    try {
      final list = await AppScope.of(context).fetchMessages(widget.otherId, widget.postId);
      if (!mounted) return;
      setState(() {
        msgs = list;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> send() async {
    final text = draft.text.trim();
    if (text.isEmpty || sending) return;
    final app = AppScope.of(context);
    setState(() => sending = true);
    try {
      await app.sendMessage(widget.otherId, widget.postId, text);
      draft.clear();
      await refresh();
    } catch (_) {
      if (mounted) toast(context, 'Не удалось отправить. Проверьте интернет.');
    }
    if (mounted) setState(() => sending = false);
  }

  @override
  void dispose() {
    timer?.cancel();
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final me = app.user?.id;
    final rev = msgs.reversed.toList();
    return Scaffold(
      body: Column(children: [
        SubHeader(title: widget.otherName),
        if (widget.postTitle.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: p.sel, border: Border(bottom: BorderSide(color: p.line))),
            child: Text(widget.postTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: p.accent, fontWeight: FontWeight.w600)),
          ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : msgs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('Напишите первое сообщение — например, спросите, актуально ли объявление.',
                            textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 15, height: 1.5)),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: rev.length,
                      itemBuilder: (_, i) {
                        final m = rev[i];
                        final mine = m.senderId == me;
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                              decoration: BoxDecoration(
                                color: mine ? teal : p.card,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(mine ? 18 : 6),
                                  bottomRight: Radius.circular(mine ? 6 : 18),
                                ),
                                border: mine ? null : Border.all(color: p.line),
                              ),
                              child: IntrinsicWidth(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                  Text(m.text,
                                      style: TextStyle(fontSize: 15, height: 1.4, color: mine ? Colors.white : p.text)),
                                  const SizedBox(height: 2),
                                  Text(timeText(m.date),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontSize: 12, color: mine ? const Color(0xB3FFFFFF) : p.muted)),
                                ]),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(12, 10, 12, 12 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.line))),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: draft,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => send(),
                style: TextStyle(fontSize: 15, color: p.text),
                decoration: InputDecoration(
                  hintText: 'Сообщение…',
                  hintStyle: TextStyle(color: p.hint, fontSize: 15),
                  isDense: true,
                  filled: true,
                  fillColor: p.input,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: p.line2)),
                  enabledBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: p.line2)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: p.accent, width: 1.6)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Отправить',
              child: GestureDetector(
                onTap: send,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: teal, shape: BoxShape.circle),
                  child: Center(
                    child: sending
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Ico('send', size: 20, color: Colors.white, stroke: 2.2),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// =====================================================================
// Профиль продавца и отзывы
// =====================================================================

class SellerScreen extends StatefulWidget {
  const SellerScreen({super.key, required this.userId, required this.name, this.fromPost});
  final String userId;
  final String name;
  final Post? fromPost;

  @override
  State<SellerScreen> createState() => _SellerScreenState();
}

class _SellerScreenState extends State<SellerScreen> {
  Profile? prof;
  List<Post> posts = [];
  List<Review> reviews = [];
  bool loading = true;
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    load();
  }

  Future<void> load() async {
    final app = AppScope.of(context);
    final r = await Future.wait([
      app.fetchProfile(widget.userId),
      app.fetchSellerPosts(widget.userId),
      app.fetchReviews(widget.userId),
    ]);
    if (!mounted) return;
    setState(() {
      prof = r[0] as Profile?;
      posts = r[1] as List<Post>;
      reviews = r[2] as List<Review>;
      loading = false;
    });
  }

  Future<void> leaveReview() async {
    final app = AppScope.of(context);
    if (app.user == null) {
      askLogin(context, 'Войдите, чтобы оставить отзыв.');
      return;
    }
    final p = Pal.of(context);
    var stars = 5;
    final text = TextEditingController();
    var busy = false;
    String? err;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SheetHandle(),
            Text('Отзыв о продавце', style: heading(18, color: p.text)),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 1; i <= 5; i++)
                GestureDetector(
                  onTap: () => setSheet(() => stars = i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Ico('star',
                        size: 36,
                        stroke: 1.6,
                        color: const Color(0xFFE0A100),
                        fill: i <= stars ? const Color(0xFFF5B82E) : null),
                  ),
                ),
            ]),
            const SizedBox(height: 14),
            Field(
                label: 'Комментарий',
                controller: text,
                maxLines: 3,
                hint: 'Как прошла сделка?',
                capitalization: TextCapitalization.sentences),
            if (err != null) ...[
              const SizedBox(height: 10),
              Text(err!, style: TextStyle(color: p.bad, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            PrimaryButton('Отправить отзыв', busy: busy, onPressed: () async {
              setSheet(() {
                busy = true;
                err = null;
              });
              try {
                await app.addReview(widget.userId, stars, text.text.trim());
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                final dup = e.toString().contains('duplicate') || e.toString().contains('23505');
                setSheet(() {
                  busy = false;
                  err = dup ? 'Вы уже оставили отзыв этому продавцу.' : 'Не удалось отправить. Попробуйте позже.';
                });
              }
            }),
          ]),
        ),
      ),
    );
    if (ok == true && mounted) {
      toast(context, 'Спасибо за отзыв!');
      load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final name = (prof?.name ?? '').isNotEmpty ? prof!.name : widget.name;
    final avg = reviews.isEmpty ? null : reviews.fold<int>(0, (a, r) => a + r.stars) / reviews.length;
    final self = app.user?.id == widget.userId;

    Widget stat(String v, String label) => Expanded(
          child: Column(children: [
            Text(v, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: p.text)),
            Text(label, style: TextStyle(fontSize: 13, color: p.muted)),
          ]),
        );

    return Scaffold(
      body: Column(children: [
        const SubHeader(title: 'Профиль продавца'),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.line)),
                      child: Column(children: [
                        Avatar(name: name, url: prof?.avatarUrl ?? widget.fromPost?.authorAvatar, size: 72),
                        const SizedBox(height: 8),
                        Text(name, textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19, color: p.text)),
                        const SizedBox(height: 2),
                        Text(
                            '${prof?.city ?? widget.fromPost?.city ?? ''}${prof != null ? ' · на сайте с ${prof!.createdAt.year}' : ''}',
                            style: TextStyle(fontSize: 13, color: p.muted)),
                        if (prof?.verified == true) ...[
                          const SizedBox(height: 8),
                          const VerifiedPill(big: true, text: '✓ Документы проверены'),
                        ],
                        const SizedBox(height: 14),
                        Row(children: [
                          stat(avg == null ? '—' : avg.toStringAsFixed(1), 'рейтинг'),
                          stat('${posts.length}', plural(posts.length, 'объявление', 'объявления', 'объявлений')),
                          stat('${reviews.length}', plural(reviews.length, 'отзыв', 'отзыва', 'отзывов')),
                        ]),
                        if (!self) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: PrimaryButton('Написать в чат', height: 48, icon: 'chat', onPressed: () {
                              if (app.user == null) {
                                askLogin(context, 'Войдите, чтобы переписываться с продавцами.');
                                return;
                              }
                              final fp = widget.fromPost;
                              push(
                                  context,
                                  ChatScreen(
                                    otherId: widget.userId,
                                    otherName: name,
                                    otherAvatar: prof?.avatarUrl,
                                    postId: fp?.id,
                                    postTitle: fp == null ? '' : '${fp.title} · ${priceMain(fp.priceEgp)}',
                                  ));
                            }),
                          ),
                        ],
                      ]),
                    ),
                    if (posts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      const SectionTitle('Объявления продавца'),
                      const SizedBox(height: 8),
                      for (final x in posts) ...[PostCard(post: x), const SizedBox(height: 10)],
                    ],
                    const SizedBox(height: 4),
                    const SectionTitle('Отзывы'),
                    const SizedBox(height: 8),
                    if (reviews.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                        child: Text('Отзывов пока нет. Станьте первым!', style: TextStyle(fontSize: 14, color: p.muted)),
                      ),
                    for (final r in reviews) ...[
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                            color: p.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.line)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                                child: Text(r.author,
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: p.text))),
                            Text('★' * r.stars + '☆' * (5 - r.stars),
                                style: TextStyle(color: p.warn, fontWeight: FontWeight.w600)),
                          ]),
                          if (r.text.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(r.text, style: TextStyle(fontSize: 14, color: p.text2, height: 1.4)),
                          ],
                          const SizedBox(height: 4),
                          Text(dateText(r.date), style: TextStyle(fontSize: 12, color: p.muted)),
                        ]),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (!self) OutlineBtn('Оставить отзыв', onPressed: leaveReview),
                  ],
                ),
        ),
      ]),
    );
  }
}
