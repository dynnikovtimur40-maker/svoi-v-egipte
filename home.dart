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
            // Быстрый доступ — иконки в стиле iOS на стеклянной панели
            Glass(
              radius: 28,
              opacity: p.dark ? .38 : .55,
              blur: 26,
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
              child: GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 4,
                childAspectRatio: .84,
                children: [for (final a in actions) QuickIcon(icon: a.$1, label: a.$2, colors: a.$3, onTap: a.$4)],
              ),
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
    final c1 = Color(widget.colors[0]), c2 = Color(widget.colors[1]);
    const size = 58.0;
    final shape = ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(size * .5),
      side: const BorderSide(color: Color(0x40FFFFFF), width: .8),
    );
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
          Container(
            width: size,
            height: size,
            decoration: ShapeDecoration(
              shape: shape,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c1, c2]),
              shadows: [
                BoxShadow(color: c2.withAlpha(p.dark ? 110 : 80), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Stack(children: [
              // стеклянный блик сверху
              Positioned.fill(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: shape.copyWith(side: BorderSide.none),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [Color(0x59FFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
              Center(child: Ico(widget.icon, size: 27, color: Colors.white, stroke: 2.1)),
            ]),
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
    // [приветствие, значок, цвета]
    final (hello, glyph, colors) = h < 5 || h >= 22
        ? ('Доброй ночи', '🌙', const [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF0F766E)])
        : h < 12
            ? ('Доброе утро', '🌅', const [Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFF8B5CF6)])
            : h < 18
                ? ('Добрый день', '☀️', const [Color(0xFF06B6D4), Color(0xFF0EA5E9), Color(0xFF14B8A6)])
                : ('Добрый вечер', '🌇', const [Color(0xFFF97316), Color(0xFFDB2777), Color(0xFF6D28D9)]);
    final l = _days.containsKey(app.lang) ? app.lang : 'en';
    final date = l == 'en' || l == 'de'
        ? '${_days[l]![now.weekday - 1]}, ${l == 'de' ? '${now.day}. ${_months[l]![now.month - 1]}' : '${_months[l]![now.month - 1]} ${now.day}'}'
        : '${_days[l]![now.weekday - 1]}, ${now.day} ${_months[l]![now.month - 1]}';
    final name = logged ? app.userName.split(' ').first : '';
    const white = Colors.white;
    const glassBg = Color(0x2EFFFFFF);
    const glassLine = Color(0x40FFFFFF);

    Widget chip(Widget child, {VoidCallback? onTap}) => Material(
          color: glassBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: glassLine, width: .8)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: child)),
        );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        boxShadow: [BoxShadow(color: colors[1].withAlpha(p.dark ? 90 : 70), blurRadius: 28, offset: const Offset(0, 12))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(children: [
          // мягкие световые пятна
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 170,
              height: 170,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)]),
              ),
            ),
          ),
          Positioned(
            left: -60,
            bottom: -70,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)]),
              ),
            ),
          ),
          // стеклянная рамка
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: glassLine, width: 1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    w.Text(date.toUpperCase(),
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: Color(0xD9FFFFFF))),
                    const SizedBox(height: 6),
                    w.Text(logged ? '${tr(hello)},' : tr('Добро пожаловать!'),
                        style: heading(logged ? 18 : 24, weight: FontWeight.w700, color: const Color(0xF2FFFFFF))),
                    if (logged)
                      w.Text('$name $glyph',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: heading(28, weight: FontWeight.w800, color: white, height: 1.15)),
                  ]),
                ),
                GestureDetector(
                  onTap: () => logged ? push(context, const ProfileScreen()) : app.setGuest(false),
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x55FFFFFF)),
                    child: Avatar(name: logged ? app.userName : '?', url: app.profile?.avatarUrl, size: 46),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: chip(
                    Row(children: [
                      Ico('pin', size: 16, color: white),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: white)),
                      ),
                    ]),
                    onTap: () => push(context, GuideCityScreen(city: weatherCity)),
                  ),
                ),
                const SizedBox(width: 8),
                FutureBuilder<List<num?>>(
                  future: cityWeather(weatherCity),
                  builder: (_, snap) {
                    final d = snap.data;
                    if (d == null || d[0] == null) return const SizedBox.shrink();
                    return chip(
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        w.Text('${weatherIcon(d[1])} ${d[0]!.round()}°',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: white)),
                        if (d[2] != null) ...[
                          const SizedBox(width: 8),
                          w.Text('🌊 ${d[2]!.round()}°', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: white)),
                        ],
                      ]),
                      onTap: () => push(context, GuideCityScreen(city: weatherCity)),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 8),
              chip(
                Row(children: [
                  for (final (i, t) in [
                    ('\$ ${egpPerUsd.toStringAsFixed(1)}', 'EGP'),
                    ('€ ${egpPerEur.toStringAsFixed(1)}', 'EGP'),
                    ('${fmt(100 * rubPerEgp)} ₽', '100 EGP'),
                  ].indexed) ...[
                    if (i > 0) Container(width: .8, height: 26, color: glassLine, margin: const EdgeInsets.symmetric(horizontal: 8)),
                    Expanded(
                      child: Column(children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: w.Text(t.$1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: white)),
                        ),
                        w.Text(t.$2, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xCCFFFFFF))),
                      ]),
                    ),
                  ],
                ]),
                onTap: onRates,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
