// Переводы интерфейса. Ключ — русский текст, как он написан в коде.
// Виджет Text здесь подменён: любой Text('Русский текст') сам переводится на выбранный язык.
// Для текста с подстановками: tr('Контакт скопирован: {c}', {'c': value}).
import 'package:flutter/widgets.dart' as w;
import 'package:flutter/widgets.dart' hide Text;

import 'i18n_strings.dart';

/// Текущий язык: ru, en, uk, ar, de.
String appLang = 'ru';

bool get isRtl => appLang == 'ar';

const _col = {'en': 0, 'uk': 1, 'ar': 2, 'de': 3};

/// Перевод строки. Если перевода нет — английский, затем русский оригинал.
String tr(String ru, [Map<String, Object?>? args]) {
  var s = ru;
  final i = _col[appLang];
  if (i != null) {
    final row = kTr[ru];
    if (row != null) {
      final v = row.length > i ? row[i] : '';
      s = v.isNotEmpty ? v : (row.isNotEmpty && row[0].isNotEmpty ? row[0] : ru);
    }
  }
  if (args != null) {
    args.forEach((k, v) => s = s.replaceAll('{$k}', '${v ?? ''}'));
  }
  return s;
}

/// Слово «объявление» в нужной форме для числа n.
String adsWord(int n) => _count(n, const {
      'ru': ['объявление', 'объявления', 'объявлений'],
      'uk': ['оголошення', 'оголошення', 'оголошень'],
      'en': ['ad', 'ads'],
      'de': ['Anzeige', 'Anzeigen'],
      'ar': ['إعلان', 'إعلانان', 'إعلانات', 'إعلانًا'],
    });

/// Слово «отзыв» в нужной форме для числа n.
String reviewsWord(int n) => _count(n, const {
      'ru': ['отзыв', 'отзыва', 'отзывов'],
      'uk': ['відгук', 'відгуки', 'відгуків'],
      'en': ['review', 'reviews'],
      'de': ['Bewertung', 'Bewertungen'],
      'ar': ['تقييم', 'تقييمان', 'تقييمات', 'تقييمًا'],
    });

String _count(int n, Map<String, List<String>> forms) {
  final f = forms[appLang] ?? forms['en']!;
  switch (appLang) {
    case 'ru':
    case 'uk':
      final m10 = n % 10, m100 = n % 100;
      if (m10 == 1 && m100 != 11) return f[0];
      if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return f[1];
      return f[2];
    case 'ar':
      if (n == 2) return f[1];
      if (n % 100 >= 3 && n % 100 <= 10) return f[2];
      if (n % 100 >= 11) return f[3];
      return f[0];
    default:
      return n == 1 ? f[0] : f[1];
  }
}

const _monthsShort = {
  'ru': ['янв.', 'февр.', 'марта', 'апр.', 'мая', 'июня', 'июля', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'],
  'uk': ['січ.', 'лют.', 'бер.', 'квіт.', 'трав.', 'черв.', 'лип.', 'серп.', 'вер.', 'жовт.', 'лист.', 'груд.'],
  'en': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
  'de': ['Jan.', 'Feb.', 'März', 'Apr.', 'Mai', 'Juni', 'Juli', 'Aug.', 'Sep.', 'Okt.', 'Nov.', 'Dez.'],
  'ar': ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'],
};

const _monthsLong = {
  'ru': ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'],
  'uk': ['січня', 'лютого', 'березня', 'квітня', 'травня', 'червня', 'липня', 'серпня', 'вересня', 'жовтня', 'листопада', 'грудня'],
  'en': ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
  'de': ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'],
  'ar': ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'],
};

String monthShort(int m) => (_monthsShort[appLang] ?? _monthsShort['en']!)[m - 1];

/// «ноября 2026» / «November 2026».
String monthYear(DateTime d) {
  final names = _monthsLong[appLang] ?? _monthsLong['en']!;
  return appLang == 'en' || appLang == 'de' ? '${names[d.month - 1]} ${d.year}' : '${names[d.month - 1]} ${d.year}';
}

/// Text, который сам переводит строку на текущий язык.
class Text extends StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) => w.Text(
        tr(data),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel == null ? null : tr(semanticsLabel!),
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
}
