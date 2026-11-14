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
    final logged = app.user != null;
    final city = app.city != cities.first ? app.city : (app.profile?.city ?? 'Хургада');
    final wc = _weatherCity(city);
    final hour = DateTime.now().hour;
    final hello = hour < 5
        ? 'Доброй ночи'
        : hour < 12
            ? 'Доброе утро'
            : hour < 18
                ? 'Добрый день'
                : 'Добрый вечер';

    final group = (app.lang == 'ru' || app.lang == 'uk') ? 'ru' : 'en';
    final news = app.news.where((n) => n.published && (n.lang == null || n.lang == group)).take(4).toList();
    final fresh = app.posts.where((x) => app.city == cities.first || x.city == app.city).take(4).toList();

    // [иконка, название, действие]
    final actions = <(String, String, VoidCallback)>[
      ('tag', 'Объявления', () => openTab(0)),
      ('tool', 'Услуги', () => openTab(1)),
      ('bag', 'Работа', () => openTab(2)),
      ('news', 'Новости', () => openTab(3)),
      ('alert', 'SOS', () => push(context, const SosScreen())),
      ('coin', 'Цены', () => push(context, const FairPricesScreen())),
      ('pyramid', 'Путеводитель', () => push(context, const GuideScreen())),
      ('gift', 'Скидки', () => push(context, const PromosScreen())),
      ('shield', 'Проверенные', () => push(context, const TrustedScreen())),
      ('pin', 'Рядом', () => push(context, const NearbyScreen())),
      ('chat', 'Разговорник', () => push(context, const PhrasebookScreen())),
      ('grid', 'Полезное', () => openTab(4)),
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
            // Приветствие, город, погода, курс
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: p.primaryGradient, borderRadius: BorderRadius.circular(22)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                w.Text(logged ? '${tr(hello)}, ${app.userName.split(' ').first}!' : tr('Добро пожаловать!'),
                    style: heading(21, weight: FontWeight.w800, color: p.onPrimary)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => push(context, GuideCityScreen(city: wc)),
                  child: Row(children: [
                    Ico('pin', size: 15, color: p.onPrimary),
                    const SizedBox(width: 4),
                    Text(city, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.onPrimary)),
                    const SizedBox(width: 10),
                    WeatherLine(city: wc, light: true),
                  ]),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => openTab(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Ico('coin', size: 16, color: p.onPrimary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: w.Text(
                            '1 \$ = ${egpPerUsd.toStringAsFixed(1)} EGP  ·  1 € = ${egpPerEur.toStringAsFixed(1)}  ·  100 EGP = ${fmt(100 * rubPerEgp)} ₽',
                            maxLines: 1,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.onPrimary),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            // Быстрый доступ
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: .95,
              children: [
                for (final a in actions)
                  Box(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    radius: 16,
                    onTap: a.$3,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: a.$2 == 'SOS' ? p.bad.withAlpha(36) : p.sel, borderRadius: BorderRadius.circular(12)),
                        child: Center(child: Ico(a.$1, size: 19, color: a.$2 == 'SOS' ? p.bad : p.accent)),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(a.$2,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: p.text)),
                      ),
                    ]),
                  ),
              ],
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
