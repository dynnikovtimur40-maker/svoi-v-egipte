// Для новичка: приветствие при первом запуске, режимы «турист / житель»,
// «Покажи таксисту» (фразы крупно на арабском с озвучкой), «Первые 30 дней» и визовый таймер.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' as w show Text;
import 'package:flutter_tts/flutter_tts.dart';

import 'config.dart';
import 'features.dart';
import 'i18n.dart';
import 'main.dart';
import 'tourist.dart';

bool get _ru => appLang == 'ru' || appLang == 'uk';

// =====================================================================
// Плавное появление
// =====================================================================

/// Блок мягко «всплывает» при первом показе. delay — задержка в миллисекундах.
class Appear extends StatefulWidget {
  const Appear({super.key, required this.child, this.delay = 0});
  final Widget child;
  final int delay;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 460));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  late final Animation<Offset> _o = Tween<Offset>(begin: const Offset(0, .07), end: Offset.zero).animate(_a);
  Timer? _t;

  @override
  void initState() {
    super.initState();
    if (widget.delay <= 0) {
      _c.forward();
    } else {
      _t = Timer(Duration(milliseconds: widget.delay), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _a, child: SlideTransition(position: _o, child: widget.child));
}

/// Небольшая кнопка-«таблетка» для выбора варианта.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap, this.raw = false});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool raw;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final style = TextStyle(
        fontSize: 13.5, fontWeight: FontWeight.w600, color: selected ? p.onPrimary : p.text);
    return Material(
      color: selected ? p.primary : p.card,
      shape: StadiumBorder(side: BorderSide(color: selected ? p.primary : p.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: raw ? w.Text(label, style: style) : Text(label, style: style),
        ),
      ),
    );
  }
}

// =====================================================================
// Приветствие при первом запуске
// =====================================================================

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _bg =
      AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  final _pages = PageController();
  int page = 0;
  String? mode;

  @override
  void dispose() {
    _bg.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    _pages.animateToPage(1, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  Widget _blob(Color c, double size, double dx, double dy, double phase) => AnimatedBuilder(
        animation: _bg,
        builder: (_, child) {
          final t = _bg.value * 2 * math.pi + phase;
          return Align(
            alignment: Alignment(dx + .25 * math.sin(t), dy + .18 * math.cos(t * 1.3)),
            child: child,
          );
        },
        child: IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [c, c.withAlpha(0)]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final pad = MediaQuery.of(context).padding;

    Widget modeCard(String id, String icon, String title, String sub, List<Color> colors) {
      final sel = mode == id;
      return AnimatedScale(
        scale: sel ? 1.02 : 1,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: sel ? p.sel : p.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: sel ? p.primary : p.line, width: sel ? 1.6 : 1)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() => mode = id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
                  ),
                  child: Center(child: Ico(icon, size: 26, color: Colors.white)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: heading(18, color: p.text)),
                    const SizedBox(height: 3),
                    Text(sub, style: TextStyle(fontSize: 13.5, color: p.muted, height: 1.35)),
                  ]),
                ),
                const SizedBox(width: 8),
                AnimatedOpacity(
                  opacity: sel ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: Ico('check', size: 22, color: p.primary, stroke: 2.6),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    final first = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Appear(
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.primary, p.accent]),
            boxShadow: [BoxShadow(color: p.primary.withAlpha(90), blurRadius: 30, offset: const Offset(0, 12))],
          ),
          child: const Center(child: Ico('pyramid', size: 46, color: Colors.white, stroke: 1.8)),
        ),
      ),
      const SizedBox(height: 26),
      Appear(delay: 120, child: Text('Свои в Египте', textAlign: TextAlign.center, style: heading(32, color: p.text))),
      const SizedBox(height: 10),
      Appear(
        delay: 220,
        child: Text('Всё для отдыха и жизни в Египте — в одном приложении',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: p.body, height: 1.4)),
      ),
      const SizedBox(height: 30),
      Appear(
        delay: 340,
        child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          for (final l in appLanguages)
            _Pill(label: l[1], raw: true, selected: app.lang == l[0], onTap: () => app.setLang(l[0])),
        ]),
      ),
    ]);

    final second = Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Кто вы в Египте?', textAlign: TextAlign.center, style: heading(26, color: p.text)),
      const SizedBox(height: 8),
      Text('Мы покажем на главной то, что нужно именно вам',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: p.body, height: 1.4)),
      const SizedBox(height: 24),
      modeCard('tourist', 'sun', 'Я турист', 'Цены, экскурсии, фразы для такси, SOS и что рядом',
          const [Color(0xFFFDBA74), Color(0xFFEA580C)]),
      const SizedBox(height: 12),
      modeCard('resident', 'home', 'Я живу здесь', 'Жильё, работа, услуги, документы и первые шаги',
          const [Color(0xFF67E8F9), Color(0xFF0891B2)]),
      const SizedBox(height: 16),
      Text('Это можно изменить в любой момент на главной',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: p.muted)),
    ]);

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(children: [
        Positioned.fill(child: _blob(p.primary.withAlpha(p.dark ? 90 : 60), 420, -.7, -.8, 0)),
        Positioned.fill(child: _blob(p.accent.withAlpha(p.dark ? 70 : 50), 380, .8, .1, 2)),
        Positioned.fill(child: _blob(const Color(0xFFEA580C).withAlpha(p.dark ? 46 : 34), 340, -.5, .9, 4)),
        Padding(
          padding: EdgeInsets.fromLTRB(22, pad.top + 16, 22, pad.bottom + 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(children: [
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (i) => setState(() => page = i),
                    children: [first, second],
                  ),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < 2; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: page == i ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: page == i ? p.primary : p.line, borderRadius: BorderRadius.circular(4)),
                    ),
                ]),
                const SizedBox(height: 18),
                page == 0
                    ? PrimaryButton('Далее', onPressed: _next)
                    : PrimaryButton('Начать', onPressed: mode == null ? null : () => app.finishWelcome(mode!)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// =====================================================================
// Главная: переключатель режима и крупные карточки
// =====================================================================

class ModeSwitch extends StatelessWidget {
  const ModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    Widget side(String id, String icon, String label) {
      final sel = app.mode == id;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!sel) {
              HapticFeedback.selectionClick();
              app.setMode(id);
            }
          },
          child: SizedBox(
            height: 38,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Ico(icon, size: 16, color: sel ? p.onPrimary : p.muted),
              const SizedBox(width: 7),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: sel ? p.onPrimary : p.muted)),
              ),
            ]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.dark ? const Color(0x14FFFFFF) : const Color(0x0D0B2B33),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.dark ? const Color(0x24FFFFFF) : p.line, width: .8),
      ),
      child: Stack(children: [
        Positioned.fill(
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: app.isTourist ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
            child: FractionallySizedBox(
              widthFactor: .5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(11)),
              ),
            ),
          ),
        ),
        Row(children: [side('tourist', 'sun', 'Я турист'), side('resident', 'home', 'Я живу здесь')]),
      ]),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard(
      {required this.icon, required this.title, required this.sub, required this.colors, required this.onTap, this.progress});
  final String icon, title, sub;
  final List<Color> colors;
  final VoidCallback onTap;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        ),
        child: InkWell(
          onTap: onTap,
          child: Stack(children: [
            PositionedDirectional(
              end: -14,
              bottom: -14,
              child: Ico(icon, size: 86, color: const Color(0x26FFFFFF), stroke: 1.4),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(11)),
                  child: Center(child: Ico(icon, size: 19, color: Colors.white)),
                ),
                const Spacer(),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: heading(16.5, color: Colors.white, height: 1.15)),
                const SizedBox(height: 3),
                if (progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 5, bottom: 2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress!),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => LinearProgressIndicator(
                            value: v, minHeight: 5, backgroundColor: const Color(0x40FFFFFF), color: Colors.white),
                      ),
                    ),
                  )
                else
                  Text(sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xE6FFFFFF), height: 1.25)),
                if (progress != null)
                  w.Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xE6FFFFFF))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Две крупные карточки на главной — свои для туриста и для жителя — и строка визы.
class HomeHero extends StatelessWidget {
  const HomeHero({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final total = first30Steps.length;
    final done = first30Steps.where((s) => app.stepsDone.contains(s.id)).length;
    final left = app.visaLeft;

    final taxi = _HeroCard(
      icon: 'car',
      title: 'Покажи таксисту',
      sub: tr('Фразы на арабском — крупно и с озвучкой'),
      colors: const [Color(0xFFF59E0B), Color(0xFFEA580C)],
      onTap: () => push(context, const ShowDriverScreen()),
    );
    final prices = _HeroCard(
      icon: 'coin',
      title: 'Честные цены',
      sub: tr('Сколько что стоит на самом деле'),
      colors: const [Color(0xFF10B981), Color(0xFF0F766E)],
      onTap: () => push(context, const FairPricesScreen()),
    );
    final steps = _HeroCard(
      icon: 'calendar',
      title: 'Первые 30 дней',
      sub: tr('Сделано {a} из {b}', {'a': done, 'b': total}),
      progress: total == 0 ? 0 : done / total,
      colors: const [Color(0xFF06B6D4), Color(0xFF2563EB)],
      onTap: () => push(context, const First30Screen()),
    );
    final cards = app.isTourist ? [taxi, prices] : [steps, taxi];

    return Column(children: [
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: SizedBox(
          key: ValueKey(app.mode),
          height: 124,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 10),
            Expanded(child: cards[1]),
          ]),
        ),
      ),
      if (left != null) ...[
        const SizedBox(height: 10),
        Box(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          onTap: () => push(context, const First30Screen()),
          child: Row(children: [
            Ico('calendar', size: 18, color: visaColor(p, left)),
            const SizedBox(width: 10),
            Expanded(
              child: w.Text(visaLine(left),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text)),
            ),
            if (app.visaUntil != null)
              w.Text(tr('до {d}', {'d': dayMonth(app.visaUntil!)}), style: TextStyle(fontSize: 13, color: p.muted)),
          ]),
        ),
      ],
    ]);
  }
}

String dayMonth(DateTime d) => '${d.day} ${monthShort(d.month)}';

Color visaColor(Pal p, int left) => left <= 0 ? p.bad : (left <= 7 ? p.warn : p.ok);

String visaLine(int left) => left < 0
    ? tr('Виза закончилась')
    : left == 0
        ? tr('Виза заканчивается сегодня')
        : tr('Виза: осталось дней — {n}', {'n': left});

// =====================================================================
// «Покажи таксисту»
// =====================================================================

FlutterTts? _tts;

/// Готовит озвучку заранее, чтобы по нажатию звук шёл без задержки (важно для Safari).
void ttsInit() {
  try {
    final t = _tts ??= FlutterTts();
    t.setLanguage('ar');
    t.setSpeechRate(kIsWeb ? .8 : .42);
  } catch (_) {}
}

void speakArabic(BuildContext context, String text) {
  try {
    final t = _tts ??= FlutterTts();
    t.speak(text).catchError((_) {
      if (context.mounted) toast(context, 'Озвучка недоступна на этом устройстве');
    });
  } catch (_) {
    toast(context, 'Озвучка недоступна на этом устройстве');
  }
}

/// [раздел, иконка, название ru, название en]
const showCats = <List<String>>[
  ['taxi', 'car', 'Такси', 'Taxi'],
  ['shop', 'bag', 'Магазин', 'Shop'],
  ['food', 'gift', 'Кафе', 'Café'],
  ['health', 'alert', 'Здоровье', 'Health'],
  ['home', 'home', 'Дом', 'Home'],
  ['common', 'chat', 'Общее', 'General'],
];

/// [раздел, по-русски, по-английски, по-арабски, произношение (рус.), произношение (лат.)]
const showPhrases = <List<String>>[
  ['taxi', 'Отвезите меня по этому адресу, пожалуйста', 'Please take me to this address', 'من فضلك وصّلني للعنوان ده', 'Мин фадлак, вассальни лиль-энуан да', 'Min fadlak, wassalni lil-enwan da'],
  ['taxi', 'Сколько стоит поездка?', 'How much is the ride?', 'الأجرة كام؟', 'Эль-огра кям?', 'El-ogra kam?'],
  ['taxi', 'Включите счётчик, пожалуйста', 'Please turn on the meter', 'شغّل العداد من فضلك', 'Шаггаль эль-аддад, мин фадлак', 'Shaghghal el-addad, min fadlak'],
  ['taxi', 'Это слишком дорого', 'That is too expensive', 'ده غالي قوي', 'Да гали áуи', 'Da ghali awi'],
  ['taxi', 'В аэропорт, пожалуйста', 'To the airport, please', 'على المطار من فضلك', 'Аля эль-матар, мин фадлак', 'Ala el-matar, min fadlak'],
  ['taxi', 'Остановите здесь, пожалуйста', 'Please stop here', 'وقّف هنا من فضلك', 'Уаэф хэна, мин фадлак', 'Waaf hena, min fadlak'],
  ['taxi', 'Подождите меня, пожалуйста', 'Please wait for me', 'استناني من فضلك', 'Истаннани, мин фадлак', 'Istannani, min fadlak'],
  ['taxi', 'У вас есть сдача?', 'Do you have change?', 'معاك فكة؟', 'Маак факка?', 'Maak fakka?'],
  ['taxi', 'Прямо / Направо / Налево', 'Straight / Right / Left', 'على طول / يمين / شمال', 'Аля туль / йемин / шемаль', 'Ala tool / yemeen / shemal'],
  ['shop', 'Сколько это стоит?', 'How much is this?', 'ده بكام؟', 'Да бикям?', 'Da bikam?'],
  ['shop', 'Можно дешевле?', 'Can it be cheaper?', 'ممكن أرخص؟', 'Мумкен архас?', 'Momken arkhas?'],
  ['shop', 'Какая последняя цена?', 'What is your final price?', 'آخر كلام؟', 'Áхер калям?', 'Akher kalam?'],
  ['shop', 'Нет, спасибо, мне не нужно', 'No, thank you, I do not need it', 'لا شكراً، مش عايز', 'Ля шукран, миш айез', 'La shokran, mesh ayez'],
  ['shop', 'Я только смотрю', 'I am just looking', 'أنا بتفرج بس', 'Ана батфарраг бас', 'Ana batfarrag bass'],
  ['shop', 'Я живу здесь, я не турист', 'I live here, I am not a tourist', 'أنا ساكن هنا، مش سايح', 'Ана сакен хэна, миш сайех', 'Ana saken hena, mesh sayeh'],
  ['shop', 'Можно оплатить картой?', 'Can I pay by card?', 'ممكن أدفع بالكارت؟', 'Мумкен адфаа биль-карт?', 'Momken adfaa bel-kart?'],
  ['shop', 'Дайте чек, пожалуйста', 'A receipt, please', 'عايز فاتورة من فضلك', 'Айез фатура, мин фадлак', 'Ayez fatoora, min fadlak'],
  ['food', 'Меню, пожалуйста', 'The menu, please', 'المنيو من فضلك', 'Эль-меню, мин фадлак', 'El-menu, min fadlak'],
  ['food', 'Счёт, пожалуйста', 'The bill, please', 'الحساب من فضلك', 'Эль-хесаб, мин фадлак', 'El-hesab, min fadlak'],
  ['food', 'Без острого, пожалуйста', 'Not spicy, please', 'من غير شطة من فضلك', 'Мин гейр шатта, мин фадлак', 'Min gheir shatta, min fadlak'],
  ['food', 'Воду без льда', 'Water without ice', 'مية من غير تلج', 'Майя мин гейр тальг', 'Mayya min gheir talg'],
  ['food', 'Я не ем мясо', 'I do not eat meat', 'أنا مش باكل لحمة', 'Ана миш бáкуль лахма', 'Ana mesh bakol lahma'],
  ['food', 'Сервис включён в счёт?', 'Is service included?', 'الخدمة محسوبة؟', 'Эль-хедма махсуба?', 'El-khedma mahsooba?'],
  ['food', 'Очень вкусно!', 'Very tasty!', 'حلو قوي!', 'Хэлу áуи!', 'Helw awi!'],
  ['health', 'Мне нужен врач', 'I need a doctor', 'محتاج دكتور', 'Мехтаг доктор', 'Mehtag doktor'],
  ['health', 'Где ближайшая аптека?', 'Where is the nearest pharmacy?', 'فين أقرب صيدلية؟', 'Фейн áраб сайдалейя?', 'Fein arab saydaleyya?'],
  ['health', 'У меня болит живот', 'I have a stomach ache', 'بطني بتوجعني', 'Батни битуагаани', 'Batni betwagaani'],
  ['health', 'У меня температура', 'I have a fever', 'عندي سخونية', 'Анди сохунейя', 'Andi sokhoneyya'],
  ['health', 'У меня аллергия', 'I have an allergy', 'عندي حساسية', 'Анди хасасейя', 'Andi hasaseyya'],
  ['health', 'Нужно что-то от головной боли', 'I need something for a headache', 'عايز حاجة للصداع', 'Айез хáга лиль-судаа', 'Ayez haga lel-sodaa'],
  ['health', 'Вызовите скорую, пожалуйста', 'Please call an ambulance', 'اطلب الإسعاف من فضلك', 'Отлоб эль-эсааф, мин фадлак', 'Otlob el-esaaf, min fadlak'],
  ['home', 'Не работает кондиционер', 'The air conditioner is not working', 'التكييف مش شغال', 'Эт-такйиф миш шагаль', 'El-takyeef mesh shaghal'],
  ['home', 'Нет воды', 'There is no water', 'مفيش مية', 'Мафиш майя', 'Mafeesh mayya'],
  ['home', 'Нет света', 'The power is out', 'النور قاطع', 'Эн-нур áтэа', 'El-noor atea'],
  ['home', 'Не работает интернет', 'The internet is not working', 'النت مش شغال', 'Эн-нет миш шагаль', 'El-net mesh shaghal'],
  ['home', 'Когда придёт мастер?', 'When will the technician come?', 'الفني هييجي إمتى؟', 'Эль-фанни хайиги эмта?', 'El-fanni hayeegi emta?'],
  ['home', 'Сколько стоит аренда в месяц?', 'How much is the rent per month?', 'الإيجار كام في الشهر؟', 'Эль-игар кям фи-шшахр?', 'El-egar kam fel-shahr?'],
  ['home', 'Хочу пополнить счётчик электричества', 'I want to top up the electricity meter', 'عايز أشحن عداد الكهربا', 'Айез ашхан аддад эль-кахраба', 'Ayez ashhan addad el-kahraba'],
  ['common', 'Я не говорю по-арабски', 'I do not speak Arabic', 'أنا مش بتكلم عربي', 'Ана миш баткаллем араби', 'Ana mesh batkallem arabi'],
  ['common', 'Вы говорите по-английски?', 'Do you speak English?', 'بتتكلم إنجليزي؟', 'Бтеткаллем ингилизи?', 'Betetkallem engelizi?'],
  ['common', 'Помогите, пожалуйста', 'Please help me', 'ساعدني من فضلك', 'Саэдни, мин фадлак', 'Saedni, min fadlak'],
  ['common', 'Где туалет?', 'Where is the toilet?', 'فين الحمام؟', 'Фейн эль-хаммам?', 'Fein el-hammam?'],
  ['common', 'Я заблудился', 'I am lost', 'أنا تايه', 'Ана тайех', 'Ana tayeh'],
  ['common', 'Позвоните по этому номеру, пожалуйста', 'Please call this number', 'اتصل بالرقم ده من فضلك', 'Эттесель бир-ракам да, мин фадлак', 'Ettesel bel-raqam da, min fadlak'],
  ['common', 'Оставьте меня в покое', 'Leave me alone', 'سيبني في حالي', 'Сибни фи хáли', 'Sibni fi hali'],
];

class ShowDriverScreen extends StatefulWidget {
  const ShowDriverScreen({super.key});

  @override
  State<ShowDriverScreen> createState() => _ShowDriverScreenState();
}

class _ShowDriverScreenState extends State<ShowDriverScreen> {
  String cat = 'taxi';

  @override
  void initState() {
    super.initState();
    ttsInit();
  }

  Future<void> _editAddress() async {
    final app = AppScope.of(context);
    final c = TextEditingController(text: app.myAddress);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Мой адрес'),
        content: TextField(
          controller: c,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(hintText: tr('Название отеля или адрес, лучше на английском или арабском')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Сохранить')),
        ],
      ),
    );
    if (v != null) app.setMyAddress(v);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final list = showPhrases.where((f) => f[0] == cat).toList();
    return Scaffold(
      body: Column(children: [
        const SubHeader(title: 'Покажи таксисту'),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 24 + MediaQuery.of(context).padding.bottom),
            children: [
              Text('Нажмите на фразу — она откроется на весь экран крупно на арабском. Покажите телефон собеседнику или включите озвучку. Работает без интернета.',
                  style: TextStyle(fontSize: 13.5, color: p.muted, height: 1.4)),
              const SizedBox(height: 12),
              // Мой адрес
              Box(
                color: p.sel,
                onTap: app.myAddress.isEmpty
                    ? _editAddress
                    : () => push(
                        context,
                        BigPhraseScreen(
                            title: tr('Отвезите меня по этому адресу, пожалуйста'),
                            arabic: 'من فضلك وصّلني للعنوان ده',
                            hint: _ru ? 'Мин фадлак, вассальни лиль-энуан да' : 'Min fadlak, wassalni lil-enwan da',
                            extra: app.myAddress)),
                child: Row(children: [
                  Ico('pin', size: 22, color: p.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Мой адрес', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text)),
                      const SizedBox(height: 2),
                      app.myAddress.isEmpty
                          ? Text('Добавьте отель или дом — покажете водителю одним нажатием',
                              style: TextStyle(fontSize: 13, color: p.muted, height: 1.35))
                          : w.Text(app.myAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13.5, color: p.body, height: 1.35)),
                    ]),
                  ),
                  IconBtn(app.myAddress.isEmpty ? 'plus' : 'edit', label: 'Изменить', onTap: _editAddress),
                ]),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: showCats.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final c = showCats[i];
                    return _Pill(
                        label: _ru ? c[2] : c[3], raw: !_ru, selected: cat == c[0], onTap: () => setState(() => cat = c[0]));
                  },
                ),
              ),
              const SizedBox(height: 12),
              for (final f in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Box(
                    padding: const EdgeInsets.all(12),
                    onTap: () => push(
                        context, BigPhraseScreen(title: _ru ? f[1] : f[2], arabic: f[3], hint: _ru ? f[4] : f[5])),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          w.Text(_ru ? tr(f[1]) : f[2],
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text, height: 1.25)),
                          const SizedBox(height: 3),
                          w.Text(f[3],
                              textDirection: TextDirection.rtl,
                              style: TextStyle(fontSize: 17, color: p.accent, fontWeight: FontWeight.w600, height: 1.5)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Ico('chevron', size: 18, color: p.muted),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Фраза на весь экран: крупный арабский текст на светлом фоне (читается на солнце).
class BigPhraseScreen extends StatelessWidget {
  const BigPhraseScreen({super.key, required this.title, required this.arabic, required this.hint, this.extra});
  final String title, arabic, hint;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    const ink = Color(0xFF0B2B33);
    final long = arabic.length > 22;
    return Scaffold(
      body: Column(children: [
        const SubHeader(title: 'Покажите экран'),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
            child: Column(children: [
              Expanded(
                child: Appear(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 12))],
                    ),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          w.Text(arabic,
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: long ? 40 : 54, fontWeight: FontWeight.w700, color: ink, height: 1.5)),
                          if (extra != null && extra!.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Container(height: 1, color: const Color(0x220B2B33)),
                            const SizedBox(height: 18),
                            w.Text(extra!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: ink, height: 1.3)),
                          ],
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              w.Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.text, height: 1.3)),
              const SizedBox(height: 4),
              w.Text(hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.5, color: p.accent, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: PrimaryButton('Озвучить', icon: 'bell', onPressed: () => speakArabic(context, arabic)),
                ),
                const SizedBox(width: 10),
                Box(
                  radius: 14,
                  padding: const EdgeInsets.all(13),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: extra == null ? arabic : '$arabic\n$extra'));
                    toast(context, 'Скопировано');
                  },
                  child: Ico('copy', size: 22, color: p.text),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

// =====================================================================
// «Первые 30 дней»
// =====================================================================

class NewbieStep {
  const NewbieStep(this.id, this.group, this.ru, this.en, this.textRu, this.textEn, [this.action]);
  final String id;
  final int group;
  final String ru, en, textRu, textEn;

  /// Куда ведёт кнопка: taxi, prices, sos, apps, nearby, trusted.
  final String? action;
}

const first30Updated = 'ноябрь 2026';

const first30Groups = <List<String>>[
  ['Первый день', 'Day one'],
  ['Первая неделя', 'First week'],
  ['Первый месяц', 'First month'],
];

const first30Steps = <NewbieStep>[
  NewbieStep('visa', 0, 'Виза и дата въезда', 'Visa and entry date',
      'Виза по прилёту или электронная e-Visa стоит 30 \$ (с 1 января 2027 — 33 \$) и действует 30 дней. Бесплатный штамп «Синай» — только для курортов Южного Синая и только на 15 дней. Отметьте дату въезда в визовом таймере выше — приложение покажет, сколько дней осталось.',
      'A visa on arrival or an e-Visa costs \$30 (\$33 from 1 January 2027) and is valid for 30 days. The free Sinai stamp covers only South Sinai resorts for 15 days. Enter your arrival date in the visa timer above to see how many days you have left.'),
  NewbieStep('sim', 0, 'Купить SIM-карту', 'Get a SIM card',
      'Операторы: Vodafone, Orange, e& (Etisalat) и WE. Покупайте в официальном салоне или в аэропорту — нужен паспорт. Попросите сразу подключить интернет-пакет и проверить, что он заработал.',
      'Operators: Vodafone, Orange, e& (Etisalat) and WE. Buy at an official store or at the airport — you need your passport. Ask them to activate a data bundle and check that it works before you leave.'),
  NewbieStep('cash', 0, 'Снять или обменять деньги', 'Get cash',
      'Меняйте деньги в банке или официальном обменнике, не на улице. Наличные фунты нужны для такси, рынков и чаевых. Мелкие купюры всегда пригодятся. Сверяйте цены с разделом «Честные цены».',
      'Exchange money at a bank or an official exchange office, never on the street. You need cash for taxis, markets and tips, and small notes are always useful. Compare prices with the Fair prices section.',
      'prices'),
  NewbieStep('taxi', 0, 'Настроить такси', 'Set up taxis',
      'Установите Uber, Careem или inDrive — цена известна заранее. В обычном такси договаривайтесь о цене до поездки. Готовые фразы для водителя — в разделе «Покажи таксисту».',
      'Install Uber, Careem or inDrive — you see the price in advance. In a street taxi agree on the price before you get in. Ready phrases for drivers are in Show the driver.',
      'taxi'),
  NewbieStep('sos', 0, 'Сохранить экстренные номера', 'Save emergency numbers',
      'Полиция — 122, скорая — 123, туристическая полиция — 126. Откройте раздел SOS и добавьте контакт близкого человека.',
      'Police 122, ambulance 123, tourist police 126. Open the SOS section and add a contact of someone close to you.',
      'sos'),
  NewbieStep('rent', 1, 'Найти жильё и подписать договор', 'Find a home and sign a contract',
      'Смотрите квартиру лично, не платите заранее по фото. Просите договор на арабском и английском с суммой, сроком и депозитом (обычно один месяц). Уточните, кто платит за свет, воду, газ и интернет, и сфотографируйте счётчики при заселении. Предложения — в разделе «Недвижимость».',
      'See the flat in person and never prepay based on photos. Ask for a contract in Arabic and English with the amount, term and deposit (usually one month). Agree who pays for electricity, water, gas and internet, and photograph the meters when you move in. Listings are in the Real estate section.'),
  NewbieStep('meters', 1, 'Разобраться со светом, водой и газом', 'Sort out electricity, water and gas',
      'Во многих домах счётчики предоплатные, с картой: её пополняют в киосках Fawry, в приложениях или в офисе компании. Узнайте у хозяина, где пополнять и сколько осталось на счётчике. Газ часто в баллонах — спросите, кто их привозит.',
      'Many homes have prepaid meters with a card that you top up at Fawry kiosks, in apps or at the company office. Ask the landlord where to top up and what the current balance is. Gas often comes in cylinders — ask who delivers them.'),
  NewbieStep('net', 1, 'Подключить домашний интернет', 'Get home internet',
      'Домашний интернет дают WE, Vodafone, Orange и e&. Обычно нужны паспорт и договор аренды, подключение занимает от нескольких дней. На первое время выручит мобильный роутер или раздача с телефона.',
      'Home internet is offered by WE, Vodafone, Orange and e&. You usually need your passport and a rental contract, and installation takes from a few days. Until then use a mobile router or your phone hotspot.'),
  NewbieStep('apps', 1, 'Установить полезные приложения', 'Install useful apps',
      'Доставка еды и продуктов, такси, карты и оплата счетов — всё собрано в разделе «Полезные приложения».',
      'Food and grocery delivery, taxis, maps and bill payments — all collected in the Useful apps section.',
      'apps'),
  NewbieStep('near', 1, 'Найти аптеку, банкомат и магазин рядом', 'Find a pharmacy, ATM and shop nearby',
      'Откройте «Рядом со мной» и сохраните ближайшие аптеку, банкомат и супермаркет — в первый раз их лучше найти спокойно, а не когда срочно нужно.',
      'Open Nearby and save the closest pharmacy, ATM and supermarket — it is better to find them calmly than when you urgently need one.',
      'nearby'),
  NewbieStep('stay', 2, 'Продлить визу или оформить резиденцию', 'Extend your visa or get a residence permit',
      'Если остаётесь дольше срока визы, обратитесь в паспортно-визовую службу своего города заранее, до окончания визы. Обычно нужны паспорт, копии страниц с визой и штампом, фото и договор аренды. Правила и стоимость меняются — уточните на месте или спросите у тех, кто недавно оформлял. За просрочку берут штраф при выезде.',
      'If you stay longer than your visa allows, go to the passport and immigration office in your city before the visa ends. You usually need your passport, copies of the visa and stamp pages, photos and a rental contract. Rules and fees change, so check locally or ask people who did it recently. Overstaying means a fine when you leave.'),
  NewbieStep('phone', 2, 'Зарегистрировать телефон (правило 90 дней)', 'Register your phone (90-day rule)',
      'Телефон, привезённый из-за границы, работает с египетской SIM-картой 90 дней. Потом его нужно зарегистрировать в официальном приложении Telephony и оплатить пошлину (около 38% стоимости), иначе его отключат от египетских сетей. Сумму показывает само приложение по номеру IMEI. Не платите через посредников.',
      'A phone brought from abroad works with an Egyptian SIM for 90 days. After that you must register it in the official Telephony app and pay a duty (about 38% of its value), otherwise it is cut off from Egyptian networks. The app shows the amount by IMEI. Do not pay through middlemen.'),
  NewbieStep('bank', 2, 'Открыть счёт в банке', 'Open a bank account',
      'Счёт нужен для зарплаты, аренды и оплаты услуг. Банки обычно просят паспорт с действующей визой или резиденцией и договор аренды. Условия в банках разные — сравните два-три отделения.',
      'You need an account for salary, rent and bills. Banks usually ask for a passport with a valid visa or residence permit and a rental contract. Terms differ between banks, so compare two or three branches.'),
  NewbieStep('doctor', 2, 'Найти врача и подумать о страховке', 'Find a doctor and consider insurance',
      'Выберите частную клинику и аптеку рядом с домом заранее. Сохраните адрес ближайшей больницы. Проверенных специалистов ищите в разделе «Проверенные».',
      'Choose a private clinic and a pharmacy near your home in advance, and save the address of the nearest hospital. Look for verified specialists in the Verified section.',
      'trusted'),
  NewbieStep('own', 2, 'Стать своим', 'Become a local',
      'Разместите первое объявление, найдите мастера или работу, подпишитесь на новости своего города. Чем больше нас в приложении — тем проще жить в Египте каждому.',
      'Post your first ad, find a handyman or a job, and follow the news of your city. The more of us are in the app, the easier life in Egypt gets for everyone.'),
];

class First30Screen extends StatefulWidget {
  const First30Screen({super.key});

  @override
  State<First30Screen> createState() => _First30ScreenState();
}

class _First30ScreenState extends State<First30Screen> {
  String? open;

  void _go(String a) {
    final Widget page;
    switch (a) {
      case 'taxi':
        page = const ShowDriverScreen();
        break;
      case 'prices':
        page = const FairPricesScreen();
        break;
      case 'sos':
        page = const SosScreen();
        break;
      case 'apps':
        page = const AppsScreen();
        break;
      case 'nearby':
        page = const NearbyScreen();
        break;
      default:
        page = const TrustedScreen();
    }
    push(context, page);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final total = first30Steps.length;
    final done = first30Steps.where((s) => app.stepsDone.contains(s.id)).length;

    Widget step(NewbieStep s) {
      final ok = app.stepsDone.contains(s.id);
      final opened = open == s.id;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Box(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            InkWell(
              onTap: () => setState(() => open = opened ? null : s.id),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 12, 6),
                child: Row(children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      app.toggleStep(s.id);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ok ? p.ok : Colors.transparent,
                          border: Border.all(color: ok ? p.ok : p.muted, width: 1.8),
                        ),
                        child: ok ? const Center(child: Ico('check', size: 15, color: Colors.white, stroke: 3)) : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: w.Text(_ru ? tr(s.ru) : s.en,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                            color: ok ? p.muted : p.text,
                            decoration: ok ? TextDecoration.lineThrough : null)),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: opened ? .25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Ico('chevron', size: 18, color: p.muted),
                  ),
                ]),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !opened
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(48, 0, 14, 14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        w.Text(_ru ? tr(s.textRu) : s.textEn, style: TextStyle(fontSize: 14, color: p.body, height: 1.45)),
                        if (s.action != null) ...[
                          const SizedBox(height: 10),
                          _Pill(label: 'Открыть раздел', selected: true, onTap: () => _go(s.action!)),
                        ],
                      ]),
                    ),
            ),
          ]),
        ),
      );
    }

    return Scaffold(
      body: Column(children: [
        const SubHeader(title: 'Первые 30 дней'),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 28 + MediaQuery.of(context).padding.bottom),
            children: [
              // Прогресс
              Appear(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF06B6D4), Color(0xFF2563EB)]),
                  ),
                  child: Row(children: [
                    SizedBox(
                      width: 62,
                      height: 62,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: total == 0 ? 0 : done / total),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => Stack(fit: StackFit.expand, children: [
                          CircularProgressIndicator(
                              value: v, strokeWidth: 6, backgroundColor: const Color(0x40FFFFFF), color: Colors.white),
                          Center(
                            child: w.Text('${(v * 100).round()}%',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        w.Text(tr('Сделано {a} из {b}', {'a': done, 'b': total}), style: heading(19, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(
                            done == total
                                ? 'Вы уже свой в Египте!'
                                : 'Шаг за шагом — и Египет станет домом',
                            style: const TextStyle(fontSize: 13.5, color: Color(0xE6FFFFFF), height: 1.35)),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              const Appear(delay: 90, child: VisaCard()),
              for (var g = 0; g < first30Groups.length; g++) ...[
                SectionTitle(_ru ? first30Groups[g][0] : first30Groups[g][1]),
                const SizedBox(height: 6),
                for (final s in first30Steps.where((x) => x.group == g)) step(s),
              ],
              const SizedBox(height: 8),
              w.Text(
                  '${tr('Правила и цены меняются — перед оформлением документов уточняйте актуальные условия.')} ${tr('Обновлено: {d}', {'d': tr(first30Updated)})}',
                  style: TextStyle(fontSize: 12.5, color: p.muted, height: 1.4)),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Визовый таймер: дата въезда + срок визы = сколько дней осталось.
class VisaCard extends StatelessWidget {
  const VisaCard({super.key});

  static const _terms = [15, 30, 90, 180];

  Future<void> _pick(BuildContext context) async {
    final app = AppScope.of(context);
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: app.visaFrom ?? now,
      firstDate: now.subtract(const Duration(days: 400)),
      lastDate: now,
      helpText: tr('Дата въезда в Египет'),
    );
    if (d != null) app.setVisa(d, app.visaDays);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final left = app.visaLeft;
    final from = app.visaFrom;

    if (left == null || from == null) {
      return Box(
        onTap: () => _pick(context),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: p.sel, borderRadius: BorderRadius.circular(13)),
            child: Center(child: Ico('calendar', size: 21, color: p.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Визовый таймер', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: p.text)),
              const SizedBox(height: 2),
              Text('Укажите дату въезда — покажем, сколько дней осталось по визе',
                  style: TextStyle(fontSize: 13, color: p.muted, height: 1.35)),
            ]),
          ),
          Ico('chevron', size: 18, color: p.muted),
        ]),
      );
    }

    final c = visaColor(p, left);
    return Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            constraints: const BoxConstraints(minWidth: 58),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: c.withAlpha(38), borderRadius: BorderRadius.circular(15)),
            child: w.Text('${left < 0 ? 0 : left}',
                textAlign: TextAlign.center, style: heading(26, color: c, height: 1.1)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              w.Text(visaLine(left), style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: p.text)),
              const SizedBox(height: 2),
              w.Text(
                  tr('Въезд {a} · виза до {b}', {
                    'a': '${dayMonth(from)} ${from.year}',
                    'b': '${dayMonth(app.visaUntil!)} ${app.visaUntil!.year}',
                  }),
                  style: TextStyle(fontSize: 13, color: p.muted, height: 1.35)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Text('Срок визы, дней', style: TextStyle(fontSize: 12.5, color: p.muted)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in _terms)
            _Pill(label: '$t', raw: true, selected: app.visaDays == t, onTap: () => app.setVisa(from, t)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          TextButton(onPressed: () => _pick(context), child: const Text('Изменить дату')),
          TextButton(onPressed: () => app.setVisa(null, app.visaDays), child: const Text('Сбросить')),
        ]),
        Text('Считаем от даты въезда. Точный срок смотрите на штампе в паспорте.',
            style: TextStyle(fontSize: 12, color: p.muted, height: 1.35)),
      ]),
    );
  }
}
