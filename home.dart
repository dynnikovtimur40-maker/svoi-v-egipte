// Главная: быстрый доступ ко всему, курс, погода, свежие новости и объявления.
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/widgets.dart' as w show Text;

import 'data.dart';
import 'features.dart';
import 'guide.dart';
import 'i18n.dart';
import 'main.dart';
import 'tourist.dart';

/// Город путеводителя для погоды: ближайший к выбранному городу.
GuideCity _weatherCity(String city) {
  const near = {
    'Сахл-Хашиш': 'Хургада',
    'Макади-Бей': 'Хургада',
    'Сома-Бей': 'Хургада',
    'Сафага': 'Хургада',
    'Эль-Кусейр': 'Марса-Алам',
    'Новый Каир': 'Каир',
    'Гиза': 'Каир',
    'Шейх-Зайед': 'Каир',
    '6-го Октября': 'Каир',
    'Эль-Аламейн': 'Александрия',
    'Нувейба': 'Дахаб',
    'Таба': 'Дахаб',
  };
  final name = near[city] ?? city;
  return guideCities.firstWhere((c) => c.name == name, orElse: () => guideCities.firstWhere((c) => c.name == 'Хургада'));
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.openTab});
  final ValueChanged<int> openTab;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final city = app.city != cities.first ? app.city : (app.profile?.city ?? 'Хургада');
    final wc = _weatherCity(city);

    final group = (app.lang == 'ru' || app.lang == 'uk') ? 'ru' : 'en';
    final news = app.news.where((n) => n.published && (n.lang == null || n.lang == group)).take(4).toList();
    final fresh = app.posts.where((x) => app.city == cities.first || x.city == app.city).take(4).toList();

    // [иконка, название, цвета градиента, действие]
    final actions = <(String, String, List<int>, VoidCallback)>[
      ('tag', 'Объявления', [0xFF34D399, 0xFF0D9488], () => openTab(0)),
      ('tool', 'Услуги', [0xFF60A5FA, 0xFF2563EB], () => openTab(1)),
      ('bag', 'Работа', [0xFFFCD34D, 0xFFF59E0B], () => openTab(2)),
      ('news', 'Новости', [0xFFA78BFA, 0xFF7C3AED], () => openTab(3)),
      ('alert', 'SOS', [0xFFFB7185, 0xFFE11D48], () => push(context, const SosScreen())),
      ('coin', 'Цены', [0xFF86EFAC, 0xFF16A34A], () => push(context, const FairPricesScreen())),
      ('pyramid', 'Путеводитель', [0xFFFDBA74, 0xFFEA580C], () => push(context, const GuideScreen())),
      ('gift', 'Скидки', [0xFFF9A8D4, 0xFFDB2777], () => push(context, const PromosScreen())),
      ('shield', 'Проверенные', [0xFF67E8F9, 0xFF0891B2], () => push(context, const TrustedScreen())),
      ('pin', 'Рядом', [0xFF7DD3FC, 0xFF0284C7], () => push(context, const NearbyScreen())),
      ('chat', 'Разговорник', [0xFFC4B5FD, 0xFF8B5CF6], () => push(context, const PhrasebookScreen())),
      ('grid', 'Полезное', [0xFFCBD5E1, 0xFF64748B], () => openTab(4)),
    ];

    return UnderBar(
      bar: const GlassBar(title: 'Свои в Египте', subtitle: 'Главная'),
      onRefresh: () async {
        await Future.wait([app.load(), app.loadNews(), app.loadRates()]);
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          sliver: SliverList.list(children: [
            GreetingCard(city: city, weatherCity: wc, onRates: () => openTab(4)),
            const SizedBox(height: 14),
            // Быстрый доступ — стеклянные иконки с цветной полоской
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 4,
              childAspectRatio: .86,
              children: [for (final a in actions) QuickIcon(icon: a.$1, label: a.$2, colors: a.$3, onTap: a.$4)],
            ),
            // Новости
            SectionTitle('Новости', action: 'Все', onAction: () => openTab(3)),
            const SizedBox(height: 6),
            if (!app.newsLoaded)
              const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
            else if (news.isEmpty)
              Text('Новостей пока нет.', style: TextStyle(fontSize: 13.5, color: p.muted))
            else
              for (final n in news) Padding(padding: const EdgeInsets.only(bottom: 8), child: NewsCard(item: n, compact: true)),
            // Свежие объявления
            SectionTitle('Свежие объявления', action: 'Все', onAction: () => openTab(0)),
            const SizedBox(height: 6),
            if (fresh.isEmpty)
              Box(
                onTap: () => openTab(0),
                child: Row(children: [
                  Ico('tag', size: 20, color: p.accent),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text('Объявлений в этом городе пока нет — станьте первым!',
                          style: TextStyle(fontSize: 13.5, color: p.body))),
                ]),
              )
            else
              for (final x in fresh) Padding(padding: const EdgeInsets.only(bottom: 8), child: PostCard(post: x)),
          ]),
        ),
      ],
    );
  }
}

/// Иконка быстрого доступа: «сквиркл» с градиентом и бликом, как на экране iPhone.
class QuickIcon extends StatefulWidget {
  const QuickIcon({super.key, required this.icon, required this.label, required this.colors, required this.onTap});
  final String icon, label;
  final List<int> colors;
  final VoidCallback onTap;

  @override
  State<QuickIcon> createState() => _QuickIconState();
}

class _QuickIconState extends State<QuickIcon> {
  bool down = false;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final accent = Color(widget.colors[0]);
    const size = 56.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => down = true),
      onTapCancel: () => setState(() => down = false),
      onTapUp: (_) => setState(() => down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: down ? .9 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          GlassTile(
            accent: accent,
            radius: 17,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(child: Ico(widget.icon, size: 25, color: p.dark ? Colors.white : p.text, stroke: 1.9)),
            ),
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(widget.label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.text, letterSpacing: -.1)),
          ),
        ]),
      ),
    );
  }
}

/// Тёмное стекло с цветной полоской снизу (иконки и плашки на главной).
class GlassTile extends StatelessWidget {
  const GlassTile({super.key, required this.child, this.accent, this.radius = 16, this.onTap});
  final Widget child;
  final Color? accent;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final br = BorderRadius.circular(radius);
    // без BackdropFilter: размытие на каждой плитке сильно тормозит веб-версию
    return ClipRRect(
      borderRadius: br,
      child: RepaintBoundary(
        child: Material(
          color: p.dark ? const Color(0x1CFFFFFF) : const Color(0x0D0B2B33),
          shape: RoundedRectangleBorder(
              borderRadius: br, side: BorderSide(color: p.dark ? const Color(0x2EFFFFFF) : const Color(0x1A0B2B33), width: .8)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(children: [
              child,
              if (accent != null) Positioned(left: 0, right: 0, bottom: 0, child: Container(height: 3, color: accent)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Карточка приветствия в стиле виджета iPhone: цвет по времени суток, дата, погода, курс.
class GreetingCard extends StatelessWidget {
  const GreetingCard({super.key, required this.city, required this.weatherCity, required this.onRates});
  final String city;
  final GuideCity weatherCity;
  final VoidCallback onRates;

  static const _days = {
    'ru': ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'],
    'uk': ['Понеділок', 'Вівторок', 'Середа', 'Четвер', 'Пʼятниця', 'Субота', 'Неділя'],
    'de': ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'],
    'en': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
  };
  static const _months = {
    'ru': ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'],
    'uk': ['січня', 'лютого', 'березня', 'квітня', 'травня', 'червня', 'липня', 'серпня', 'вересня', 'жовтня', 'листопада', 'грудня'],
    'de': ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'],
    'en': ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
  };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final logged = app.user != null;
    final now = DateTime.now();
    final h = now.hour;
    final (hello, glyph) = h < 5 || h >= 22
        ? ('Доброй ночи', '🌙')
        : h < 12
            ? ('Доброе утро', '🌅')
            : h < 18
                ? ('Добрый день', '☀️')
                : ('Добрый вечер', '🌇');
    final l = _days.containsKey(app.lang) ? app.lang : 'en';
    final date = l == 'en' || l == 'de'
        ? '${_days[l]![now.weekday - 1]}, ${l == 'de' ? '${now.day}. ${_months[l]![now.month - 1]}' : '${_months[l]![now.month - 1]} ${now.day}'}'
        : '${_days[l]![now.weekday - 1]}, ${now.day} ${_months[l]![now.month - 1]}';
    final name = logged ? app.userName.split(' ').first : '';
    final fg = p.dark ? Colors.white : p.text;
    final sub = p.dark ? const Color(0xB3FFFFFF) : p.muted;
    const pad = EdgeInsets.symmetric(horizontal: 12, vertical: 10);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              w.Text(date.toUpperCase(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: sub)),
              const SizedBox(height: 4),
              w.Text(logged ? '${tr(hello)},' : tr('Добро пожаловать!'),
                  style: heading(logged ? 26 : 28, weight: FontWeight.w800, color: fg, height: 1.12)),
              if (logged)
                w.Text('$name $glyph',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: heading(30, weight: FontWeight.w800, color: fg, height: 1.12)),
            ]),
          ),
          GestureDetector(
            onTap: () => logged ? push(context, const ProfileScreen()) : app.setGuest(false),
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.accent, width: 2)),
              child: Avatar(name: logged ? app.userName : '?', url: app.profile?.avatarUrl, size: 48),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: GlassTile(
              onTap: () => push(context, GuideCityScreen(city: weatherCity)),
              child: Padding(
                padding: pad,
                child: Row(children: [
                  Ico('pin', size: 16, color: fg),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(city,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg)),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FutureBuilder<List<num?>>(
            future: cityWeather(weatherCity),
            builder: (_, snap) {
              final d = snap.data;
              if (d == null || d[0] == null) return const SizedBox.shrink();
              return GlassTile(
                  onTap: () => push(context, GuideCityScreen(city: weatherCity)),
                child: Padding(
                  padding: pad,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    w.Text('${weatherIcon(d[1])} ${d[0]!.round()}°', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg)),
                    if (d[2] != null) ...[
                      const SizedBox(width: 8),
                      w.Text('🌊 ${d[2]!.round()}°', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg)),
                    ],
                  ]),
                ),
              );
            },
          ),
        ]),
        const SizedBox(height: 8),
        GlassTile(
          onTap: onRates,
          child: Padding(
            padding: pad,
            child: Row(children: [
              for (final (i, t) in [
                ('\$ ${egpPerUsd.toStringAsFixed(1)}', 'EGP'),
                ('€ ${egpPerEur.toStringAsFixed(1)}', 'EGP'),
                ('${fmt(100 * rubPerEgp)} ₽', '100 EGP'),
              ].indexed) ...[
                if (i > 0) Container(width: .8, height: 26, color: p.dark ? const Color(0x33FFFFFF) : p.line, margin: const EdgeInsets.symmetric(horizontal: 8)),
                Expanded(
                  child: Column(children: [
                    FittedBox(fit: BoxFit.scaleDown, child: w.Text(t.$1, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg))),
                    w.Text(t.$2, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: sub)),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}
