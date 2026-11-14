// Раздел «Недвижимость»: параметры жилья, форма, характеристики и быстрые фильтры.
import 'package:flutter/material.dart' hide Text;

import 'data.dart';
import 'i18n.dart';
import 'main.dart';

const realtyTypes = ['Квартира', 'Студия', 'Комната', 'Вилла', 'Таунхаус', 'Дом / шале', 'Коммерческая'];
const realtyRooms = ['Студия', '1', '2', '3', '4+'];
const seaOptions = ['Первая линия', 'До 500 м', 'До 1 км', 'До 3 км', 'Далеко от моря'];

/// [ключ, подпись, иконка]
const realtyFeatures = <List<String>>[
  ['furnished', 'С мебелью', 'sofa'],
  ['pool', 'Бассейн', 'sun'],
  ['ac', 'Кондиционер', 'sun'],
  ['wifi', 'Интернет', 'globe'],
  ['pets', 'Можно с животными', 'heart'],
  ['parking', 'Парковка', 'car'],
];

/// Категории, где у объявления есть параметры жилья.
bool realtyHasSpecs(String category) => category != 'Риелторы и услуги';

String roomsText(String r) => r == 'Студия' ? tr('Студия') : tr('{n} комн.', {'n': r});

/// Короткая строка для карточки: «2 комн. · 75 м² · до 500 м».
String realtySummary(Post p) {
  final d = p.details;
  return [
    if (d['rooms'] != null) roomsText(d['rooms'] as String),
    if (d['area'] != null) '${d['area']} м²',
    if (d['sea'] != null) tr(d['sea'] as String),
  ].join(' · ');
}

/// Блок характеристик на странице объявления.
class RealtySpecs extends StatelessWidget {
  const RealtySpecs({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final d = post.details;
    final rows = <(String, String, String)>[
      if (d['type'] != null) ('home', 'Тип', tr(d['type'] as String)),
      if (d['rooms'] != null) ('key', 'Комнаты', roomsText(d['rooms'] as String)),
      if (d['area'] != null) ('grid', 'Площадь', '${d['area']} м²'),
      if (d['floor'] != null) ('menu', 'Этаж', '${d['floor']}'),
      if (d['sea'] != null) ('sun', 'До моря', tr(d['sea'] as String)),
      if ((d['place'] ?? '').toString().isNotEmpty) ('pin', 'Район / компаунд', d['place'].toString()),
    ];
    final feats = [for (final f in realtyFeatures) if (d[f[0]] == true) f];
    if (rows.isEmpty && feats.isEmpty) return const SizedBox.shrink();
    return Box(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Параметры жилья', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: p.text)),
        const SizedBox(height: 8),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Ico(r.$1, size: 17, color: p.accent),
              const SizedBox(width: 10),
              Expanded(child: Text(r.$2, style: TextStyle(fontSize: 14, color: p.muted))),
              Flexible(child: Text(r.$3, textAlign: TextAlign.end, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.text))),
            ]),
          ),
        if (feats.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final f in feats)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: p.sel, borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Ico('check', size: 14, color: p.accent),
                  const SizedBox(width: 4),
                  Text(f[1], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.text)),
                ]),
              ),
          ]),
        ],
      ]),
    );
  }
}

/// Поля жилья в форме объявления. Меняет [details] на месте.
class RealtyForm extends StatefulWidget {
  const RealtyForm({super.key, required this.details, required this.category});
  final Map<String, dynamic> details;
  final String category;

  @override
  State<RealtyForm> createState() => _RealtyFormState();
}

class _RealtyFormState extends State<RealtyForm> {
  late final area = TextEditingController(text: widget.details['area']?.toString() ?? '');
  late final floor = TextEditingController(text: widget.details['floor']?.toString() ?? '');
  late final place = TextEditingController(text: widget.details['place']?.toString() ?? '');

  Map<String, dynamic> get d => widget.details;

  @override
  void dispose() {
    area.dispose();
    floor.dispose();
    place.dispose();
    super.dispose();
  }

  Widget chip(String label, bool on, VoidCallback onTap) {
    final p = Pal.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: on ? p.primary : p.soft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? p.primary : p.line),
        ),
        child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: on ? p.onPrimary : p.text)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    const gap = SizedBox(height: 14);
    final label = TextStyle(fontSize: 13, color: p.muted, fontWeight: FontWeight.w600);
    final wanted = widget.category == 'Ищу жильё';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PickField(
        label: wanted ? 'Какое жильё ищете' : 'Тип жилья',
        value: (d['type'] as String?) ?? realtyTypes.first,
        options: realtyTypes,
        onChanged: (v) => setState(() => d['type'] = v),
      ),
      gap,
      Text(wanted ? 'Сколько комнат нужно' : 'Комнат', style: label),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final r in realtyRooms)
          chip(r, d['rooms'] == r, () => setState(() => d['rooms'] == r ? d.remove('rooms') : d['rooms'] = r)),
      ]),
      if (!wanted) ...[
        gap,
        Row(children: [
          Expanded(
            child: Field(
              label: 'Площадь, м²',
              controller: area,
              hint: '75',
              keyboard: TextInputType.number,
              onChanged: (v) {
                final n = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
                n == null ? d.remove('area') : d['area'] = n;
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Field(
              label: 'Этаж',
              controller: floor,
              hint: '3 из 5',
              onChanged: (v) => v.trim().isEmpty ? d.remove('floor') : d['floor'] = v.trim(),
            ),
          ),
        ]),
      ],
      gap,
      PickField(
        label: 'До моря',
        value: (d['sea'] as String?) ?? 'Не важно',
        options: ['Не важно', ...seaOptions],
        onChanged: (v) => setState(() => v == 'Не важно' ? d.remove('sea') : d['sea'] = v),
      ),
      gap,
      Field(
        label: 'Район или компаунд',
        controller: place,
        hint: 'Например: Мамша, Аль-Ахья, Сахл-Хашиш',
        onChanged: (v) => v.trim().isEmpty ? d.remove('place') : d['place'] = v.trim(),
      ),
      gap,
      Text(wanted ? 'Что важно' : 'Удобства', style: label),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final f in realtyFeatures)
          chip(f[1], d[f[0]] == true, () => setState(() => d[f[0]] == true ? d.remove(f[0]) : d[f[0]] = true)),
      ]),
    ]);
  }
}

/// Быстрые фильтры жилья под строкой поиска.
class RealtyQuickFilters extends StatelessWidget {
  const RealtyQuickFilters({super.key, required this.f, required this.onChanged});
  final Filters f;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget chip(String label, bool on, VoidCallback tap) => GestureDetector(
          onTap: () {
            tap();
            onChanged();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? p.accent.withAlpha(46) : p.soft,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: on ? p.accent : p.line),
            ),
            child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: on ? p.accent : p.text)),
          ),
        );
    final items = <Widget>[
      for (final r in realtyRooms) chip(r == 'Студия' ? 'Студия' : '$r ${tr('комн.')}', f.rooms == r, () => f.rooms = f.rooms == r ? null : r),
      chip('У моря', f.nearSea, () => f.nearSea = !f.nearSea),
      chip('С мебелью', f.furnished, () => f.furnished = !f.furnished),
      chip('Бассейн', f.pool, () => f.pool = !f.pool),
      chip('С животными', f.pets, () => f.pets = !f.pets),
    ];
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => items[i],
      ),
    );
  }
}
