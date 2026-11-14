// Для туриста: честные цены, проверенные гиды, рядом со мной, SOS, скидки партнёров.
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' as w show Text;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data.dart';
import 'features.dart';
import 'guide.dart';
import 'i18n.dart';
import 'main.dart';

bool get _ru => appLang == 'ru' || appLang == 'uk';

String _egp(int v) => '${fmt(v.toDouble())} EGP';

/// Открывает ссылку прямо в обработчике нажатия (Safari блокирует открытие после ожиданий).
void _launch(BuildContext context, String url) {
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).then((ok) {
    if (!ok && context.mounted) toast(context, 'Не удалось открыть ссылку');
  }).catchError((_) {
    if (context.mounted) toast(context, 'Не удалось открыть ссылку');
  });
}

Widget _page(BuildContext context, String title, List<Widget> children, {Widget? fab}) => Scaffold(
      floatingActionButton: fab,
      body: Column(children: [
        SubHeader(title: title),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 90 + MediaQuery.of(context).padding.bottom),
            children: children,
          ),
        ),
      ]),
    );

Widget _note(BuildContext context, String text, {String icon = 'help'}) {
  final p = Pal.of(context);
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: p.infobg, borderRadius: BorderRadius.circular(14)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Ico(icon, size: 18, color: p.info),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: TextStyle(fontSize: 13.5, color: p.info, height: 1.4))),
    ]),
  );
}

// =====================================================================
// Честные цены
// =====================================================================

class FairPricesScreen extends StatelessWidget {
  const FairPricesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    AppScope.of(context); // перестроить, когда загрузится курс
    return _page(context, 'Честные цены', [
      _note(context,
          tr('Сколько это должно стоить в Хургаде и на курортах ({d}). Нажмите на строку, чтобы проверить цену, которую вам назвали.',
              {'d': tr(fairPricesUpdated)}),
          icon: 'coin'),
      const SizedBox(height: 10),
      Box(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Как не переплатить', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: p.text)),
          const SizedBox(height: 6),
          for (final t in const [
            'Договаривайтесь о цене до поездки или покупки — и в фунтах, не в долларах.',
            'На рынке начинайте с трети от первой цены.',
            'Такси надёжнее заказывать в Uber, Careem или inDrive.',
            'Носите мелкие купюры: «сдачи нет» — частый приём.',
          ])
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('•  ', style: TextStyle(color: p.accent, fontWeight: FontWeight.w800)),
                Expanded(child: Text(t, style: TextStyle(fontSize: 13.5, color: p.body, height: 1.35))),
              ]),
            ),
        ]),
      ),
      for (final g in fairPrices) ...[
        SectionTitle(_ru ? g.$1 : g.$2),
        const SizedBox(height: 6),
        Box(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < g.$3.length; i++) ...[
              if (i > 0) Divider(height: 1, color: p.line),
              _PriceRow(item: g.$3[i]),
            ],
          ]),
        ),
      ],
      const SizedBox(height: 14),
      Text('Цены — ориентир. В Каире и Шарме они немного выше, в маленьких городах — ниже.',
          style: TextStyle(fontSize: 12.5, color: p.muted, height: 1.4)),
    ]);
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.item});
  final FairPrice item;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final note = _ru ? item.noteRu : item.noteEn;
    final range = item.min == item.max ? _egp(item.min) : '${fmt(item.min.toDouble())}–${_egp(item.max)}';
    return InkWell(
      onTap: () => showGlassSheet<void>(context, (_) => _PriceCheckSheet(item: item)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_ru ? item.ru : item.en, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: p.text)),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(note, style: TextStyle(fontSize: 12, color: p.muted)),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            w.Text(range, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: p.accent)),
            w.Text('≈ ${fmt(item.max / egpPerUsd)} \$ · ${fmt(item.max * rubPerEgp)} ₽',
                style: TextStyle(fontSize: 11.5, color: p.muted)),
          ]),
        ]),
      ),
    );
  }
}

class _PriceCheckSheet extends StatefulWidget {
  const _PriceCheckSheet({required this.item});
  final FairPrice item;

  @override
  State<_PriceCheckSheet> createState() => _PriceCheckSheetState();
}

class _PriceCheckSheetState extends State<_PriceCheckSheet> {
  final ctl = TextEditingController();
  String cur = 'EGP';

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  double? get egp {
    final v = double.tryParse(ctl.text.replaceAll(',', '.').replaceAll(' ', ''));
    if (v == null || v <= 0) return null;
    return switch (cur) { 'USD' => v * egpPerUsd, 'EUR' => v * egpPerEur, 'RUB' => v / rubPerEgp, _ => v };
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final it = widget.item;
    final v = egp;
    String? verdict;
    Color fg = p.ok, bg = p.okbg;
    if (v != null) {
      if (v <= it.max * 1.1) {
        verdict = v < it.min * 0.6 ? 'Подозрительно дёшево — уточните, что входит в цену.' : 'Нормальная цена 👍';
      } else if (v <= it.max * 1.7) {
        verdict = 'Дороговато — можно поторговаться.';
        fg = p.warn;
        bg = p.warnbg;
      } else {
        verdict = 'Похоже на развод. Нормально — {r}.';
        fg = p.bad;
        bg = p.bad.withAlpha(30);
      }
    }
    final range = it.min == it.max ? _egp(it.min) : '${fmt(it.min.toDouble())}–${_egp(it.max)}';
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 6, 18, 18 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_ru ? it.ru : it.en, style: heading(19, weight: FontWeight.w800, color: p.text)),
          const SizedBox(height: 4),
          Text(tr('Нормальная цена: {r}', {'r': range}), style: TextStyle(fontSize: 14, color: p.muted)),
          const SizedBox(height: 14),
          Field(
            label: 'Сколько вам назвали?',
            controller: ctl,
            hint: '0',
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Segments<String>(
            values: const ['EGP', 'USD', 'EUR', 'RUB'],
            labels: const ['EGP', '\$', '€', '₽'],
            selected: cur,
            onChanged: (x) => setState(() => cur = x),
          ),
          if (verdict != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(verdict, {'r': range}), style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: fg)),
                if (cur != 'EGP') ...[
                  const SizedBox(height: 4),
                  w.Text('= ${_egp(v!.round())}', style: TextStyle(fontSize: 13, color: fg)),
                ],
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

// =====================================================================
// Проверенные гиды, трансферы, дайвинг
// =====================================================================

class TrustedScreen extends StatefulWidget {
  const TrustedScreen({super.key});

  @override
  State<TrustedScreen> createState() => _TrustedScreenState();
}

class _TrustedScreenState extends State<TrustedScreen> {
  int kind = 0;

  static const kinds = ['Экскурсии', 'Трансфер и такси', 'Дайвинг'];

  bool match(Post x) {
    switch (kind) {
      case 0:
        return x.section == Section.services && x.category == 'Экскурсии';
      case 1:
        return x.section == Section.services && x.category == 'Трансфер и такси';
      default:
        final t = '${x.title} ${x.description}'.toLowerCase();
        return x.category == 'Спорт и дайвинг' ||
            (x.section == Section.services && (t.contains('дайв') || t.contains('div') || t.contains('снорк')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final all = app.posts.where(match).where((x) => app.city == cities.first || x.city == app.city).toList();
    double score(Post x) => (x.verified ? 100 : 0) + (app.ratings[x.userId] ?? 0) * 10 + (app.reviewCounts[x.userId] ?? 0);
    all.sort((a, b) => score(b).compareTo(score(a)));
    final verified = all.where((x) => x.verified).length;
    return _page(context, 'Проверенные', [
      _note(context,
          'Сначала показаны исполнители с галочкой — они подтвердили профиль через Telegram. Звёзды ставят только после реальной сделки.',
          icon: 'shield'),
      const SizedBox(height: 12),
      Segments<int>(
        values: const [0, 1, 2],
        labels: kinds,
        selected: kind,
        onChanged: (x) => setState(() => kind = x),
      ),
      const SizedBox(height: 6),
      if (all.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
          child: Text(tr('Найдено: {n}, с галочкой: {v}', {'n': '${all.length}', 'v': '$verified'}),
              style: TextStyle(fontSize: 12.5, color: p.muted)),
        ),
      if (all.isEmpty)
        EmptyState(
          icon: 'shield',
          text: app.city == cities.first
              ? 'Пока никого нет. Вы гид или водитель? Разместите услугу — это бесплатно.'
              : 'В этом городе пока никого нет. Выберите «Все города» на главной или разместите свою услугу.',
          action: 'Разместить услугу',
          onAction: () => _addService(context),
        )
      else ...[
        for (final x in all) Padding(padding: const EdgeInsets.only(top: 8), child: PostCard(post: x)),
        const SizedBox(height: 16),
        OutlineBtn('Я гид или водитель — разместить услугу', height: 48, color: p.text, onPressed: () => _addService(context)),
      ],
    ]);
  }

  void _addService(BuildContext context) {
    final app = AppScope.of(context);
    if (app.user == null) {
      askLogin(context, 'Войдите или зарегистрируйтесь, чтобы разместить услугу.');
      return;
    }
    push(context, const AddPostScreen(section: Section.services));
  }
}

// =====================================================================
// Рядом со мной
// =====================================================================

class NearbyScreen extends StatelessWidget {
  const NearbyScreen({super.key});

  static const places = <List<String>>[
    // иконка, название, поиск в Google Картах
    ['heart', 'Аптека', 'pharmacy'],
    ['alert', 'Больница', 'hospital'],
    ['coin', 'Обменник', 'currency exchange'],
    ['coin', 'Банкомат', 'ATM'],
    ['bag', 'Супермаркет', 'supermarket'],
    ['menu', 'Кафе и рестораны', 'restaurant'],
    ['sun', 'Пляж', 'beach'],
    ['phone', 'Магазин сим-карт', 'Vodafone store'],
  ];

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return _page(context, 'Рядом со мной', [
      _note(context, 'Откроются Google Карты с ближайшими местами. Разрешите картам доступ к геолокации.', icon: 'pin'),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.3,
        children: [
          for (final x in places)
            Box(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onTap: () => _launch(context, 'https://www.google.com/maps/search/${Uri.encodeComponent('${x[2]} near me')}'),
              child: Row(children: [
                Ico(x[0], size: 20, color: p.accent),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(x[1],
                        maxLines: 2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.text))),
              ]),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Text('Совет: заранее скачайте карту своего города офлайн в Google Картах.',
          style: TextStyle(fontSize: 12.5, color: p.muted, height: 1.4)),
    ]);
  }
}

// =====================================================================
// SOS
// =====================================================================

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  String insName = '', insPhone = '', insPolicy = '', hotel = '';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        insName = p.getString('sos_ins_name') ?? '';
        insPhone = p.getString('sos_ins_phone') ?? '';
        insPolicy = p.getString('sos_ins_policy') ?? '';
        hotel = p.getString('sos_hotel') ?? '';
      });
    }).catchError((_) {});
  }

  Future<void> edit() async {
    final a = TextEditingController(text: insName),
        b = TextEditingController(text: insPhone),
        c = TextEditingController(text: insPolicy),
        d = TextEditingController(text: hotel);
    final ok = await showGlassSheet<bool>(context, (ctx) {
      final p = Pal.of(ctx);
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 6, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Мои данные на экстренный случай', style: heading(18, weight: FontWeight.w800, color: p.text)),
              const SizedBox(height: 4),
              Text('Хранятся только на этом телефоне.', style: TextStyle(fontSize: 13, color: p.muted)),
              const SizedBox(height: 12),
              Field(label: 'Страховая компания', controller: a, hint: 'Например, Ингосстрах'),
              const SizedBox(height: 10),
              Field(label: 'Телефон ассистанса страховой', controller: b, hint: '+7 …', keyboard: TextInputType.phone),
              const SizedBox(height: 10),
              Field(label: 'Номер полиса', controller: c),
              const SizedBox(height: 10),
              Field(label: 'Мой отель и адрес', controller: d, hint: 'Название и район', maxLines: 2),
              const SizedBox(height: 14),
              PrimaryButton('Сохранить', onPressed: () => Navigator.pop(ctx, true)),
            ]),
          ),
        ),
      );
    });
    if (ok == true) {
      setState(() {
        insName = a.text.trim();
        insPhone = b.text.trim();
        insPolicy = c.text.trim();
        hotel = d.text.trim();
      });
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString('sos_ins_name', insName);
        await p.setString('sos_ins_phone', insPhone);
        await p.setString('sos_ins_policy', insPolicy);
        await p.setString('sos_hotel', hotel);
      } catch (_) {}
    }
    for (final x in [a, b, c, d]) {
      x.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget call(String title, String number, Color color) => Expanded(
          child: Material(
            color: color,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _launch(context, 'tel:$number'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                child: Column(children: [
                  w.Text(number, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ),
          ),
        );
    final insDigits = contactDigits(insPhone);
    return _page(context, 'SOS', [
      Text('Нажмите — и телефон сразу наберёт номер.', style: TextStyle(fontSize: 13.5, color: p.muted)),
      const SizedBox(height: 10),
      Row(children: [
        call('Скорая помощь', '123', const Color(0xFFD64545)),
        const SizedBox(width: 10),
        call('Туристическая полиция', '126', const Color(0xFF2F6FD6)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        call('Полиция', '122', const Color(0xFF3A4A6B)),
        const SizedBox(width: 10),
        call('Пожарная служба', '180', const Color(0xFFE07B2A)),
      ]),
      SectionTitle('Моя страховка и отель', action: 'Изменить', onAction: edit),
      const SizedBox(height: 6),
      Box(
        onTap: edit,
        child: insName.isEmpty && insPhone.isEmpty && hotel.isEmpty
            ? Row(children: [
                Ico('shield', size: 20, color: p.accent),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('Добавьте телефон страховой и адрес отеля — в стрессе их трудно искать.',
                        style: TextStyle(fontSize: 13.5, color: p.body, height: 1.35))),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (insName.isNotEmpty || insPolicy.isNotEmpty)
                  w.Text([insName, if (insPolicy.isNotEmpty) '№ $insPolicy'].where((x) => x.isNotEmpty).join(' · '),
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: p.text)),
                if (insDigits.length >= 6) ...[
                  const SizedBox(height: 8),
                  PrimaryButton(tr('Позвонить в страховую: {n}', {'n': insPhone}),
                      height: 44, onPressed: () => _launch(context, 'tel:+$insDigits')),
                ],
                if (hotel.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Мой отель', style: TextStyle(fontSize: 12.5, color: p.muted)),
                  w.Text(hotel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text)),
                ],
              ]),
      ),
      SectionTitle('Фразы на арабском'),
      const SizedBox(height: 4),
      Text('Нажмите на фразу — она откроется крупно, чтобы показать собеседнику.',
          style: TextStyle(fontSize: 12.5, color: p.muted)),
      const SizedBox(height: 6),
      for (final f in sosPhrases)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Box(
            padding: const EdgeInsets.all(12),
            onTap: () => showGlassSheet<void>(
              context,
              (ctx) => SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    w.Text(f[2],
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: Pal.of(ctx).text)),
                    const SizedBox(height: 10),
                    w.Text(_ru ? f[3] : f[4], style: TextStyle(fontSize: 18, color: Pal.of(ctx).accent)),
                  ]),
                ),
              ),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  w.Text(_ru ? f[0] : f[1], style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text)),
                  w.Text(_ru ? f[3] : f[4], style: TextStyle(fontSize: 13, color: p.accent)),
                ]),
              ),
              w.Text(f[2], textDirection: TextDirection.rtl, style: TextStyle(fontSize: 18, color: p.text, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      const SizedBox(height: 16),
      OutlineBtn('Посольства', height: 46, color: p.text, onPressed: () => push(context, const EmbassiesScreen())),
      const SizedBox(height: 8),
      OutlineBtn('Больница или аптека рядом', height: 46, color: p.text, onPressed: () => push(context, const NearbyScreen())),
    ]);
  }
}

// =====================================================================
// Скидки партнёров
// =====================================================================

class Promo {
  Promo(Map m)
      : id = m['id'] as String,
        partner = (m['partner'] ?? '') as String,
        city = (m['city'] ?? '') as String,
        title = (m['title'] ?? '') as String,
        details = (m['details'] ?? '') as String,
        code = (m['code'] ?? '') as String,
        contact = (m['contact'] ?? '') as String,
        until = DateTime.tryParse((m['until'] ?? '') as String),
        active = (m['active'] ?? true) as bool;
  final String id, partner, city, title, details, code, contact;
  final DateTime? until;
  final bool active;
}

class PromosScreen extends StatefulWidget {
  const PromosScreen({super.key});

  @override
  State<PromosScreen> createState() => _PromosScreenState();
}

class _PromosScreenState extends State<PromosScreen> {
  List<Promo>? items;
  bool failed = false;

  SupabaseClient get sb => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final rows = await sb.from('promos').select().order('created_at', ascending: false).limit(200);
      if (!mounted) return;
      setState(() {
        items = rows.map<Promo>((m) => Promo(m)).toList();
        failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final list = (items ?? [])
        .where((x) => app.city == cities.first || x.city == cities.first || x.city == app.city)
        .toList();
    return _page(
      context,
      'Скидки',
      [
        _note(context, 'Скидки от проверенных партнёров для пользователей приложения. Назовите промокод при заказе.',
            icon: 'gift'),
        const SizedBox(height: 8),
        if (items == null && !failed)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (failed)
          EmptyState(icon: 'alert', text: 'Нет связи с сервером.', action: 'Повторить', onAction: load)
        else if (list.isEmpty)
          const EmptyState(
              icon: 'gift', text: 'Скоро здесь появятся скидки от кафе, дайв-центров и гидов. Загляните позже!')
        else
          for (final x in list) Padding(padding: const EdgeInsets.only(top: 8), child: _promoCard(context, x, app.isAdmin)),
        if (!app.isAdmin) ...[
          const SizedBox(height: 16),
          Text('Есть бизнес и хотите сюда? Напишите в поддержку — разместим бесплатно.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: p.muted, height: 1.4)),
        ],
      ],
      fab: app.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => editPromo(null),
              backgroundColor: p.primary,
              foregroundColor: p.onPrimary,
              icon: Ico('plus', size: 20, color: p.onPrimary),
              label: const Text('Добавить'),
            )
          : null,
    );
  }

  Widget _promoCard(BuildContext context, Promo x, bool admin) {
    final p = Pal.of(context);
    return Box(
      onTap: admin ? () => editPromo(x) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: w.Text(x.partner, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.accent))),
          if (x.city != cities.first) Pill(x.city, bg: p.sel, fg: p.accent),
          if (admin && !x.active) ...[const SizedBox(width: 6), Pill('Скрыта', bg: p.warnbg, fg: p.warn)],
        ]),
        const SizedBox(height: 4),
        w.Text(x.title, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: p.text)),
        if (x.details.isNotEmpty) ...[
          const SizedBox(height: 4),
          w.Text(x.details, style: TextStyle(fontSize: 13.5, color: p.body, height: 1.4)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          if (x.code.isNotEmpty)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: x.code));
                  toast(context, 'Промокод скопирован');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10), border: Border.all(color: p.accent, width: 1.3)),
                  child: Row(children: [
                    Expanded(
                        child: w.Text(x.code,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1, color: p.accent))),
                    Ico('copy', size: 16, color: p.accent),
                  ]),
                ),
              ),
            )
          else
            const Spacer(),
          if (x.contact.isNotEmpty) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => openContact(context, telegramUser(x.contact) != null ? 'tg' : 'wa', x.contact),
              style: TextButton.styleFrom(foregroundColor: p.accent),
              child: const Text('Связаться'),
            ),
          ],
        ]),
        if (x.until != null) ...[
          const SizedBox(height: 6),
          w.Text(tr('До {d}', {'d': '${x.until!.day.toString().padLeft(2, '0')}.${x.until!.month.toString().padLeft(2, '0')}.${x.until!.year}'}),
              style: TextStyle(fontSize: 12, color: p.muted)),
        ],
      ]),
    );
  }

  Future<void> editPromo(Promo? x) async {
    final partner = TextEditingController(text: x?.partner ?? ''),
        title = TextEditingController(text: x?.title ?? ''),
        details = TextEditingController(text: x?.details ?? ''),
        code = TextEditingController(text: x?.code ?? ''),
        contact = TextEditingController(text: x?.contact ?? ''),
        days = TextEditingController(text: '');
    var city = x?.city ?? cities.first;
    var active = x?.active ?? true;
    final res = await showGlassSheet<String>(context, (ctx) {
      final p = Pal.of(ctx);
      return StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 6, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(x == null ? 'Новая скидка' : 'Скидка', style: heading(18, weight: FontWeight.w800, color: p.text)),
                const SizedBox(height: 12),
                Field(label: 'Партнёр', controller: partner, hint: 'Кафе «Нил»'),
                const SizedBox(height: 10),
                Field(label: 'Что за скидка', controller: title, hint: '−15% на всё меню'),
                const SizedBox(height: 10),
                Field(label: 'Подробности', controller: details, maxLines: 3),
                const SizedBox(height: 10),
                Field(label: 'Промокод', controller: code, hint: 'SVOI15'),
                const SizedBox(height: 10),
                Field(label: 'Контакт (телефон или @telegram)', controller: contact),
                const SizedBox(height: 10),
                Field(label: 'Сколько дней действует (пусто — бессрочно)', controller: days, keyboard: TextInputType.number),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: city,
                  items: [for (final c in cities) DropdownMenuItem(value: c, child: Text(c))],
                  onChanged: (v) => set(() => city = v ?? city),
                  decoration: const InputDecoration(labelText: 'Город'),
                ),
                SwitchListTile(
                  value: active,
                  onChanged: (v) => set(() => active = v),
                  title: const Text('Показывать'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                PrimaryButton('Сохранить', onPressed: () => Navigator.pop(ctx, 'save')),
                if (x != null)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'delete'),
                    style: TextButton.styleFrom(foregroundColor: p.bad),
                    child: const Text('Удалить'),
                  ),
              ]),
            ),
          ),
        ),
      );
    });
    try {
      if (res == 'save') {
        final d = int.tryParse(days.text.trim());
        final row = {
          'partner': partner.text.trim(),
          'title': title.text.trim(),
          'details': details.text.trim(),
          'code': code.text.trim().toUpperCase(),
          'contact': contact.text.trim(),
          'city': city,
          'active': active,
          if (d != null && d > 0) 'until': DateTime.now().add(Duration(days: d)).toIso8601String().substring(0, 10),
        };
        if (x == null) {
          await sb.from('promos').insert(row);
        } else {
          await sb.from('promos').update(row).eq('id', x.id);
        }
        if (mounted) toast(context, 'Сохранено');
      } else if (res == 'delete' && x != null) {
        await sb.from('promos').delete().eq('id', x.id);
        if (mounted) toast(context, 'Удалено');
      }
    } catch (e) {
      if (mounted) toast(context, 'Не удалось сохранить. Проверьте поля: партнёр и название обязательны.');
    }
    for (final c in [partner, title, details, code, contact, days]) {
      c.dispose();
    }
    if (res != null) load();
  }
}
