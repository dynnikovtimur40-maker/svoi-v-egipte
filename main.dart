import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'data.dart';
import 'features.dart';
import 'i18n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  // Язык: сохранённый выбор, иначе язык телефона (если он у нас есть), иначе русский.
  try {
    final prefs = await SharedPreferences.getInstance();
    final device = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final saved = prefs.getString('lang');
    final code = saved ?? device;
    if (appLanguages.any((l) => l[0] == code)) appLang = code;
  } catch (_) {}
  runApp(const SvoiApp());
}

// =====================================================================
// Палитра: тёмный премиум + светлая тема, цвет акцента выбирается
// =====================================================================

/// Цвета акцента, которые можно выбрать в боковой панели.
const accentOptions = <List<Object>>[
  ['Бирюза', 0xFF14B8A6],
  ['Синий', 0xFF3B82F6],
  ['Индиго', 0xFF6366F1],
  ['Фиолет', 0xFFA855F7],
  ['Коралл', 0xFFF43F5E],
  ['Золото', 0xFFF59E0B],
];

Color accentColor(int i) => Color(accentOptions[i.clamp(0, accentOptions.length - 1)][1] as int);

class Pal {
  Pal._({
    required this.dark,
    required this.primary,
    required this.onPrimary,
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
    required this.warnbg,
    required this.warn,
    required this.okbg,
    required this.ok,
    required this.infobg,
    required this.info,
    required this.bad,
    required this.input,
    required this.hint,
  });

  final bool dark;
  final Color primary, onPrimary, accent;
  final Color bg, card, soft, seg, line, line2, line3, text, text2, muted, body;
  final Color warnbg, warn, okbg, ok, infobg, info, bad, input, hint;

  /// Полупрозрачные варианты.
  Color get sel => primary.withAlpha(dark ? 40 : 26);
  Color get avatar => primary.withAlpha(dark ? 56 : 36);
  Color get brown => muted;
  Color glass([double a = .72]) => bg.withAlpha((a * 255).round());
  Color get glassLine => dark ? const Color(0x1AFFFFFF) : const Color(0x14000000);
  LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(primary, Colors.white, .12)!, Color.lerp(primary, Colors.black, .12)!],
      );

  factory Pal.make(bool dark, Color primary) {
    final onPrimary = primary.computeLuminance() > .5 ? const Color(0xFF15120A) : Colors.white;
    if (dark) {
      return Pal._(
        dark: true,
        primary: primary,
        onPrimary: onPrimary,
        accent: Color.lerp(primary, Colors.white, .22)!,
        bg: const Color(0xFF0B0C10),
        card: const Color(0xFF15171D),
        soft: const Color(0xFF1D2028),
        seg: const Color(0xFF121419),
        line: const Color(0x14FFFFFF),
        line2: const Color(0x24FFFFFF),
        line3: const Color(0x0FFFFFFF),
        text: const Color(0xFFF5F6F8),
        text2: const Color(0xFFC7CBD3),
        muted: const Color(0xFF8B91A0),
        body: const Color(0xFFDCE0E6),
        warnbg: const Color(0xFF2A2210),
        warn: const Color(0xFFFBBF24),
        okbg: const Color(0xFF102A1D),
        ok: const Color(0xFF4ADE80),
        infobg: const Color(0xFF171B33),
        info: const Color(0xFFA5B4FC),
        bad: const Color(0xFFF87171),
        input: const Color(0xFF1A1D24),
        hint: const Color(0xFF6B7180),
      );
    }
    return Pal._(
      dark: false,
      primary: primary,
      onPrimary: onPrimary,
      accent: Color.lerp(primary, Colors.black, .22)!,
      bg: const Color(0xFFF5F6F8),
      card: const Color(0xFFFFFFFF),
      soft: const Color(0xFFF0F1F4),
      seg: const Color(0xFFEBEDF0),
      line: const Color(0xFFE7E9EE),
      line2: const Color(0xFFD9DCE3),
      line3: const Color(0xFFF0F1F4),
      text: const Color(0xFF0F1115),
      text2: const Color(0xFF3A3F4A),
      muted: const Color(0xFF6B7280),
      body: const Color(0xFF262A33),
      warnbg: const Color(0xFFFFF6E6),
      warn: const Color(0xFF8A5A00),
      okbg: const Color(0xFFE7F7EE),
      ok: const Color(0xFF15803D),
      infobg: const Color(0xFFEEF0FF),
      info: const Color(0xFF3730A3),
      bad: const Color(0xFFDC2626),
      input: const Color(0xFFF3F4F6),
      hint: const Color(0xFF9CA3AF),
    );
  }

  static Pal of(BuildContext context) {
    final t = Theme.of(context);
    return Pal.make(t.brightness == Brightness.dark, t.colorScheme.primary);
  }
}

/// Пары «фон / цвет значка» для категорий (используются как оттенки).
const catHues = [0xFF14B8A6, 0xFFF59E0B, 0xFF6366F1, 0xFF22C55E, 0xFFF43F5E, 0xFFA855F7, 0xFF3B82F6];

const sectionHue = {
  Section.ads: 0xFF14B8A6,
  Section.services: 0xFFF59E0B,
  Section.jobs: 0xFF6366F1,
};

Color withAlpha(int argb, double a) =>
    Color(((a * 255).round().clamp(0, 255) << 24) | (argb & 0xFFFFFF));

TextStyle heading(double size, {FontWeight weight = FontWeight.w700, Color? color, double height = 1.25}) =>
    appLang == 'ar'
        ? GoogleFonts.cairo(fontSize: size, fontWeight: weight, color: color, height: height)
        : GoogleFonts.manrope(fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: -.2);

ThemeData buildTheme(Brightness b, Color primary) {
  final p = Pal.make(b == Brightness.dark, primary);
  final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: b).copyWith(
      primary: primary, onPrimary: p.onPrimary, surface: p.card, onSurface: p.text, error: p.bad);
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    splashColor: primary.withAlpha(20),
    highlightColor: primary.withAlpha(10),
    dividerColor: p.line,
  );
  return base.copyWith(
    textTheme: (appLang == 'ar' ? GoogleFonts.cairoTextTheme(base.textTheme) : GoogleFonts.interTextTheme(base.textTheme)).apply(bodyColor: p.text, displayColor: p.text),
    textSelectionTheme: TextSelectionThemeData(cursorColor: primary, selectionColor: primary.withAlpha(70)),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
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
  'calendar': 'M4 6h16v14H4z M4 10h16 M8 3v4 M16 3v4',
  'pyramid': 'M12 3L22 20H2z M12 3l3.5 17',
  'more': 'M5 12h.01 M12 12h.01 M19 12h.01',
  'share': 'M12 3v12 M7 8l5-5 5 5 M5 13v7h14v-7',
  'bell': 'M6 16V11a6 6 0 0 1 12 0v5l2 2H4z M10 20a2 2 0 0 0 4 0',
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
  'Подработка': 'coin',
  'Резюме': 'doc',
  'Удалёнка': 'laptop',
  'Туризм': 'sun',
  'Аренда посуточно': 'calendar',
  'Телефоны': 'phone',
  'Бытовая техника': 'laptop',
  'Мото и скутеры': 'car',
  'Детские товары': 'gift',
  'Спорт и дайвинг': 'sun',
  'Животные': 'heart',
  'Другое': 'grid',
  'Сантехника и электрика': 'tool',
  'Уборка': 'home',
  'Юристы': 'doc',
  'Здоровье': 'heart',
  'Трансфер и такси': 'car',
  'Экскурсии': 'pyramid',
  'IT и компьютеры': 'laptop',
  'Няни': 'people',
  'Отели и рестораны': 'bag',
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
    final paint = CustomPaint(
      size: Size.square(size),
      painter: _IcoPainter(ic[name] ?? ic['tag']!, color ?? Pal.of(context).text, stroke, fill),
    );
    // Стрелки зеркалим для языков справа налево
    if ((name == 'back' || name == 'chevron' || name == 'send') && Directionality.of(context) == TextDirection.rtl) {
      return Transform.flip(flipX: true, child: paint);
    }
    return paint;
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
// Общие элементы интерфейса
// =====================================================================

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// Матовое стекло: размытие того, что под ним.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = 0, this.opacity = .72, this.blur = 22, this.border = true, this.padding, this.color});
  final Widget child;
  final double radius;
  final double opacity;
  final double blur;
  final bool border;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final br = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? p.glass(opacity),
            borderRadius: br,
            border: border ? Border.all(color: p.glassLine) : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Мягкое цветное свечение на фоне (цвет акцента).
class GlowBackground extends StatelessWidget {
  const GlowBackground({super.key, required this.child, this.strong = false});
  final Widget child;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final a1 = p.dark ? (strong ? 90 : 60) : (strong ? 60 : 38);
    final second = Color.lerp(p.primary, const Color(0xFF6366F1), .55)!;
    return Stack(children: [
      Positioned.fill(child: ColoredBox(color: p.bg)),
      // фон рисуется один раз и не перерисовывается при прокрутке
      Positioned(
        top: -160,
        left: -120,
        child: _blob(p.primary.withAlpha(a1), 420),
      ),
      Positioned(
        top: -60,
        right: -160,
        child: _blob(second.withAlpha((a1 * .7).round()), 380),
      ),
      if (strong)
        Positioned(
          bottom: -200,
          left: -80,
          child: _blob(p.primary.withAlpha((a1 * .6).round()), 420),
        ),
      Positioned.fill(child: RepaintBoundary(child: child)),
    ]);
  }

  Widget _blob(Color c, double size) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [c, c.withAlpha(0)]),
          ),
        ),
      );
}

void toast(BuildContext context, String text) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xF01C1F27),
    elevation: 0,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0x1FFFFFFF))),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    duration: const Duration(milliseconds: 2400),
  ));
}

Future<T?> push<T>(BuildContext context, Widget page) =>
    Navigator.push<T>(context, MaterialPageRoute(builder: (_) => page));

Future<T?> showGlassSheet<T>(BuildContext context, WidgetBuilder builder) {
  final p = Pal.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8C000000),
    builder: (ctx) => Glass(
      radius: 28,
      opacity: p.dark ? .86 : .92,
      blur: 28,
      child: builder(ctx),
    ),
  );
}

/// Просим войти: закрываем все экраны и показываем вход.
Future<void> askLogin(BuildContext context, String why) async {
  final p = Pal.of(context);
  final go = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x8C000000),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Glass(
        radius: 24,
        opacity: p.dark ? .88 : .95,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(gradient: p.primaryGradient, borderRadius: BorderRadius.circular(14)),
            child: Ico('user', size: 24, color: p.onPrimary),
          ),
          const SizedBox(height: 14),
          Text('Нужен вход', style: heading(20, weight: FontWeight.w800, color: p.text)),
          const SizedBox(height: 6),
          Text(why, style: TextStyle(fontSize: 15, color: p.text2, height: 1.45)),
          const SizedBox(height: 18),
          PrimaryButton('Войти', height: 48, onPressed: () => Navigator.pop(ctx, true)),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: p.muted, minimumSize: const Size.fromHeight(44)),
            child: const Text('Не сейчас'),
          ),
        ]),
      ),
    ),
  );
  if (go == true && context.mounted) {
    final app = AppScope.of(context);
    Navigator.of(context).popUntil((r) => r.isFirst);
    app.setGuest(false);
  }
}

Future<bool> confirmDialog(BuildContext context, String title, String text, String yes, {bool danger = true}) async {
  final p = Pal.of(context);
  final r = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x8C000000),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Glass(
        radius: 24,
        opacity: p.dark ? .88 : .95,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: heading(19, weight: FontWeight.w800, color: p.text)),
          const SizedBox(height: 6),
          Text(text, style: TextStyle(fontSize: 15, color: p.text2, height: 1.45)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlineBtn('Отмена', color: p.text, onPressed: () => Navigator.pop(ctx, false))),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: danger ? p.bad : p.primary,
                    foregroundColor: danger ? Colors.white : p.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  child: Text(yes),
                ),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
  return r == true;
}

class Box extends StatelessWidget {
  const Box({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.radius = 18, this.color, this.onTap});
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
  const PrimaryButton(this.label, {super.key, required this.onPressed, this.busy = false, this.height = 50, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final double height;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled || busy ? 1 : .5,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: p.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: p.primary.withAlpha(p.dark ? 70 : 60), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Center(
              child: busy
                  ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: p.onPrimary))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      if (icon != null) ...[Ico(icon!, size: 19, color: p.onPrimary), const SizedBox(width: 8)],
                      Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.onPrimary)),
                    ]),
            ),
          ),
        ),
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
          backgroundColor: p.soft,
          side: BorderSide(color: p.line),
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
    borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));

InputDecoration fieldDecoration(Pal p, {String? hint, Widget? suffix, bool enabled = true}) =>
    InputDecoration(
      hintText: hint == null ? null : tr(hint),
      hintStyle: TextStyle(color: p.hint, fontSize: 15),
      isDense: true,
      filled: true,
      fillColor: enabled ? p.input : p.seg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      suffixIcon: suffix,
      border: _border(p.line),
      enabledBorder: _border(p.line),
      disabledBorder: _border(Colors.transparent),
      focusedBorder: _border(p.primary, 1.6),
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
      Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(label, style: TextStyle(fontSize: 13, color: p.muted, fontWeight: FontWeight.w600)),
      ),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: obscure ? 1 : maxLines,
        minLines: maxLines > 1 ? maxLines : null,
        obscureText: obscure,
        validator: validator == null
            ? null
            : (v) {
                final r = validator!(v);
                return r == null ? null : tr(r);
              },
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
      Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(label, style: TextStyle(fontSize: 13, color: p.muted, fontWeight: FontWeight.w600)),
      ),
      const SizedBox(height: 6),
      Material(
        color: p.input,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: p.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final v = await pickOption(context, label, options, value);
            if (v != null) onChanged(v);
          },
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
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
  return showGlassSheet<String>(
    context,
    (ctx) {
      final p = Pal.of(ctx);
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .75),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(title, style: heading(18, weight: FontWeight.w800, color: p.text)),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(10, 0, 10, 14), children: [
                for (final o in options)
                  OptionRow(label: o, selected: o == current, onTap: () => Navigator.pop(ctx, o)),
              ]),
            ),
          ]),
        ),
      );
    },
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
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 15, color: selected ? p.accent : p.text, fontWeight: selected ? FontWeight.w700 : FontWeight.w500))),
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
          margin: const EdgeInsets.only(top: 10, bottom: 10),
          width: 38,
          height: 4,
          decoration: BoxDecoration(color: Pal.of(context).line2, borderRadius: BorderRadius.circular(2)),
        ),
      );
}

class Toggle extends StatelessWidget {
  const Toggle({super.key, required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 46,
      height: 28,
      padding: const EdgeInsets.all(3),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(color: value ? p.primary : p.line2, borderRadius: BorderRadius.circular(14)),
      child: Container(
          width: 22, height: 22, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
    );
  }
}

class Segments<T> extends StatelessWidget {
  const Segments({super.key, required this.values, required this.labels, required this.selected, required this.onChanged, this.icons});
  final List<T> values;
  final List<String> labels;
  final List<String>? icons;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.seg, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.line)),
      child: Row(children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(values[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: values[i] == selected ? (p.dark ? p.soft : p.card) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: values[i] == selected
                      ? [BoxShadow(color: Colors.black.withAlpha(p.dark ? 60 : 18), blurRadius: 6, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icons != null) ...[
                    Ico(icons![i], size: 16, color: values[i] == selected ? p.accent : p.muted),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: values[i] == selected ? p.text : p.muted)),
                  ),
                ]),
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
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(big ? 12 : 8)),
        child: Text(text, style: TextStyle(fontSize: big ? 13 : 12, color: fg, fontWeight: FontWeight.w600, height: 1.2)),
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
          style: TextStyle(fontSize: size * .4, fontWeight: FontWeight.w800, color: fg ?? p.accent)),
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
      padding: const EdgeInsets.fromLTRB(4, 10, 0, 0),
      child: Row(children: [
        Expanded(child: Text(text, style: heading(17, weight: FontWeight.w800, color: p.text))),
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
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: p.sel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: p.primary.withAlpha(50)),
          ),
          child: Center(child: Ico(icon, size: 32, color: p.accent, stroke: 1.8)),
        ),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: p.muted, height: 1.5)),
        if (action != null) ...[
          const SizedBox(height: 18),
          SizedBox(width: 240, child: PrimaryButton(action!, onPressed: onAction, height: 48)),
        ],
      ]),
    );
  }
}

/// Круглая кнопка-значок. glass = на стекле поверх фото.
class IconBtn extends StatelessWidget {
  const IconBtn(this.icon, {super.key, required this.onTap, this.label, this.color, this.fill, this.size = 20, this.box = 40, this.glass = false, this.plain = false});
  final String icon;
  final VoidCallback? onTap;
  final String? label;
  final Color? color;
  final Color? fill;
  final double size;
  final double box;
  final bool glass;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final ico = Center(child: Ico(icon, size: size, color: color ?? p.text, stroke: icon == 'more' ? 3.6 : 2, fill: fill));
    Widget body;
    if (plain) {
      body = SizedBox(width: box, height: box, child: ico);
    } else if (glass) {
      body = SizedBox(
        width: box,
        height: box,
        child: Glass(radius: box / 2, opacity: p.dark ? .55 : .7, blur: 16, child: ico),
      );
    } else {
      body = Container(
        width: box,
        height: box,
        decoration: BoxDecoration(color: p.soft, shape: BoxShape.circle, border: Border.all(color: p.line)),
        child: ico,
      );
    }
    return Semantics(
      button: true,
      label: label == null ? null : tr(label!),
      child: GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: body),
    );
  }
}

/// Шапка внутренних экранов: «назад» + заголовок.
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
        maxLines: 1, overflow: TextOverflow.ellipsis, style: heading(18, weight: FontWeight.w800, color: p.text));
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8 + top, 12, 8),
      decoration: BoxDecoration(color: p.bg, border: Border(bottom: BorderSide(color: p.line3))),
      child: Row(children: [
        IconBtn(leading, onTap: () => Navigator.maybePop(context), label: leading == 'close' ? 'Закрыть' : 'Назад'),
        const SizedBox(width: 12),
        Expanded(child: center ? Center(child: titleW) : titleW),
        const SizedBox(width: 8),
        trailing ?? const SizedBox(width: 40),
      ]),
    );
  }
}

/// Логотип: пирамида на градиенте акцента.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: p.primaryGradient,
        borderRadius: BorderRadius.circular(size * .3),
        boxShadow: [BoxShadow(color: p.primary.withAlpha(90), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Center(child: Ico('pyramid', size: size * .56, color: p.onPrimary, stroke: 2, fill: p.onPrimary.withAlpha(60))),
    );
  }
}

class DashedBorder extends CustomPainter {
  DashedBorder(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius((Offset.zero & size).deflate(1), const Radius.circular(16));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
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

Future<void> openUrl(BuildContext context, String url, String fallbackCopy) async {
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && context.mounted) {
    Clipboard.setData(ClipboardData(text: fallbackCopy));
    toast(context, tr('Не удалось открыть. Контакт скопирован: {c}', {'c': fallbackCopy}));
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
          key: ValueKey(state.lang),
          title: tr('Свои в Египте'),
          debugShowCheckedModeBanner: false,
          locale: Locale(state.lang),
          supportedLocales: [for (final l in appLanguages) Locale(l[0])],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildTheme(Brightness.light, accentColor(state.accent)),
          darkTheme: buildTheme(Brightness.dark, accentColor(state.accent)),
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
    app.loadRates();
    app.loadNews();
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
  bool good = false;
  bool needConfirm = false;
  bool agree = false;
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
    if (l.contains('not confirmed')) return 'Почта ещё не подтверждена. Откройте письмо и нажмите ссылку.';
    if (l.contains('invalid login')) return 'Неверная почта или пароль';
    if (l.contains('already registered') || l.contains('already been registered')) {
      return 'Эта почта уже зарегистрирована — войдите';
    }
    if (l.contains('password should be')) return 'Пароль должен быть не короче 6 символов';
    if (l.contains('invalid') && l.contains('email')) return 'Проверьте адрес почты';
    if (l.contains('rate limit')) return 'Слишком много попыток, подождите минуту';
    return m;
  }

  void say(String m, {bool ok = false}) => setState(() {
        message = m;
        good = ok;
      });

  Future<void> submit() async {
    final e = email.text.trim();
    final p = pass.text;
    if (register && !agree) {
      say('Чтобы зарегистрироваться, примите правила и политику конфиденциальности');
      return;
    }
    if (!e.contains('@') || p.length < 6 || (register && name.text.trim().isEmpty)) {
      say(register ? 'Заполните имя, почту и пароль (от 6 символов)' : 'Введите почту и пароль (от 6 символов)');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    final auth = Supabase.instance.client.auth;
    try {
      if (register) {
        final res = await auth.signUp(
            email: e, password: p, data: {'name': name.text.trim()}, emailRedirectTo: siteUrl);
        if (res.session == null && mounted) {
          setState(() {
            register = false;
            needConfirm = true;
          });
          say(tr('Мы отправили письмо на {e}. Откройте его и нажмите ссылку «Подтвердить», затем войдите здесь.', {'e': e}), ok: true);
        }
      } else {
        await auth.signInWithPassword(email: e, password: p);
      }
    } on AuthException catch (err) {
      if (mounted) {
        if (err.message.toLowerCase().contains('not confirmed')) setState(() => needConfirm = true);
        say(translate(err.message));
      }
    } catch (_) {
      if (mounted) say('Нет связи с сервером, попробуйте ещё раз');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> resetPassword() async {
    final e = email.text.trim();
    if (!e.contains('@')) {
      say('Введите почту, и мы пришлём ссылку для сброса пароля');
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(e, redirectTo: siteUrl);
      if (mounted) say('Письмо для сброса пароля отправлено', ok: true);
    } catch (_) {
      if (mounted) say('Не удалось отправить письмо, попробуйте позже');
    }
  }

  Future<void> resend() async {
    final e = email.text.trim();
    if (!e.contains('@')) {
      say('Введите почту, на которую регистрировались');
      return;
    }
    try {
      await Supabase.instance.client.auth.resend(type: OtpType.signup, email: e, emailRedirectTo: siteUrl);
      if (mounted) say(tr('Письмо отправлено повторно на {e}. Проверьте также папку «Спам».', {'e': e}), ok: true);
    } on AuthException catch (err) {
      if (mounted) say(translate(err.message));
    } catch (_) {
      if (mounted) say('Не удалось отправить письмо, попробуйте позже');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final mq = MediaQuery.of(context);
    return Scaffold(
      body: GlowBackground(
        strong: true,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 24 + mq.padding.top, 20, 24 + mq.padding.bottom),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Center(child: AppLogo(size: 64)),
                const SizedBox(height: 18),
                Text('Свои в Египте',
                    textAlign: TextAlign.center, style: heading(30, weight: FontWeight.w800, color: p.text, height: 1.1)),
                const SizedBox(height: 8),
                Text('Объявления, услуги, работа и новости\nдля русскоязычных в Египте',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.45, color: p.muted)),
                const SizedBox(height: 26),
                Glass(
                  radius: 26,
                  opacity: p.dark ? .6 : .8,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: AutofillGroup(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Segments<bool>(
                        values: const [false, true],
                        labels: const ['Вход', 'Регистрация'],
                        selected: register,
                        onChanged: (v) => setState(() {
                          register = v;
                          message = null;
                        }),
                      ),
                      const SizedBox(height: 16),
                      if (register) ...[
                        Field(label: 'Ваше имя', controller: name, hint: 'Например: Тимур', capitalization: TextCapitalization.words),
                        const SizedBox(height: 12),
                      ],
                      Field(
                          label: 'Электронная почта',
                          controller: email,
                          hint: 'name@mail.com',
                          keyboard: TextInputType.emailAddress,
                          autocorrect: false),
                      const SizedBox(height: 12),
                      Field(
                        label: 'Пароль',
                        controller: pass,
                        hint: 'Не короче 6 символов',
                        obscure: hide,
                        autocorrect: false,
                        onSubmitted: (_) => submit(),
                        suffix: IconButton(
                          onPressed: () => setState(() => hide = !hide),
                          icon: Ico(hide ? 'eye' : 'eyeOff', size: 20, color: p.muted),
                        ),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: good ? p.okbg : p.warnbg, borderRadius: BorderRadius.circular(12)),
                          child: Text(message!,
                              style: TextStyle(color: good ? p.ok : p.warn, fontSize: 14, height: 1.4)),
                        ),
                      ],
                      if (register) ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => setState(() => agree = !agree),
                          behavior: HitTestBehavior.opaque,
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 22,
                              height: 22,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                color: agree ? p.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: agree ? p.primary : p.line2, width: 1.6),
                              ),
                              child: agree ? Center(child: Ico('check', size: 14, stroke: 3, color: p.onPrimary)) : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Wrap(children: [
                                Text('Я принимаю ', style: TextStyle(fontSize: 13.5, color: p.text2, height: 1.4)),
                                GestureDetector(
                                  onTap: () => push(context, const PolicyScreen()),
                                  child: Text('правила сервиса и политику конфиденциальности',
                                      style: TextStyle(
                                          fontSize: 13.5, color: p.accent, height: 1.4, fontWeight: FontWeight.w600)),
                                ),
                              ]),
                            ),
                          ]),
                        ),
                      ],
                      if (needConfirm && !register)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: resend,
                            style: TextButton.styleFrom(foregroundColor: p.accent),
                            child: const Text('Отправить письмо ещё раз', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      const SizedBox(height: 16),
                      PrimaryButton(register ? 'Зарегистрироваться' : 'Войти', busy: busy, onPressed: submit),
                      if (!register)
                        TextButton(
                          onPressed: resetPassword,
                          style: TextButton.styleFrom(foregroundColor: p.muted, minimumSize: const Size.fromHeight(42)),
                          child: const Text('Забыли пароль?', style: TextStyle(fontSize: 14)),
                        )
                      else
                        const SizedBox(height: 8),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                OutlineBtn('Пропустить, просто посмотреть',
                    height: 50, color: p.text, onPressed: () => AppScope.of(context).setGuest(true)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Каркас: разделы + боковая панель
// =====================================================================

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  static bool _linkHandled = false;

  @override
  void initState() {
    super.initState();
    // ссылка вида …/svoi-v-egipte/?post=<id> открывает объявление
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_linkHandled) return;
      _linkHandled = true;
      final id = Uri.base.queryParameters['post'];
      if (id == null || id.isEmpty || !mounted) return;
      final post = await AppScope.of(context).fetchPost(id);
      if (!mounted) return;
      if (post == null) {
        toast(context, 'Объявление снято с публикации или удалено.');
      } else {
        push(context, PostDetailScreen(post: post));
      }
    });
  }

  static const pages = <Widget>[
    ListTab(section: Section.ads),
    ListTab(section: Section.services),
    ListTab(section: Section.jobs),
    NewsTab(),
    MoreTab(),
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
    final p = Pal.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      drawer: AppDrawer(tab: tab, onSelect: (i) => setState(() => tab = i)),
      drawerEdgeDragWidth: 28,
      drawerScrimColor: const Color(0x73000000),
      body: GlowBackground(child: IndexedStack(index: tab, children: pages)),
      floatingActionButton: tab <= 2
          ? Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: p.primaryGradient,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [BoxShadow(color: p.primary.withAlpha(110), blurRadius: 22, offset: const Offset(0, 8))],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(26),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: openAdd,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Ico('plus', size: 20, color: p.onPrimary, stroke: 2.4),
                      const SizedBox(width: 8),
                      Text('Разместить',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.onPrimary)),
                    ]),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

/// Кнопка «≡», открывает боковую панель.
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    return Stack(clipBehavior: Clip.none, children: [
      IconBtn('menu', label: 'Меню', onTap: () => Scaffold.of(context).openDrawer()),
      if (app.unreadTotal > 0)
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(color: const Color(0xFFF43F5E), shape: BoxShape.circle, border: Border.all(color: p.bg, width: 2)),
          ),
        ),
    ]);
  }
}

/// Боковая панель: разделы, личный кабинет, оформление.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.tab, required this.onSelect});
  final int tab;
  final ValueChanged<int> onSelect;

  static const sections = [
    ['Объявления', 'tag'],
    ['Услуги', 'tool'],
    ['Работа', 'bag'],
    ['Новости', 'news'],
    ['Полезное', 'coin'],
  ];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final logged = app.user != null;
    final mq = MediaQuery.of(context);

    void close() => Navigator.of(context).pop();
    void open(Widget page, String why) {
      close();
      if (logged) {
        push(context, page);
      } else {
        askLogin(context, why);
      }
    }

    Widget item(String icon, String label, {bool selected = false, VoidCallback? onTap, String? badge, bool danger = false}) {
      final fg = danger ? p.bad : (selected ? p.text : p.text2);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        child: Material(
          color: selected ? p.sel : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 46,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  Ico(icon, size: 20, color: danger ? p.bad : (selected ? p.accent : p.muted), stroke: 1.9),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, color: fg, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                  ),
                  if (badge != null)
                    Container(
                      constraints: const BoxConstraints(minWidth: 22),
                      height: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(11)),
                      child: Center(
                          child: Text(badge, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.onPrimary))),
                    ),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    Widget label(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 16, 6),
          child: Text(tr(t).toUpperCase(),
              style: TextStyle(fontSize: 11.5, color: p.muted, fontWeight: FontWeight.w700, letterSpacing: .8)),
        );

    final mode = app.themeMode;

    return Drawer(
      width: 312,
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadiusDirectional.horizontal(end: Radius.circular(28))),
      clipBehavior: Clip.antiAlias,
      child: Glass(
        opacity: p.dark ? .8 : .9,
        blur: 30,
        border: false,
        child: Container(
          decoration: BoxDecoration(border: BorderDirectional(end: BorderSide(color: p.glassLine))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(height: mq.padding.top + 14),
            // Логотип
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const AppLogo(size: 36),
                const SizedBox(width: 10),
                Text('Свои в Египте', style: heading(17, weight: FontWeight.w800, color: p.text)),
              ]),
            ),
            const SizedBox(height: 14),
            // Карточка пользователя
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Material(
                color: p.dark ? const Color(0x0FFFFFFF) : const Color(0x08000000),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: p.glassLine)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    if (logged) {
                      open(const ProfileScreen(), '');
                    } else {
                      close();
                      app.setGuest(false);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Avatar(name: logged ? app.userName : '?', url: app.profile?.avatarUrl, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(logged ? app.userName : 'Гость',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: p.text)),
                          const SizedBox(height: 2),
                          Text(logged ? '${tr('Мой профиль')} · ${tr(app.profile?.city ?? 'Каир')}' : 'Войти или зарегистрироваться',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: logged ? p.muted : p.accent, fontWeight: FontWeight.w500)),
                        ]),
                      ),
                      Ico('chevron', size: 16, color: p.muted),
                    ]),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(padding: EdgeInsets.zero, children: [
                label('Разделы'),
                for (var i = 0; i < sections.length; i++)
                  item(sections[i][1], sections[i][0], selected: tab == i, onTap: () {
                    onSelect(i);
                    close();
                  }),
                item('pyramid', 'Путеводитель', onTap: () {
                  close();
                  push(context, const GuideScreen());
                }),
                label('Личный кабинет'),
                item('doc', 'Мои объявления',
                    badge: logged && app.myPosts.isNotEmpty ? '${app.myPosts.length}' : null,
                    onTap: () => open(const MyAdsScreen(), 'Войдите, чтобы видеть свои объявления.')),
                item('heart', 'Избранное',
                    badge: app.favorites.isNotEmpty ? '${app.favorites.length}' : null,
                    onTap: () => open(const FavoritesScreen(), 'Войдите, чтобы сохранять избранное.')),
                item('chat', 'Сообщения',
                    badge: app.unreadTotal > 0 ? '${app.unreadTotal}' : null,
                    onTap: () => open(const ChatsScreen(), 'Войдите, чтобы переписываться.')),
                item('shield', 'Проверка профиля',
                    badge: app.profile?.verified == true ? '✓' : null,
                    onTap: () => open(const VerifyScreen(), 'Войдите, чтобы пройти проверку.')),
                if (app.isAdmin) ...[
                  label('Администратор'),
                  item('shield', 'Модерация', onTap: () {
                    close();
                    push(context, const ModerationScreen());
                  }),
                ],
                label('О сервисе'),
                item('doc', 'Правила и конфиденциальность', onTap: () {
                  close();
                  push(context, const PolicyScreen());
                }),
                label('Оформление'),
                item('globe', '${tr('Язык')} · ${langName(app.lang)}', onTap: () {
                  close();
                  showLanguageSheet(context);
                }),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Segments<ThemeMode>(
                    values: const [ThemeMode.dark, ThemeMode.light, ThemeMode.system],
                    labels: const ['Тёмная', 'Светлая', 'Система'],
                    icons: const ['moon', 'sun', 'palette'],
                    selected: mode,
                    onChanged: app.setTheme,
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    for (var i = 0; i < accentOptions.length; i++)
                      Semantics(
                        button: true,
                        selected: app.accent == i,
                        label: '${tr('Цвет')}: ${tr('${accentOptions[i][0]}')}',
                        child: GestureDetector(
                          onTap: () => app.setAccent(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 36,
                            height: 36,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: app.accent == i ? p.text : Colors.transparent, width: 2),
                            ),
                            child: Container(
                              decoration: BoxDecoration(color: accentColor(i), shape: BoxShape.circle),
                              child: app.accent == i
                                  ? Center(
                                      child: Ico('check',
                                          size: 16,
                                          stroke: 3,
                                          color: accentColor(i).computeLuminance() > .5 ? Colors.black : Colors.white))
                                  : null,
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 16, 8),
                  child: Text('${tr('Цвет')}: ${tr('${accentOptions[app.accent][0]}')}', style: TextStyle(fontSize: 12.5, color: p.muted)),
                ),
              ]),
            ),
            Divider(height: 1, color: p.line),
            Padding(
              padding: EdgeInsets.fromLTRB(0, 6, 0, 8 + mq.padding.bottom),
              child: logged
                  ? item('logout', 'Выйти', danger: true, onTap: () async {
                      close();
                      await app.signOut();
                    })
                  : item('user', 'Войти или зарегистрироваться', onTap: () {
                      close();
                      app.setGuest(false);
                    }),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Прозрачная (стеклянная) шапка разделов.
class GlassBar extends StatelessWidget {
  const GlassBar({super.key, required this.title, this.subtitle, this.trailing, this.bottom});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final top = MediaQuery.of(context).padding.top;
    return Glass(
      opacity: p.dark ? .62 : .75,
      border: false,
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.glassLine))),
        padding: EdgeInsets.fromLTRB(16, top + 10, 16, bottom == null ? 12 : 10),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const MenuButton(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: heading(21, weight: FontWeight.w800, color: p.text)),
                if (subtitle != null)
                  Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: p.muted)),
              ]),
            ),
            if (trailing != null) trailing!,
          ]),
          if (bottom != null) ...[const SizedBox(height: 12), bottom!],
        ]),
      ),
    );
  }
}

/// Список под стеклянной шапкой: контент прокручивается под ней.
class UnderBar extends StatefulWidget {
  const UnderBar({super.key, required this.bar, required this.slivers, this.onRefresh});
  final Widget bar;
  final List<Widget> slivers;
  final RefreshCallback? onRefresh;

  @override
  State<UnderBar> createState() => _UnderBarState();
}

class _UnderBarState extends State<UnderBar> {
  final key = GlobalKey();
  double barH = 120;

  void measure() {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && (box.size.height - barH).abs() > .5) {
      setState(() => barH = box.size.height);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) measure();
    });
    final p = Pal.of(context);
    Widget scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      cacheExtent: 800,
      slivers: [SliverToBoxAdapter(child: SizedBox(height: barH)), ...widget.slivers],
    );
    if (widget.onRefresh != null) {
      scroll = RefreshIndicator(
        color: p.primary,
        backgroundColor: p.card,
        edgeOffset: barH,
        onRefresh: widget.onRefresh!,
        child: scroll,
      );
    }
    return Stack(children: [
      Positioned.fill(child: scroll),
      Positioned(top: 0, left: 0, right: 0, child: KeyedSubtree(key: key, child: widget.bar)),
    ]);
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
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void onQuery(String v) {
    setState(() => query = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) AppScope.of(context).searchRemote(v);
    });
  }

  Future<void> subscribe() async {
    final app = AppScope.of(context);
    await subscribeToSearch(context,
        section: widget.section,
        category: cat,
        city: app.city == cities.first ? null : app.city,
        query: query,
        priceMax: filters.priceTo);
  }

  Future<void> pickCity() async {
    final app = AppScope.of(context);
    final v = await pickOption(context, 'Ваш город', cities, app.city);
    if (v != null) app.setCity(v);
  }

  Future<void> openFilters() async {
    final app = AppScope.of(context);
    final tmp = Filters()
      ..sort = filters.sort
      ..priceFrom = filters.priceFrom
      ..priceTo = filters.priceTo
      ..verifiedOnly = filters.verifiedOnly;
    final from = TextEditingController(text: filters.priceFrom?.toString() ?? '');
    final to = TextEditingController(text: filters.priceTo?.toString() ?? '');
    final ok = await showGlassSheet<bool>(
      context,
      (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final p = Pal.of(ctx);
        final n = app.filter(widget.section, cat, query, tmp).length;
        Widget sortChip(SortMode m, String label) {
          final on = tmp.sort == m;
          return GestureDetector(
            onTap: () => setSheet(() => tmp.sort = m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? p.primary : p.soft,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: on ? p.primary : p.line),
              ),
              child: Text(label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: on ? p.onPrimary : p.text)),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
              18, 0, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SheetHandle(),
            Row(children: [
              Expanded(child: Text('Фильтры', style: heading(20, weight: FontWeight.w800, color: p.text))),
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
            const SizedBox(height: 12),
            Text('Сортировка', style: TextStyle(fontSize: 13, color: p.muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              sortChip(SortMode.fresh, 'Сначала новые'),
              sortChip(SortMode.cheap, 'Дешевле'),
              sortChip(SortMode.expensive, 'Дороже'),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: Field(
                  label: widget.section == Section.jobs ? 'Зарплата от, EGP' : 'Цена от, EGP',
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
              color: p.soft,
              onTap: () => setSheet(() => tmp.verifiedOnly = !tmp.verifiedOnly),
              child: Row(children: [
                Ico('shield', size: 20, color: p.ok),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Только проверенные продавцы', style: TextStyle(fontSize: 15, color: p.text)),
                    const SizedBox(height: 2),
                    Text('Объявления проходят модерацию всегда. Этот фильтр оставляет авторов, подтвердивших Telegram.',
                        style: TextStyle(fontSize: 12, color: p.muted, height: 1.35)),
                  ]),
                ),
                Toggle(value: tmp.verifiedOnly),
              ]),
            ),
            const SizedBox(height: 18),
            PrimaryButton(tr('Показать {n}', {'n': '$n ${adsWord(n)}'}),
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
    final title = sectionNames[widget.section]!;

    final cityChip = GestureDetector(
      onTap: pickCity,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Ico('pin', size: 15, color: p.accent),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 104),
            child: Text(app.city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.text)),
          ),
          const SizedBox(width: 2),
          Ico('down', size: 14, color: p.muted),
        ]),
      ),
    );

    final search = Row(children: [
      Expanded(
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: p.input.withAlpha(p.dark ? 220 : 255), borderRadius: BorderRadius.circular(14), border: Border.all(color: p.line)),
          child: Row(children: [
            Ico('search', size: 18, color: p.muted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                onChanged: onQuery,
                style: TextStyle(fontSize: 15, color: p.text),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration.collapsed(
                  hintText: tr(searchHints[widget.section]!),
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
        label: tr('Подписаться на поиск'),
        child: GestureDetector(
          onTap: subscribe,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.input.withAlpha(p.dark ? 220 : 255),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.line),
            ),
            child: Center(child: Ico('bell', size: 20, color: p.text)),
          ),
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: openFilters,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: filters.active ? p.primaryGradient : null,
            color: filters.active ? null : p.input.withAlpha(p.dark ? 220 : 255),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: filters.active ? Colors.transparent : p.line),
          ),
          child: Center(child: Ico('filter', size: 20, color: filters.active ? p.onPrimary : p.text)),
        ),
      ),
    ]);

    final chips = SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: catNames.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = catNames[i];
          final on = cat == c;
          final name = c ?? 'Все';
          final hue = Color(catHues[i % catHues.length]);
          return GestureDetector(
            onTap: () => setState(() => cat = c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: on ? p.primaryGradient : null,
                color: on ? null : p.soft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: on ? Colors.transparent : p.line),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Ico(catIcon[name] ?? 'tag', size: 16, stroke: 2, color: on ? p.onPrimary : hue),
                const SizedBox(width: 6),
                Text(name,
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600, color: on ? p.onPrimary : p.text)),
              ]),
            ),
          );
        },
      ),
    );

    final bar = GlassBar(
      title: title,
      subtitle: 'Свои в Египте',
      trailing: cityChip,
      bottom: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [search, const SizedBox(height: 10), chips]),
    );

    final slivers = <Widget>[
      if (app.loading && app.posts.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
        ),
      if (app.error != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.warnbg, borderRadius: BorderRadius.circular(14)),
              child: Text(app.error!, style: TextStyle(color: p.warn, fontSize: 13, height: 1.45)),
            ),
          ),
        ),
      if (items.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
            child: Text('${items.length} ${adsWord(items.length)}'
                '${app.city != cities.first ? ' · ${tr(app.city)}' : ''}',
                style: TextStyle(fontSize: 13, color: p.muted, fontWeight: FontWeight.w500)),
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
          padding: EdgeInsets.fromLTRB(16, 10, 16, app.hasMore && query.trim().isEmpty ? 16 : 120),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 230,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: .64,
            ),
            delegate: SliverChildBuilderDelegate((_, i) => PostTile(post: items[i]), childCount: items.length),
          ),
        ),
      if (app.hasMore && query.trim().isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            child: OutlineBtn(app.loadingMore ? 'Загружаем…' : 'Показать ещё объявления',
                icon: 'down', onPressed: app.loadingMore ? null : app.loadMore),
          ),
        ),
    ];

    return UnderBar(bar: bar, slivers: slivers, onRefresh: app.load);
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

/// Картинка объявления: фото или градиент со значком.
class PostImage extends StatelessWidget {
  const PostImage({super.key, required this.post, this.iconSize = 40, this.index = 0, this.fit = BoxFit.cover, this.cacheWidth = 480});
  final Post post;
  final double iconSize;
  final int index;
  final BoxFit fit;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final hue = Color(sectionHue[post.section]!);
    final fallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(hue.withAlpha(p.dark ? 70 : 50), p.card),
            Color.alphaBlend(hue.withAlpha(p.dark ? 22 : 18), p.card),
          ],
        ),
      ),
      child: Center(child: Ico(iconForPost(post), size: iconSize, color: Color.lerp(hue, p.text, p.dark ? .15 : .1), stroke: 1.6)),
    );
    if (post.photos.length <= index) return fallback;
    return Image.network(post.photos[index], fit: fit, width: double.infinity, height: double.infinity,
        cacheWidth: cacheWidth, gaplessPlayback: true, errorBuilder: (_, __, ___) => fallback);
  }
}

class PostThumb extends StatelessWidget {
  const PostThumb({super.key, required this.post, this.size = 76, this.height, this.radius = 14, this.iconSize = 30});
  final Post post;
  final double size;
  final double? height;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(width: size, height: height ?? size, child: PostImage(post: post, iconSize: iconSize, cacheWidth: 240)),
      );
}

/// Плитка в ленте: фото + цена + заголовок.
class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final fav = app.favorites.contains(post.id);
    final rating = app.ratings[post.userId];
    return GestureDetector(
      onTap: () => push(context, PostDetailScreen(post: post)),
      behavior: HitTestBehavior.opaque,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: post.isHighlighted
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: post.isVip ? const Color(0xFFF59E0B) : p.accent, width: 2.2),
                    boxShadow: [BoxShadow(color: (post.isVip ? const Color(0xFFF59E0B) : p.accent).withAlpha(70), blurRadius: 14)],
                  )
                : null,
            child: ClipRRect(
            borderRadius: BorderRadius.circular(post.isHighlighted ? 19 : 20),
            child: Stack(children: [
              Positioned.fill(child: PostImage(post: post)),
              if (post.isVip)
                Positioned(
                  left: 8,
                  top: post.photos.length > 1 ? 34 : 8,
                  child: const VipBadge(),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: Semantics(
                  button: true,
                  label: 'В избранное',
                  child: GestureDetector(
                    onTap: () => favOrLogin(context, post.id),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(color: Color(0x73000000), shape: BoxShape.circle),
                      child: Center(
                        child: Ico('heart',
                            size: 18,
                            color: fav ? const Color(0xFFF43F5E) : Colors.white,
                            fill: fav ? const Color(0xFFF43F5E) : null),
                      ),
                    ),
                  ),
                ),
              ),
              if (post.photos.length > 1)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0x8C000000), borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Ico('image', size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('${post.photos.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              if (post.verified)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xD90B2A1A), borderRadius: BorderRadius.circular(10)),
                    child: const Text('✓ Проверен',
                        style: TextStyle(color: Color(0xFF86EFAC), fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                ),
            ]),
          ),
          ),
        ),
        const SizedBox(height: 8),
        Text(priceOf(post),
            maxLines: 1, overflow: TextOverflow.ellipsis, style: heading(16, weight: FontWeight.w800, color: p.text)),
        const SizedBox(height: 2),
        Text(post.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.5, color: p.text2, height: 1.3, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: Text('${tr(post.city)} · ${dateText(post.date)}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.muted)),
          ),
          if (rating != null)
            Text('★ ${rating.toStringAsFixed(1)}',
                style: TextStyle(fontSize: 12, color: p.warn, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

/// Карточка-строка (избранное, объявления продавца).
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final fav = app.favorites.contains(post.id);
    final rating = app.ratings[post.userId];
    final rub = post.section == Section.jobs ? '' : priceRub(post.priceEgp);

    return Box(
      padding: const EdgeInsets.all(10),
      onTap: () => push(context, PostDetailScreen(post: post)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PostThumb(post: post, size: 84),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(priceOf(post), style: heading(16, weight: FontWeight.w800, color: p.text)),
            if (rub.isNotEmpty) Text(rub, style: TextStyle(fontSize: 12, color: p.muted)),
            const SizedBox(height: 3),
            Text(post.title,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: p.text2, height: 1.3)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('${tr(post.city)} · ${tr(post.category)}', style: TextStyle(fontSize: 12, color: p.muted)),
              if (post.verified) const VerifiedPill(),
              if (post.isVip) const VipBadge(),
              if (rating != null)
                Text('★ ${rating.toStringAsFixed(1)}',
                    style: TextStyle(fontSize: 12, color: p.warn, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
        IconBtn('heart',
            plain: true,
            label: 'В избранное',
            onTap: () => favOrLogin(context, post.id),
            color: fav ? const Color(0xFFF43F5E) : p.muted,
            fill: fav ? const Color(0xFFF43F5E) : null),
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

  @override
  void initState() {
    super.initState();
    // просмотр считается раз в сутки от человека; свои не считаются
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).registerEvent(post.id, 'view');
    });
  }

  Future<void> reportPost() async {
    final app = AppScope.of(context);
    if (app.user == null) {
      askLogin(context, 'Войдите, чтобы отправить жалобу модератору.');
      return;
    }
    final reason = await pickOption(context, 'Что не так с объявлением?', reportReasons, '');
    if (reason == null || !mounted) return;
    final r = await app.report(postId: post.id, reason: reason);
    if (!mounted) return;
    toast(context, r == 'ok'
        ? 'Спасибо! Модератор проверит объявление.'
        : r == 'dup'
            ? 'Вы уже жаловались на это объявление.'
            : 'Не удалось отправить. Проверьте интернет.');
  }

  void contact(String kind) {
    final c = post.contact.trim();
    final d = contactDigits(c);
    final tg = telegramUser(c);
    final hasPhone = d.length >= 8;
    final plus = c.contains('+') || d.startsWith('20') ? '+' : '';
    if (kind == 'wa') {
      if (!hasPhone) {
        Clipboard.setData(ClipboardData(text: c));
        toast(context, tr('Номер WhatsApp не указан. Контакт скопирован: {c}', {'c': c}));
        return;
      }
      AppScope.of(context).registerEvent(post.id, 'contact');
      openUrl(context, 'https://wa.me/$d', c);
    } else if (kind == 'tg') {
      AppScope.of(context).registerEvent(post.id, 'contact');
      if (tg != null) {
        openUrl(context, 'https://t.me/$tg', c);
      } else if (hasPhone) {
        openUrl(context, 'https://t.me/+$d', c);
      } else {
        Clipboard.setData(ClipboardData(text: c));
        toast(context, tr('Контакт скопирован: {c}', {'c': c}));
      }
    } else {
      if (!hasPhone) {
        Clipboard.setData(ClipboardData(text: c));
        toast(context, tr('Телефон не указан. Контакт скопирован: {c}', {'c': c}));
        return;
      }
      AppScope.of(context).registerEvent(post.id, 'contact');
      openUrl(context, 'tel:$plus$d', c);
    }
  }

  void openChat() {
    final app = AppScope.of(context);
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
            postTitle: '${post.title} · ${priceOf(post)}'));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final mq = MediaQuery.of(context);
    final fav = app.favorites.contains(post.id);
    final rating = app.ratings[post.userId];
    final mine = app.user?.id == post.userId;
    final since = post.authorSince != null ? ' · ${tr('с {y}', {'y': post.authorSince!.year})}' : '';
    final rub = post.section == Section.jobs ? '' : priceRub(post.priceEgp);
    final count = math.max(1, post.photos.length);
    final galleryH = math.min(mq.size.width, 460.0) * .92 + mq.padding.top;

    final gallery = SizedBox(
      height: galleryH,
      child: Stack(children: [
        PageView.builder(
          itemCount: count,
          onPageChanged: (i) => setState(() => page = i),
          itemBuilder: (_, i) => GestureDetector(
            onTap: post.photos.isEmpty ? null : () => push(context, PhotoViewer(photos: post.photos, start: i)),
            child: PostImage(post: post, index: i, iconSize: 72, cacheWidth: 1200),
          ),
        ),
        // затемнение сверху, чтобы кнопки читались
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 110 + mq.padding.top,
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),
        if (count > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 34,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < count; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color: i == page ? Colors.white : const Color(0x99FFFFFF), borderRadius: BorderRadius.circular(3)),
                ),
            ]),
          ),
      ]),
    );

    Widget chip(String icon, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Ico(icon, size: 14, color: p.muted),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(fontSize: 13, color: p.text2, fontWeight: FontWeight.w500)),
          ]),
        );

    Widget round(String label, Color bg, Color fg, String icon, VoidCallback onTap) => Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
              child: Center(child: icon.isEmpty ? Text(label[0], style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 18)) : Ico(icon, size: 22, color: fg)),
            ),
          ),
        );

    final bottomBar = Glass(
      radius: 24,
      opacity: p.dark ? .7 : .85,
      padding: const EdgeInsets.all(10),
      child: mine
          ? PrimaryButton('Изменить объявление', icon: 'edit', onPressed: () async {
              final changed = await push<bool>(context, AddPostScreen(section: post.section, edit: post));
              if (changed == true && context.mounted) Navigator.pop(context);
            })
          : Row(children: [
              round('Позвонить', p.soft, p.text, 'phoneCall', () => contact('call')),
              const SizedBox(width: 8),
              Expanded(child: PrimaryButton('Написать в чат', icon: 'chat', onPressed: openChat)),
            ]),
    );

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(children: [
        CustomScrollView(slivers: [
          SliverToBoxAdapter(child: gallery),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                decoration: BoxDecoration(
                  color: p.bg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                ),
                padding: EdgeInsets.fromLTRB(18, 20, 18, 110 + mq.padding.bottom),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Flexible(child: Text(priceOf(post), style: heading(26, weight: FontWeight.w800, color: p.text))),
                    if (rub.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(rub, style: TextStyle(fontSize: 14, color: p.muted)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 6),
                  Text(post.title, style: heading(19, weight: FontWeight.w700, color: p.text2, height: 1.3)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    chip('pin', post.city),
                    chip(catIcon[post.category] ?? 'tag', post.category),
                    chip('calendar', dateText(post.date)),
                    chip('eye', tr('{n} просм.', {'n': post.views})),
                    if (post.verified) const VerifiedPill(big: true),
                  ]),
                  const SizedBox(height: 18),
                  Text('Описание', style: heading(16, weight: FontWeight.w800, color: p.text)),
                  const SizedBox(height: 6),
                  Text(post.description.isEmpty ? 'Без описания' : post.description,
                      style: TextStyle(fontSize: 15.5, height: 1.6, color: p.body)),
                  const SizedBox(height: 18),
                  Box(
                    padding: const EdgeInsets.all(12),
                    onTap: () => push(context, SellerScreen(userId: post.userId, name: post.author, fromPost: post)),
                    child: Row(children: [
                      Avatar(name: post.author, url: post.authorAvatar, size: 46),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Flexible(
                              child: Text(post.author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.text)),
                            ),
                            if (post.verified) ...[const SizedBox(width: 6), Ico('shield', size: 15, color: p.ok)],
                          ]),
                          const SizedBox(height: 2),
                          Text(rating != null ? '★ ${rating.toStringAsFixed(1)}$since' : '${tr('Новый продавец')}$since',
                              style: TextStyle(fontSize: 13, color: p.muted)),
                          if (post.authorLastSeen != null)
                            Text(onlineText(post.authorLastSeen),
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: isOnline(post.authorLastSeen) ? p.ok : p.muted,
                                    fontWeight: isOnline(post.authorLastSeen) ? FontWeight.w600 : FontWeight.w400)),
                        ]),
                      ),
                      Text('Контакты', style: TextStyle(fontSize: 13, color: p.accent, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 2),
                      Ico('chevron', size: 16, color: p.accent),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: p.warnbg, borderRadius: BorderRadius.circular(14)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Ico('alert', size: 18, color: p.warn),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Не переводите предоплату до встречи. Выбирайте продавцов с отметкой «Проверен».',
                            style: TextStyle(fontSize: 13, color: p.warn, height: 1.45)),
                      ),
                    ]),
                  ),
                  if (mine) ...[
                    const SizedBox(height: 12),
                    Text(tr('Это ваше объявление. Контакт: {c}', {'c': post.contact}),
                        style: TextStyle(fontSize: 13, color: p.muted)),
                  ] else
                    Center(
                      child: TextButton(
                        onPressed: reportPost,
                        style: TextButton.styleFrom(foregroundColor: p.bad, minimumSize: const Size(0, 44)),
                        child: const Text('Пожаловаться на объявление', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ]),
        Positioned(
          top: mq.padding.top + 10,
          left: 14,
          right: 14,
          child: Row(children: [
            IconBtn('back', glass: true, color: Colors.white, label: 'Назад', onTap: () => Navigator.maybePop(context)),
            const Spacer(),
            IconBtn('share', glass: true, color: Colors.white, label: 'Поделиться', onTap: () => sharePost(context, post)),
            const SizedBox(width: 8),
            IconBtn('heart',
                glass: true,
                label: 'В избранное',
                onTap: () => favOrLogin(context, post.id),
                color: fav ? const Color(0xFFF43F5E) : Colors.white,
                fill: fav ? const Color(0xFFF43F5E) : null),
          ]),
        ),
        Positioned(left: 12, right: 12, bottom: 12 + mq.padding.bottom, child: bottomBar),
      ]),
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
          top: MediaQuery.of(context).padding.top + 10,
          left: 14,
          child: IconBtn('close', glass: true, label: 'Закрыть', color: Colors.white, onTap: () => Navigator.pop(context)),
        ),
      ]),
    );
  }
}
// =====================================================================
// Размещение и редактирование
// =====================================================================

const titleHints = {
  Section.ads: 'Например: Квартира 2 комнаты у моря',
  Section.services: 'Например: Ремонт кондиционеров с выездом',
  Section.jobs: 'Например: Нужен администратор в отель',
};

const descHints = {
  Section.ads: 'Состояние, размеры, что входит, где можно посмотреть',
  Section.services: 'Что делаете, опыт, районы выезда, сроки',
  Section.jobs: 'Обязанности, график, требования, оплата',
};

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
  late final phone = TextEditingController(text: _part(widget.edit?.contact, true));
  late final tg = TextEditingController(text: _part(widget.edit?.contact, false));

  static String _part(String? contact, bool wantPhone) {
    if (contact == null) return '';
    if (wantPhone) {
      final m = RegExp(r'\+?\d[\d\s\-()]{8,}\d').firstMatch(contact);
      return m?.group(0) ?? '';
    }
    final m = RegExp(r'@[A-Za-z][A-Za-z0-9_]{4,31}').firstMatch(contact);
    return m?.group(0) ?? '';
  }

  String? phoneCheck(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return tg.text.trim().isEmpty ? 'Укажите телефон или Telegram' : null;
    return normalizePhone(t) == null ? 'Номер: 10–15 цифр, например +20 100 123 4567' : null;
  }

  String? tgCheck(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    return normalizeTelegram(t) == null ? 'Ник Telegram: латиница, цифры и «_», от 5 символов' : null;
  }
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
    if (e == null && (prof?.phone ?? '').isNotEmpty) phone.text = prof!.phone!;
    if (e == null && (prof?.tgUsername ?? '').isNotEmpty) tg.text = '@${prof!.tgUsername}';
  }

  @override
  void dispose() {
    for (final c in [title, desc, price, phone, tg]) {
      c.dispose();
    }
    super.dispose();
  }

  String? notEmpty(String? v) => (v == null || v.trim().isEmpty) ? tr('Заполните поле') : null;

  /// Байты фото, загруженных в этом окне (чтобы не скачивать их снова для редактирования).
  final Map<String, Uint8List> _bytes = {};

  Future<void> photoActions(int i) async {
    final act = await pickOption(context, tr('Фото {n}', {'n': i + 1}),
        [if (i > 0) 'Сделать главным', 'Обрезать и повернуть', 'Удалить фото'], '');
    if (act == null || !mounted) return;
    if (act == 'Сделать главным') {
      setState(() => photos.insert(0, photos.removeAt(i)));
    } else if (act == 'Удалить фото') {
      setState(() => photos.removeAt(i));
    } else {
      final app = AppScope.of(context);
      final url = photos[i];
      try {
        setState(() => uploading = true);
        final src = _bytes[url] ?? await app.downloadPhoto(url);
        if (!mounted) return;
        setState(() => uploading = false);
        final out = await push<Uint8List>(context, PhotoEditor(bytes: src));
        if (out == null || !mounted) return;
        setState(() => uploading = true);
        final nu = await app.uploadImage(out, 'post');
        _bytes[nu] = out;
        if (mounted) setState(() => photos[i] = nu);
      } catch (_) {
        if (mounted) toast(context, 'Не удалось открыть фото. Попробуйте ещё раз.');
      }
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> addPhotos() async {
    final app = AppScope.of(context);
    try {
      var picked = await pickManyImages(5 - photos.length);
      if (picked.isEmpty || !mounted) return;
      // одно фото — сразу предлагаем обрезать и повернуть
      if (picked.length == 1) {
        final edited = await push<Uint8List>(context, PhotoEditor(bytes: picked.first));
        if (!mounted) return;
        if (edited != null) picked = [edited];
      }
      setState(() => uploading = true);
      for (final b in picked) {
        final url = await app.uploadImage(b, 'post');
        if (!mounted) return;
        _bytes[url] = b;
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
        contact: [
          if (phone.text.trim().isNotEmpty) normalizePhone(phone.text)!,
          if (tg.text.trim().isNotEmpty) normalizeTelegram(tg.text)!,
        ].join(' · '),
        photos: photos,
        priceEgp: int.tryParse(price.text.replaceAll(RegExp(r'[^0-9]'), '')),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      final mine = app.myPosts.where((x) => x.title == title.text.trim()).toList();
      toast(context, mine.isNotEmpty && mine.first.status == 'pending'
          ? 'Объявление отправлено модератору — обычно проверка занимает до 15 минут.'
          : 'Готово! Объявление опубликовано.');
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, AppState.serverMessage(e, 'Не удалось сохранить. Проверьте интернет.'));
    }
  }

  Future<void> remove() async {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final yes = await confirmDialog(context, 'Удалить объявление?', 'Его нельзя будет восстановить.', 'Удалить');
    if (!yes || !mounted) return;
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
          GestureDetector(
            onTap: uploading ? null : () => photoActions(i),
            child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(photos[i],
                width: 88,
                height: 88,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(width: 88, height: 88, color: p.soft, child: Center(child: Ico('image', color: p.muted)))),
          ),
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
          Positioned(
            right: 4,
            bottom: 4,
            child: IgnorePointer(
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: withAlpha(0xFF13262B, .7), shape: BoxShape.circle),
                child: const Center(child: Ico('edit', size: 13, color: Colors.white, stroke: 2.2)),
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
        painter: DashedBorder(p.line2),
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
                  if (photos.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Нажмите на фото: сделать главным, обрезать, повернуть',
                          style: TextStyle(fontSize: 12, color: p.muted)),
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
                    hint: titleHints[section]!,
                    validator: notEmpty,
                    capitalization: TextCapitalization.sentences,
                  ),
                  gap,
                  Field(
                    label: 'Описание',
                    controller: desc,
                    hint: descHints[section]!,
                    maxLines: 4,
                    capitalization: TextCapitalization.sentences,
                  ),
                  gap,
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Field(
                        label: priceLabels[section]!,
                        controller: price,
                        hint: section == Section.jobs ? 'Пусто — договорная' : 'Пусто — договорная, 0 — бесплатно',
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
                    label: 'Телефон / WhatsApp',
                    controller: phone,
                    hint: '+20 100 123 4567',
                    keyboard: TextInputType.phone,
                    validator: phoneCheck,
                    autocorrect: false,
                  ),
                  gap,
                  Field(
                    label: 'Telegram (необязательно)',
                    controller: tg,
                    hint: '@username',
                    validator: tgCheck,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 8),
                  Text('Объявление появится в ленте сразу после автоматической проверки. Подозрительные объявления сначала смотрит модератор. Запрещены мат, ссылки, казино, интим и другие нарушения правил.',
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

// =====================================================================
// Полезное: конвертер и справочник
// =====================================================================

class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return UnderBar(
      bar: const GlassBar(title: 'Полезное', subtitle: 'Курс валют и важные номера'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          sliver: SliverList.list(children: [
            const ConverterCard(),
            const SizedBox(height: 6),
            const SectionTitle('Справочник'),
            const SizedBox(height: 8),
            MenuGroup(rows: [
              for (final d in demoDirectory)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: p.sel, borderRadius: BorderRadius.circular(12)),
                      child: Center(child: Ico('phoneCall', size: 18, color: p.accent)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.name, style: TextStyle(fontSize: 15, color: p.text, fontWeight: FontWeight.w600)),
                        Text(d.note, style: TextStyle(fontSize: 13, color: p.muted)),
                      ]),
                    ),
                    GestureDetector(
                      onTap: () => openUrl(context, 'tel:${d.phone.replaceAll(' ', '')}', d.phone),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(gradient: p.primaryGradient, borderRadius: BorderRadius.circular(18)),
                        child: Center(
                          child: Text(d.phone,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: p.onPrimary)),
                        ),
                      ),
                    ),
                  ]),
                ),
            ]),
            const SizedBox(height: 20),
            Center(child: Text('Свои в Египте · версия 0.4', style: TextStyle(fontSize: 12.5, color: p.muted))),
          ]),
        ),
      ],
    );
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
    AppScope.of(context); // перерисовать, когда загрузится свежий курс
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
        Text(ratesUpdated == null ? tr('Примерный курс, для ориентира') : tr('Курс обновлён: {d}', {'d': dateText(ratesUpdated!)}),
            style: TextStyle(fontSize: 13, color: p.muted)),
      ]),
    );
  }
}

// =====================================================================
// Профиль
// =====================================================================

String sinceText(DateTime d) => tr('На сайте с {d}', {'d': monthYear(d)});

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
    final picked = await pickOneImage(maxWidth: 1200);
    if (picked == null || !context.mounted) return;
    // обрезка по кругу, чтобы лицо было по центру
    final bytes = await push<Uint8List>(context, PhotoEditor(bytes: picked, fixedAspect: 1, circle: true, maxSide: 600));
    if (bytes == null || !context.mounted) return;
    toast(context, 'Загружаем фото…');
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
              decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle, border: Border.all(color: p.card, width: 3)),
              child: Center(child: Ico('camera', size: size * .17, color: p.onPrimary, stroke: 2.2)),
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

    Widget stat(String v, String label, VoidCallback onTap) => Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                Text(v, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: p.text)),
                const SizedBox(height: 2),
                Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: p.accent)),
              ]),
            ),
          ),
        );
    void myReviews() => push(context, ReviewsScreen(userId: app.user!.id, name: app.userName));

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
                  if (prof?.banned == true) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: p.warnbg, borderRadius: BorderRadius.circular(14)),
                      child: Text('Ваш аккаунт заблокирован за нарушение правил. Публиковать объявления и писать сообщения нельзя.',
                          style: TextStyle(fontSize: 13, color: p.bad, height: 1.4)),
                    ),
                    const SizedBox(height: 10),
                  ],
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
                          const VerifiedPill(big: true, text: '✓ Telegram подтверждён')
                        else
                          GestureDetector(
                            onTap: () => push(context, const VerifyScreen()),
                            child: Pill('Не проверен · пройти', bg: p.warnbg, fg: p.warn, big: true),
                          ),
                      ]),
                      if (prof != null) ...[
                        const SizedBox(height: 8),
                        Text(sinceText(prof.createdAt), style: TextStyle(fontSize: 13, color: p.muted)),
                      ],
                      const SizedBox(height: 14),
                      Divider(height: 1, color: p.line3),
                      const SizedBox(height: 14),
                      Row(children: [
                        stat('$active', adsWord(active), () => push(context, const MyAdsScreen())),
                        stat('${app.favorites.length}', 'в избранном', () => push(context, const FavoritesScreen())),
                        stat(rating == null ? '—' : rating.toStringAsFixed(1),
                            reviews == 0 ? 'нет отзывов' : '$reviews ${reviewsWord(reviews)}', myReviews),
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
                        right: tr(app.city),
                        onTap: () async {
                          final v = await pickOption(context, 'Город в ленте', cities, app.city);
                          if (v != null) app.setCity(v);
                        }),
                    MenuRow(icon: 'lock', label: 'Сменить пароль', onTap: () => showPasswordSheet(context)),
                    MenuRow(icon: 'chat', label: 'Сообщения', right: app.unreadTotal > 0 ? '${app.unreadTotal}' : null,
                        rightAccent: app.unreadTotal > 0, onTap: () => push(context, const ChatsScreen())),
                    MenuRow(icon: 'globe', label: 'Язык', right: langName(app.lang), onTap: () => showLanguageSheet(context)),
                    MenuRow(icon: 'star', label: 'Мои отзывы и рейтинг', onTap: myReviews),
                    MenuRow(
                        icon: 'bell',
                        label: 'Подписки на поиск',
                        right: app.savedSearches.isEmpty ? null : '${app.savedSearches.length}',
                        onTap: () => push(context, const SavedSearchesScreen())),
                    MenuRow(
                        icon: 'send',
                        label: 'Уведомления в Telegram',
                        right: prof?.verified != true
                            ? tr('нужна проверка')
                            : (prof?.notifyTg ?? true)
                                ? tr('Вкл.')
                                : tr('Выкл.'),
                        onTap: () async {
                          if (prof?.verified != true) {
                            push(context, const VerifyScreen());
                            return;
                          }
                          await app.setNotifyTg(!(prof?.notifyTg ?? true));
                          if (context.mounted) {
                            toast(context, (app.profile?.notifyTg ?? true) ? 'Уведомления включены' : 'Уведомления выключены');
                          }
                        }),
                    MenuRow(
                        icon: 'lock',
                        label: 'Заблокированные',
                        right: app.blockedIds.isEmpty ? null : '${app.blockedIds.length}',
                        onTap: () => push(context, const BlockedScreen())),
                    MenuRow(
                        icon: 'shield',
                        label: 'Проверка профиля',
                        right: app.profile?.verified == true ? tr('Пройдена') : null,
                        onTap: () => push(context, const VerifyScreen())),
                  ]),
                  const SizedBox(height: 10),
                  MenuGroup(rows: [
                    MenuRow(
                      icon: 'trash',
                      label: 'Удалить аккаунт',
                      danger: true,
                      onTap: () => deleteAccountFlow(context),
                    ),
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
          Text(priceOf(post), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.accent)),
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
              Text('${priceOf(post)} · ${dateText(post.date)}', style: TextStyle(fontSize: 13, color: p.muted)),
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
      return ['Отклонено', withAlpha(0xFFA33A2B, .16), p.bad];
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
      await app.updateProfile(name: name.text.trim(), city: city, phone: normalizePhone(phone.text) ?? '');
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
                        validator: (v) => (v ?? '').trim().isEmpty || normalizePhone(v!) != null
                            ? null
                            : 'Номер: 10–15 цифр, например +20 100 123 4567',
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
              backgroundColor: primary ? p.primary : p.soft,
              foregroundColor: primary ? p.onPrimary : (fg ?? p.text),
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
                          child: Text('Новые и изменённые объявления проходят проверку модератором. «Продвинуть» — поднять наверх, выделить цветом или сделать VIP.',
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
                                Text('${priceOf(x)} · ${tr(x.city)} · ${dateText(x.date)}',
                                    style: TextStyle(fontSize: 13, color: p.muted)),
                                if (x.status == 'pending')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text('Проверяем — обычно до нескольких часов',
                                        style: TextStyle(fontSize: 12.5, color: p.warn)),
                                  ),
                                if (x.status == 'active')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                        tr('👁 {v} просм. · ☎ {c} обращ. · ♡ {f}',
                                            {'v': x.views, 'c': x.contacts, 'f': app.myFavCounts[x.id] ?? 0}),
                                        style: TextStyle(fontSize: 12.5, color: p.text2)),
                                  ),
                                if (x.status == 'active' && x.isHighlighted)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                        x.isVip
                                            ? tr('VIP до {d}', {'d': dateText(x.vipUntil!)})
                                            : tr('Выделено до {d}', {'d': dateText(x.highlightUntil!)}),
                                        style: const TextStyle(fontSize: 12.5, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
                                  ),
                                if (x.status == 'blocked' && (x.rejectReason ?? '').isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(tr('Причина: {r}', {'r': tr(x.rejectReason ?? '')}), style: TextStyle(fontSize: 12.5, color: p.bad)),
                                  ),
                              ]),
                            ),
                            const SizedBox(width: 8),
                            Pill(st[0] as String, bg: st[1] as Color, fg: st[2] as Color),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: smallBtn('Продвинуть', x.status == 'active' ? () => showPromoteSheet(context, x) : null,
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
                                  ? smallBtn('Вернуть', () => setStatus(x, 'active', 'Отправлено на проверку'),
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
                                  Text('${mine ? tr('Вы: ') : ''}${t.last.imageUrl != null && t.last.text.isEmpty ? tr('📷 Фото') : t.last.text}',
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
                                  decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(11)),
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
  List<Deal> deals = [];
  bool loading = true;
  bool sending = false;
  bool uploading = false;
  Timer? timer;
  bool started = false;
  Profile? other;
  int ticks = 0;
  AppState? appRef;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    refresh();
    loadDeals();
    loadOther();
    appRef = AppScope.of(context);
    appRef!.loadBlocks();
    // новые сообщения приходят мгновенно; таймер — запасной вариант
    AppScope.of(context).onIncomingMessage(refresh);
    timer = Timer.periodic(const Duration(seconds: 8), (_) {
      refresh();
      if (++ticks % 4 == 0) loadOther(); // статус «в сети» — раз в ~30 секунд
    });
  }

  Future<void> loadOther() async {
    final pr = await AppScope.of(context).fetchProfile(widget.otherId);
    if (mounted && pr != null) setState(() => other = pr);
  }

  Future<void> openPost() async {
    final id = widget.postId;
    if (id == null) return;
    final post = await AppScope.of(context).fetchPost(id);
    if (!mounted) return;
    if (post == null) {
      toast(context, 'Объявление снято с публикации или удалено.');
      return;
    }
    push(context, PostDetailScreen(post: post));
  }

  Future<void> refresh() async {
    try {
      final list = await AppScope.of(context).fetchMessages(widget.otherId, widget.postId);
      if (!mounted) return;
      if (list.length != msgs.length || loading || (list.isNotEmpty && msgs.isNotEmpty && list.last.read != msgs.last.read)) {
        setState(() {
          msgs = list;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadDeals() async {
    final d = await AppScope.of(context).fetchDealsWith(widget.otherId);
    if (mounted) setState(() => deals = d.where((x) => x.postId == widget.postId).toList());
  }

  Future<void> send({String? imageUrl}) async {
    final text = draft.text.trim();
    if ((text.isEmpty && imageUrl == null) || sending) return;
    final app = AppScope.of(context);
    setState(() => sending = true);
    try {
      await app.sendMessage(widget.otherId, widget.postId, imageUrl != null ? '' : text, imageUrl: imageUrl);
      if (imageUrl == null) draft.clear();
      await refresh();
    } catch (e) {
      if (mounted) toast(context, AppState.serverMessage(e, 'Не удалось отправить. Проверьте интернет.'));
    }
    if (mounted) setState(() => sending = false);
  }

  Future<void> attachPhoto() async {
    final app = AppScope.of(context);
    try {
      final bytes = await pickOneImage(maxWidth: 1400);
      if (bytes == null) return;
      setState(() => uploading = true);
      final url = await app.uploadImage(bytes, 'chat');
      await send(imageUrl: url);
    } catch (_) {
      if (mounted) toast(context, 'Не удалось отправить фото. Попробуйте ещё раз.');
    }
    if (mounted) setState(() => uploading = false);
  }

  Future<void> confirmDeal() async {
    final app = AppScope.of(context);
    final ok = await confirmDialog(
        context,
        'Сделка состоялась?',
        tr('Подтвердите, что {n} купил(а) товар или получил(а) услугу. После этого покупатель сможет оставить вам отзыв.', {'n': widget.otherName}),
        'Подтвердить',
        danger: false);
    if (!ok || !mounted) return;
    try {
      await app.confirmDeal(widget.otherId, widget.postId);
      await app.sendMessage(widget.otherId, widget.postId, '✅ Сделка подтверждена. Буду рад(а) вашему отзыву!');
      await Future.wait([loadDeals(), refresh()]);
      if (mounted) toast(context, 'Сделка подтверждена');
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      toast(
          context,
          s.contains('duplicate') || s.contains('23505')
              ? 'Сделка уже подтверждена'
              : 'Подтвердить можно, когда покупатель написал вам в этом чате.');
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    appRef?.onIncomingMessage(null);
    draft.dispose();
    super.dispose();
  }

  String dayLabel(DateTime d) {
    final t = dateText(d);
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final mq = MediaQuery.of(context);
    final me = app.user?.id;
    final iAmSeller = widget.postId != null && app.myPosts.any((x) => x.id == widget.postId);
    final deal = deals.isEmpty ? null : deals.first;

    // Строим ленту: разделители по дням + сообщения (снизу вверх).
    final items = <Object>[];
    String? lastDay;
    for (final m in msgs) {
      final day = dayLabel(m.date);
      if (day != lastDay) {
        items.add(day);
        lastDay = day;
      }
      items.add(m);
    }
    final rev = items.reversed.toList();

    Widget dealBar() {
      if (iAmSeller && deal == null && msgs.any((m) => m.senderId == widget.otherId)) {
        return _ChatBanner(
          icon: 'check',
          text: 'Договорились? Отметьте сделку — так покупатель сможет оставить отзыв.',
          action: 'Сделка состоялась',
          onTap: confirmDeal,
        );
      }
      if (iAmSeller && deal != null) {
        return _ChatBanner(icon: 'shield', text: 'Сделка подтверждена', good: true);
      }
      if (deal != null && deal.buyerId == me && !deal.reviewed) {
        return _ChatBanner(
          icon: 'star',
          text: 'Продавец подтвердил сделку. Оцените его — это поможет другим.',
          action: 'Оставить отзыв',
          onTap: () async {
            final title = widget.postTitle.split(' · ').first;
            final ok = await showReviewSheet(context, deal, widget.otherName, title);
            if (ok) loadDeals();
          },
        );
      }
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(children: [
        // Шапка
        Container(
          padding: EdgeInsets.fromLTRB(10, 8 + mq.padding.top, 12, 10),
          decoration: BoxDecoration(color: p.bg, border: Border(bottom: BorderSide(color: p.line3))),
          child: Row(children: [
            IconBtn('back', plain: true, label: 'Назад', onTap: () => Navigator.maybePop(context)),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => push(context, SellerScreen(userId: widget.otherId, name: widget.otherName)),
              child: Avatar(name: widget.otherName, url: widget.otherAvatar, size: 40),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => push(context, SellerScreen(userId: widget.otherId, name: widget.otherName)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.otherName,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: heading(16, weight: FontWeight.w800, color: p.text)),
                  if (other?.lastSeen != null)
                    Text(onlineText(other!.lastSeen),
                        style: TextStyle(fontSize: 12, color: isOnline(other!.lastSeen) ? p.ok : p.muted))
                  else
                    Text('Открыть профиль', style: TextStyle(fontSize: 12, color: p.muted)),
                ]),
              ),
            ),
            IconBtn('more', plain: true, label: 'Ещё', onTap: () async {
              await showUserMenu(context, userId: widget.otherId, name: widget.otherName);
              if (mounted) setState(() {});
            }),
          ]),
        ),
        if (widget.postTitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Box(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              radius: 14,
              onTap: openPost,
              child: Row(children: [
                Ico('tag', size: 16, color: p.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.postTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, color: p.text, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                Text('Открыть', style: TextStyle(fontSize: 12.5, color: p.accent, fontWeight: FontWeight.w600)),
                Ico('chevron', size: 14, color: p.accent),
              ]),
            ),
          ),
        dealBar(),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : msgs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Ico('chat', size: 40, color: p.muted, stroke: 1.6),
                          const SizedBox(height: 12),
                          Text('Напишите первое сообщение — например, спросите, актуально ли объявление.',
                              textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 15, height: 1.5)),
                        ]),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: rev.length,
                      itemBuilder: (_, i) {
                        final it = rev[i];
                        if (it is String) {
                          return Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(10)),
                              child: Text(it, style: TextStyle(fontSize: 12, color: p.muted, fontWeight: FontWeight.w600)),
                            ),
                          );
                        }
                        final m = it as ChatMessage;
                        final mine = m.senderId == me;
                        // соседнее сообщение того же автора — меньше отступ и «хвостик» только у последнего
                        final newer = i > 0 && rev[i - 1] is ChatMessage ? rev[i - 1] as ChatMessage : null;
                        final lastInGroup = newer == null || newer.senderId != m.senderId;
                        return _Bubble(m: m, mine: mine, tail: lastInGroup, maxW: math.min(mq.size.width * .78, 420.0));
                      },
                    ),
        ),
        // Поле ввода (или плашка, если переписка ограничена)
        if (app.blockedIds.contains(widget.otherId) || app.blockedMe.contains(widget.otherId))
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + mq.padding.bottom),
            decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.line))),
            child: Row(children: [
              Ico('lock', size: 18, color: p.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    app.blockedIds.contains(widget.otherId)
                        ? 'Вы заблокировали этого пользователя.'
                        : 'Пользователь ограничил переписку с вами.',
                    style: TextStyle(fontSize: 13.5, color: p.text2)),
              ),
              if (app.blockedIds.contains(widget.otherId))
                TextButton(
                  onPressed: () => app.setBlocked(widget.otherId, false),
                  child: Text('Разблокировать', style: TextStyle(color: p.accent, fontWeight: FontWeight.w600)),
                ),
            ]),
          )
        else
        Container(
          padding: EdgeInsets.fromLTRB(8, 8, 10, 8 + mq.padding.bottom),
          decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.line))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            uploading
                ? const SizedBox(width: 44, height: 44, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2.2)))
                : IconBtn('image', plain: true, box: 44, size: 22, color: p.muted, label: 'Прикрепить фото', onTap: attachPhoto),
            const SizedBox(width: 2),
            Expanded(
              child: TextField(
                controller: draft,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 15, color: p.text),
                decoration: InputDecoration(
                  hintText: tr('Сообщение…'),
                  hintStyle: TextStyle(color: p.hint, fontSize: 15),
                  isDense: true,
                  filled: true,
                  fillColor: p.input,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: p.line)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: p.primary, width: 1.4)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Отправить',
              child: GestureDetector(
                onTap: () => send(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(gradient: p.primaryGradient, shape: BoxShape.circle),
                  child: Center(
                    child: sending
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.onPrimary))
                        : Ico('send', size: 19, color: p.onPrimary, stroke: 2.2),
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

class _ChatBanner extends StatelessWidget {
  const _ChatBanner({required this.icon, required this.text, this.action, this.onTap, this.good = false});
  final String icon;
  final String text;
  final String? action;
  final VoidCallback? onTap;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: good ? p.okbg : p.sel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: good ? p.ok.withAlpha(60) : p.primary.withAlpha(60)),
      ),
      child: Row(children: [
        Ico(icon, size: 18, color: good ? p.ok : p.accent),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: good ? p.ok : p.text, height: 1.35))),
        if (action != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(gradient: p.primaryGradient, borderRadius: BorderRadius.circular(12)),
              child: Text(action!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.onPrimary)),
            ),
          ),
        ],
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.m, required this.mine, required this.tail, required this.maxW});
  final ChatMessage m;
  final bool mine;
  final bool tail;
  final double maxW;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final fg = mine ? p.onPrimary : p.text;
    final r = const Radius.circular(20);
    final small = const Radius.circular(6);
    final radius = BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: mine || !tail ? r : small,
      bottomRight: mine && tail ? small : r,
    );
    final time = Row(mainAxisSize: MainAxisSize.min, children: [
      Text(timeOnly(m.date), style: TextStyle(fontSize: 11, color: mine ? fg.withAlpha(190) : p.muted)),
      if (mine) ...[
        const SizedBox(width: 3),
        Text(m.read ? '✓✓' : '✓',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: m.read ? fg : fg.withAlpha(150))),
      ],
    ]);

    Widget content;
    if (m.imageUrl != null) {
      content = GestureDetector(
        onTap: () => push(context, PhotoViewer(photos: [m.imageUrl!])),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(children: [
            Image.network(m.imageUrl!,
                width: math.min(maxW, 260.0),
                fit: BoxFit.cover,
                cacheWidth: 600,
                errorBuilder: (_, __, ___) => Container(
                    width: 200, height: 140, color: p.soft, child: Center(child: Ico('image', color: p.muted)))),
            Positioned(
              right: 8,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0x8C000000), borderRadius: BorderRadius.circular(8)),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.white),
                  child: Text(timeOnly(m.date), style: const TextStyle(fontSize: 11, color: Colors.white)),
                ),
              ),
            ),
          ]),
        ),
      );
    } else {
      content = Container(
        padding: const EdgeInsets.fromLTRB(14, 9, 12, 7),
        decoration: BoxDecoration(
          gradient: mine ? p.primaryGradient : null,
          color: mine ? null : p.card,
          borderRadius: radius,
          border: mine ? null : Border.all(color: p.line),
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 8,
          runSpacing: 2,
          children: [
            Text(m.text, style: TextStyle(fontSize: 15, height: 1.38, color: fg)),
            Padding(padding: const EdgeInsets.only(top: 3), child: time),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: tail ? 6 : 2),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxW), child: content),
      ),
    );
  }
}

String timeOnly(DateTime d) {
  final l = d.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

// =====================================================================
// Профиль продавца и отзывы
// =====================================================================

class StarsRow extends StatelessWidget {
  const StarsRow({super.key, required this.value, this.size = 14});
  final double value;
  final double size;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 1),
            child: Ico('star',
                size: size,
                stroke: 1.4,
                color: const Color(0xFFF5B82E),
                fill: value >= i - .25 ? const Color(0xFFF5B82E) : null),
          ),
      ]);
}

/// Отзыв после сделки. Возвращает true, если отзыв отправлен.
Future<bool> showReviewSheet(BuildContext context, Deal deal, String sellerName, String postTitle) async {
  final app = AppScope.of(context);
  var stars = 5;
  final text = TextEditingController();
  var busy = false;
  String? err;
  const labels = ['', 'Ужасно', 'Плохо', 'Нормально', 'Хорошо', 'Отлично'];
  final ok = await showGlassSheet<bool>(
    context,
    (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      final p = Pal.of(ctx);
      return Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetHandle(),
          Text('Отзыв о продавце', style: heading(20, weight: FontWeight.w800, color: p.text)),
          const SizedBox(height: 4),
          Text(postTitle.isEmpty ? sellerName : '$sellerName · $postTitle',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: p.muted)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              GestureDetector(
                onTap: () => setSheet(() => stars = i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Ico('star',
                      size: 38, stroke: 1.5, color: const Color(0xFFF5B82E), fill: i <= stars ? const Color(0xFFF5B82E) : null),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          Center(child: Text(labels[stars], style: TextStyle(fontSize: 14, color: p.text2, fontWeight: FontWeight.w600))),
          const SizedBox(height: 14),
          Field(label: 'Комментарий', controller: text, maxLines: 3, hint: 'Как прошла сделка? Что понравилось?', capitalization: TextCapitalization.sentences),
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
              await app.addReview(deal, stars, text.text.trim(), postTitle);
              if (ctx.mounted) Navigator.pop(ctx, true);
            } catch (e) {
              final dup = e.toString().contains('duplicate') || e.toString().contains('23505');
              setSheet(() {
                busy = false;
                err = dup ? 'Вы уже оставили отзыв по этой сделке.' : 'Не удалось отправить. Попробуйте позже.';
              });
            }
          }),
        ]),
      );
    }),
  );
  if (ok == true && context.mounted) toast(context, 'Спасибо за отзыв!');
  return ok == true;
}

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
  List<Deal> deals = [];
  bool loading = true;
  bool started = false;
  final adsKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    load();
  }

  void openReviews() {
    final name = (prof?.name ?? '').isNotEmpty ? prof!.name : widget.name;
    push(context, ReviewsScreen(userId: widget.userId, name: name));
  }

  void scrollToAds() {
    final c = adsKey.currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  Future<void> load() async {
    final app = AppScope.of(context);
    final r = await Future.wait([
      app.fetchProfile(widget.userId),
      app.fetchSellerPosts(widget.userId),
      app.fetchReviews(widget.userId),
      app.fetchDealsWith(widget.userId),
    ]);
    if (!mounted) return;
    setState(() {
      prof = r[0] as Profile?;
      posts = r[1] as List<Post>;
      reviews = r[2] as List<Review>;
      deals = (r[3] as List<Deal>).where((d) => d.sellerId == widget.userId).toList();
      loading = false;
    });
  }

  Future<void> leaveReview() async {
    final app = AppScope.of(context);
    if (app.user == null) {
      askLogin(context, 'Войдите, чтобы оставить отзыв.');
      return;
    }
    final open = deals.where((d) => !d.reviewed).toList();
    if (open.isEmpty) return;
    final d = open.first;
    final title = await app.postTitleOf(d.postId);
    if (!mounted) return;
    final name = (prof?.name ?? '').isNotEmpty ? prof!.name : widget.name;
    final ok = await showReviewSheet(context, d, name, title);
    if (ok) load();
  }

  Future<void> reply(Review r) async {
    final app = AppScope.of(context);
    final c = TextEditingController(text: r.reply ?? '');
    final ok = await showGlassSheet<bool>(
      context,
      (ctx) {
        final p = Pal.of(ctx);
        return Padding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SheetHandle(),
            Text('Ответ на отзыв', style: heading(20, weight: FontWeight.w800, color: p.text)),
            const SizedBox(height: 14),
            Field(label: 'Ваш ответ', controller: c, maxLines: 3, hint: 'Спасибо за отзыв!', capitalization: TextCapitalization.sentences),
            const SizedBox(height: 16),
            PrimaryButton('Ответить', onPressed: () => Navigator.pop(ctx, true)),
          ]),
        );
      },
    );
    if (ok != true || c.text.trim().isEmpty) return;
    try {
      await app.replyReview(r.id, c.text.trim());
      if (mounted) {
        toast(context, 'Ответ опубликован');
        load();
      }
    } catch (_) {
      if (mounted) toast(context, 'Не удалось ответить. Попробуйте позже.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final name = (prof?.name ?? '').isNotEmpty ? prof!.name : widget.name;
    final avg = reviews.isEmpty ? 0.0 : reviews.fold<int>(0, (a, r) => a + r.stars) / reviews.length;
    final self = app.user?.id == widget.userId;
    final canReview = deals.any((d) => !d.reviewed);

    Widget stat(String v, String label, VoidCallback? onTap) => Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                Text(v, style: heading(19, weight: FontWeight.w800, color: p.text)),
                Text(label, style: TextStyle(fontSize: 12.5, color: onTap == null ? p.muted : p.accent)),
              ]),
            ),
          ),
        );
    final blocked = app.blockedIds.contains(widget.userId);
    final contactSrc = widget.fromPost?.contact ??
        [if ((prof?.phone ?? '').isNotEmpty) prof!.phone!, if ((prof?.tgUsername ?? '').isNotEmpty) '@${prof!.tgUsername}'].join(' · ');

    return Scaffold(
      body: Column(children: [
        SubHeader(
          title: self ? 'Мой профиль' : 'Профиль продавца',
          trailing: self || app.user == null
              ? null
              : IconBtn('more', label: 'Ещё', onTap: () async {
                  await showUserMenu(context, userId: widget.userId, name: name);
                  if (mounted) setState(() {});
                }),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  color: p.primary,
                  onRefresh: load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
                    children: [
                      Box(
                        padding: const EdgeInsets.all(20),
                        child: Column(children: [
                          Avatar(name: name, url: prof?.avatarUrl ?? widget.fromPost?.authorAvatar, size: 76),
                          const SizedBox(height: 10),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Flexible(
                              child: Text(name,
                                  textAlign: TextAlign.center, style: heading(20, weight: FontWeight.w800, color: p.text)),
                            ),
                            if (prof?.verified == true) ...[const SizedBox(width: 6), Ico('shield', size: 18, color: p.ok)],
                          ]),
                          const SizedBox(height: 2),
                          Text(
                              '${tr(prof?.city ?? widget.fromPost?.city ?? '')}${prof != null ? ' · ${tr('на сайте с {y}', {'y': prof!.createdAt.year})}' : ''}',
                              style: TextStyle(fontSize: 13, color: p.muted)),
                          if (prof?.lastSeen != null) ...[
                            const SizedBox(height: 4),
                            OnlineDot(lastSeen: prof!.lastSeen),
                          ],
                          if (prof?.verified == true) ...[
                            const SizedBox(height: 8),
                            const VerifiedPill(big: true, text: '✓ Telegram подтверждён'),
                          ],
                          const SizedBox(height: 16),
                          Row(children: [
                            stat(reviews.isEmpty ? '—' : avg.toStringAsFixed(1), 'рейтинг', openReviews),
                            stat('${posts.length}', adsWord(posts.length), posts.isEmpty ? null : scrollToAds),
                            stat('${reviews.length}', reviewsWord(reviews.length), openReviews),
                          ]),
                          if (!self && blocked) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: p.warnbg, borderRadius: BorderRadius.circular(14)),
                              child: Row(children: [
                                Ico('lock', size: 18, color: p.warn),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text('Вы заблокировали этого пользователя. Его объявления скрыты, писать вам он не может.',
                                        style: TextStyle(fontSize: 13, color: p.warn, height: 1.4))),
                              ]),
                            ),
                            const SizedBox(height: 8),
                            OutlineBtn('Разблокировать', icon: 'lock', onPressed: () async {
                              await app.setBlocked(widget.userId, false);
                              if (mounted) toast(context, 'Пользователь разблокирован');
                            }),
                          ],
                          if (!self && !blocked && contactSrc.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            ContactButtons(contact: contactSrc, postId: widget.fromPost?.id),
                          ],
                          if (!self && !blocked) ...[
                            const SizedBox(height: 16),
                            PrimaryButton('Написать', height: 48, icon: 'chat', onPressed: () {
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
                                    postTitle: fp == null ? '' : '${fp.title} · ${priceOf(fp)}',
                                  ));
                            }),
                          ],
                        ]),
                      ),
                      const SizedBox(height: 6),
                      const SectionTitle('Отзывы'),
                      const SizedBox(height: 8),
                      if (reviews.isNotEmpty) ...[RatingSummary(reviews: reviews, onTap: openReviews), const SizedBox(height: 10)],
                      if (!self && canReview) ...[
                        PrimaryButton('Оставить отзыв', icon: 'star', height: 48, onPressed: leaveReview),
                        const SizedBox(height: 10),
                      ] else if (!self) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(14)),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Ico('shield', size: 18, color: p.accent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                  'Отзыв можно оставить только после сделки: продавец подтверждает её в чате кнопкой «Сделка состоялась». Так все отзывы — настоящие.',
                                  style: TextStyle(fontSize: 13, color: p.text2, height: 1.45)),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (reviews.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                          child: Text('Отзывов пока нет.', style: TextStyle(fontSize: 14, color: p.muted)),
                        ),
                      for (final r in reviews.take(3)) ...[
                        ReviewCard(review: r, onReply: self && (r.reply ?? '').isEmpty ? () => reply(r) : null),
                        const SizedBox(height: 10),
                      ],
                      if (reviews.length > 3) ...[
                        OutlineBtn(tr('Все отзывы ({n})', {'n': reviews.length}), icon: 'star', onPressed: openReviews),
                        const SizedBox(height: 10),
                      ],
                      if (posts.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        SectionTitle(self ? 'Мои объявления' : 'Объявления продавца', key: adsKey),
                        const SizedBox(height: 8),
                        for (final x in posts) ...[PostCard(post: x), const SizedBox(height: 10)],
                      ],
                    ],
                  ),
                ),
        ),
      ]),
    );
  }
}

// =====================================================================
// Модерация (только для администратора)
// =====================================================================

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  int tab = 0;
  List<Post> pending = [];
  List<Map<String, dynamic>> reports = [];
  bool loading = true;
  String? error;
  bool started = false;

  static const reasons = [
    'Запрещённый товар или услуга',
    'Спам или реклама',
    'Мошенничество',
    'Неверный контакт',
    'Неинформативное объявление',
    'Дубликат',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    load();
  }

  Future<void> load() async {
    final app = AppScope.of(context);
    try {
      final r = await Future.wait([app.fetchPending(), app.fetchReports()]);
      if (!mounted) return;
      setState(() {
        pending = r[0] as List<Post>;
        reports = r[1] as List<Map<String, dynamic>>;
        loading = false;
        error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Не удалось загрузить. Проверьте, что база обновлена (v4).';
        });
      }
    }
  }

  Future<void> approve(Post x) async {
    try {
      await AppScope.of(context).moderate(x.id, 'active');
      if (mounted) toast(context, 'Опубликовано');
      load();
    } catch (_) {
      if (mounted) toast(context, 'Не удалось. Попробуйте ещё раз.');
    }
  }

  Future<void> reject(Post x) async {
    final reason = await pickOption(context, 'Причина отклонения', reasons, '');
    if (reason == null || !mounted) return;
    try {
      await AppScope.of(context).moderate(x.id, 'blocked', reason: reason);
      if (mounted) toast(context, 'Отклонено');
      load();
    } catch (_) {
      if (mounted) toast(context, 'Не удалось. Попробуйте ещё раз.');
    }
  }

  Widget postCard(Post x, {Widget? extra}) {
    final p = Pal.of(context);
    return Box(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GestureDetector(
          onTap: () => push(context, PostDetailScreen(post: x)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PostThumb(post: x, size: 72),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(x.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text)),
                const SizedBox(height: 2),
                Text('${priceOf(x)} · ${tr(sectionNames[x.section]!)} · ${tr(x.category)}',
                    style: TextStyle(fontSize: 12.5, color: p.muted)),
                Text('${x.author} · ${tr(x.city)} · ${dateText(x.date)}', style: TextStyle(fontSize: 12.5, color: p.muted)),
                Text(tr('Контакт: {c}', {'c': x.contact}), style: TextStyle(fontSize: 12.5, color: p.text2)),
                if ((x.autoFlags ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(tr('Автопроверка: {f}', {'f': x.autoFlags}),
                        style: TextStyle(fontSize: 12.5, color: p.warn, fontWeight: FontWeight.w600)),
                  ),
              ]),
            ),
          ]),
        ),
        if (x.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(x.description, maxLines: 4, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, color: p.text2, height: 1.4)),
        ],
        if (extra != null) ...[const SizedBox(height: 8), extra],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: PrimaryButton('Одобрить', height: 42, icon: 'check', onPressed: () => approve(x))),
          const SizedBox(width: 8),
          Expanded(child: OutlineBtn('Отклонить', height: 42, color: p.bad, onPressed: () => reject(x))),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final list = <Widget>[];
    if (tab == 3) {
      list.add(const AdminPanel());
    } else if (tab == 2) {
      list.add(const VerificationsPanel());
    } else if (tab == 0) {
      if (pending.isEmpty) {
        list.add(const EmptyState(icon: 'check', text: 'Новых объявлений на проверке нет.'));
      }
      for (final x in pending) {
        list..add(postCard(x))..add(const SizedBox(height: 10));
      }
    } else {
      if (reports.isEmpty) list.add(const EmptyState(icon: 'shield', text: 'Жалоб нет.'));
      for (final r in reports) {
        final pm = r['post'];
        if (pm is! Map<String, dynamic>) {
          final t = r['target'];
          if (t is! Map) continue;
          list
            ..add(Box(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Avatar(name: (t['name'] ?? '') as String, url: t['avatar_url'] as String?, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((t['name'] ?? '—') as String, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text)),
                      Text('${tr('Жалоба на пользователя')}: ${tr((r['reason'] ?? '') as String)}',
                          style: TextStyle(fontSize: 12.5, color: p.warn)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlineBtn('Профиль', height: 40, onPressed: () => push(context,
                        SellerScreen(userId: t['id'] as String, name: (t['name'] ?? '') as String))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlineBtn('Снять жалобу', height: 40, color: p.muted, onPressed: () async {
                      await AppScope.of(context).deleteReport((r['id'] as num).toInt());
                      load();
                    }),
                  ),
                ]),
              ]),
            ))
            ..add(const SizedBox(height: 10));
          continue;
        }
        final x = Post.fromMap(pm);
        list
          ..add(postCard(x,
              extra: Row(children: [
                Ico('alert', size: 16, color: p.warn),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('${tr('Жалоба')} · ${dateText(DateTime.tryParse((r['created_at'] ?? '') as String) ?? DateTime.now())}'
                      '${(r['reason'] ?? '').toString().isNotEmpty ? ': ${r['reason']}' : ''}',
                      style: TextStyle(fontSize: 12.5, color: p.warn)),
                ),
                TextButton(
                  onPressed: () async {
                    await AppScope.of(context).deleteReport((r['id'] as num).toInt());
                    load();
                  },
                  child: Text('Снять жалобу', style: TextStyle(color: p.muted, fontSize: 12.5)),
                ),
              ])))
          ..add(const SizedBox(height: 10));
      }
    }
    return Scaffold(
      body: Column(children: [
        SubHeader(title: 'Модерация', trailing: IconBtn('menu', plain: true, label: 'Обновить', onTap: load)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Segments<int>(
            values: const [0, 1, 2, 3],
            labels: ['${tr('Новые')} (${pending.length})', '${tr('Жалобы')} (${reports.length})', tr('Люди'), tr('Ещё')],
            selected: tab,
            onChanged: (v) => setState(() => tab = v),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  color: p.primary,
                  onRefresh: load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 24 + MediaQuery.of(context).padding.bottom),
                    children: [
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(error!, style: TextStyle(color: p.bad)),
                        ),
                      ...list,
                    ],
                  ),
                ),
        ),
      ]),
    );
  }
}

// =====================================================================
// Правила сервиса и политика конфиденциальности
// =====================================================================

class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key});

  static const sections = <List<String>>[
    ['Правила сервиса', ''],
    ['1. Что можно размещать',
        'Реальные товары, жильё, услуги и вакансии в Египте. Одно объявление — один товар или услуга. Фото и описание должны соответствовать действительности.'],
    ['2. Что запрещено',
        'Казино, ставки и азартные игры; порнография, интим и эскорт; наркотики и рецептурные лекарства; оружие; поддельные документы; финансовые пирамиды и «быстрый заработок»; реклама сторонних сайтов и ссылки в тексте; спам и одинаковые объявления; оскорбления и дискриминация; чужие фото и данные.'],
    ['3. Модерация',
        'Каждое новое или изменённое объявление проверяет модератор и публикует его после проверки. Мы можем отклонить или снять объявление, нарушающее правила, и заблокировать аккаунт за повторные нарушения. Действует лимит — не больше 5 объявлений в сутки.'],
    ['4. Отзывы',
        'Оставить отзыв можно только после сделки, которую продавец подтвердил в чате. Отзывы должны быть честными и по делу.'],
    ['5. Безопасность сделок',
        'Сервис не участвует в сделках и не принимает платежи между пользователями. Не переносите предоплату до встречи, проверяйте товар и документы, выбирайте пользователей с отметкой «Проверен». О подозрительных объявлениях сообщайте кнопкой «Пожаловаться».'],
    ['Политика конфиденциальности', ''],
    ['Какие данные мы храним',
        'Почту и пароль для входа (пароль хранится в зашифрованном виде), имя, город, телефон и фото профиля, которые вы указали сами; ваши объявления с фотографиями; сообщения в чате; отзывы и жалобы.'],
    ['Зачем',
        'Чтобы вы могли входить в аккаунт, публиковать объявления, общаться с другими пользователями, а также для модерации и защиты от мошенников и спама.'],
    ['Кто видит',
        'Объявления, имя, город, фото профиля и контакт из объявления видят все пользователи. Сообщения видят только участники переписки. Почту видите только вы. Мы не продаём и не передаём ваши данные третьим лицам для рекламы.'],
    ['Где хранятся',
        'На серверах сервиса Supabase с защищённым доступом. Фото объявлений и чата доступны по ссылке.'],
    ['Удаление',
        'Объявления можно удалить в разделе «Мои объявления». Чтобы удалить аккаунт и все данные, обратитесь к администрации — удалим в течение 30 дней.'],
  ];

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      body: Column(children: [
        const SubHeader(title: 'Правила и конфиденциальность'),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 32 + MediaQuery.of(context).padding.bottom),
            children: [
              for (final s in sections)
                if (s[1].isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 8),
                    child: Text(s[0], style: heading(20, weight: FontWeight.w800, color: p.text)),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s[0], style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text)),
                      const SizedBox(height: 4),
                      Text(s[1], style: TextStyle(fontSize: 14.5, color: p.text2, height: 1.5)),
                    ]),
                  ),
              const SizedBox(height: 8),
              Text('Редакция от 14 ноября 2026 г.', style: TextStyle(fontSize: 12.5, color: p.muted)),
            ],
          ),
        ),
      ]),
    );
  }
}
