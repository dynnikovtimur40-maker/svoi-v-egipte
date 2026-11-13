// Этап 6: язык, проверка профиля, продвижение, редактор фото, путеводитель.
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart' hide Text;
import 'package:image/image.dart' as img;

import 'config.dart';
import 'data.dart';
import 'guide.dart';
import 'i18n.dart';
import 'main.dart';

// =====================================================================
// Язык
// =====================================================================

String langName(String code) =>
    appLanguages.firstWhere((l) => l[0] == code, orElse: () => appLanguages.first)[1];

Future<void> showLanguageSheet(BuildContext context) async {
  final app = AppScope.of(context);
  final code = await showGlassSheet<String>(
    context,
    (ctx) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
            child: Text('Язык приложения', style: heading(18, weight: FontWeight.w800, color: Pal.of(ctx).text)),
          ),
          for (final l in appLanguages)
            OptionRow(label: l[1], selected: app.lang == l[0], onTap: () => Navigator.pop(ctx, l[0])),
        ]),
      ),
    ),
  );
  if (code != null && code != app.lang) await app.setLang(code);
}

// =====================================================================
// Значок VIP
// =====================================================================

class VipBadge extends StatelessWidget {
  const VipBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('VIP', style: TextStyle(color: Color(0xFF3B2600), fontSize: 11, fontWeight: FontWeight.w800)),
      );
}

// =====================================================================
// Продвижение объявления
// =====================================================================

const _promoInfo = {
  'bump': ['chevron', 'Объявление снова появится в начале ленты.'],
  'highlight': ['palette', 'Цветная рамка в ленте 7 дней — объявление заметнее.'],
  'vip': ['star', 'Закреплено в самом верху ленты 7 дней, золотая рамка и значок VIP.'],
};

Future<void> showPromoteSheet(BuildContext context, Post post) async {
  final app = AppScope.of(context);
  if (app.products.isEmpty) await app.loadProducts();
  if (!context.mounted) return;
  if (app.products.isEmpty) {
    toast(context, 'Продвижение будет доступно после обновления базы (v4).');
    return;
  }
  await showGlassSheet<void>(context, (ctx) => _PromoteSheet(post: post));
  await app.loadMyPosts();
}

class _PromoteSheet extends StatefulWidget {
  const _PromoteSheet({required this.post});
  final Post post;

  @override
  State<_PromoteSheet> createState() => _PromoteSheetState();
}

class _PromoteSheetState extends State<_PromoteSheet> {
  String? busy;

  Future<void> pay(Product x) async {
    final app = AppScope.of(context);
    setState(() => busy = x.code);
    try {
      final url = await app.paymentLink(widget.post.id, x.code);
      if (!mounted) return;
      Navigator.pop(context);
      await openUrl(context, url, url);
      if (context.mounted) toast(context, 'После оплаты услуга включится автоматически. Обновите список.');
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = null);
      toast(context, e.toString().contains('not_configured')
          ? 'Онлайн-оплата скоро будет подключена.'
          : 'Не удалось открыть оплату. Попробуйте ещё раз.');
    }
  }

  Future<void> free(Product x) async {
    final app = AppScope.of(context);
    setState(() => busy = x.code);
    try {
      await app.adminPromote(widget.post.id, x.code);
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, 'Готово');
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = null);
      toast(context, AppState.serverMessage(e, 'Не удалось. Попробуйте ещё раз.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetHandle(),
          Text('Продвинуть объявление', style: heading(19, weight: FontWeight.w800, color: p.text)),
          const SizedBox(height: 4),
          Text(widget.post.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: p.muted)),
          const SizedBox(height: 14),
          for (final x in app.products) ...[
            Box(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: x.code == 'vip' ? const Color(0x33F59E0B) : p.sel,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Ico(_promoInfo[x.code]?[0] ?? 'star',
                        size: 20, color: x.code == 'vip' ? const Color(0xFFF59E0B) : p.accent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(x.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text)),
                    const SizedBox(height: 2),
                    Text(_promoInfo[x.code]?[1] ?? '', style: TextStyle(fontSize: 12.5, color: p.muted, height: 1.35)),
                    if (app.isAdmin)
                      GestureDetector(
                        onTap: busy == null ? () => free(x) : null,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Выдать бесплатно (админ)',
                              style: TextStyle(fontSize: 12.5, color: p.accent, fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 104,
                  child: PrimaryButton('${fmt(x.price)} EGP',
                      height: 40, busy: busy == x.code, onPressed: busy == null ? () => pay(x) : null),
                ),
              ]),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          Text('Оплата картой или кошельком через Paymob. Деньги не возвращаются после включения услуги.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: p.muted, height: 1.4)),
        ]),
      ),
    );
  }
}

// =====================================================================
// Проверка профиля через Telegram
// =====================================================================

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  bool busy = false;
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    refresh();
  }

  Future<void> refresh() async {
    final app = AppScope.of(context);
    await Future.wait([app.loadProfile(), app.loadMyVerification()]);
  }

  Future<void> openBot() async {
    final app = AppScope.of(context);
    setState(() => busy = true);
    try {
      final url = await app.verificationLink();
      if (!mounted) return;
      await openUrl(context, url, url);
    } catch (e) {
      if (mounted) {
        toast(context, AppState.serverMessage(e, 'Бот проверки ещё не подключён. Попробуйте позже.'));
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final verified = app.profile?.verified == true;
    final v = app.myVerification;

    Widget step(String n, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: p.sel, shape: BoxShape.circle),
              child: Center(child: Text(n, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: p.accent))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(fontSize: 14.5, color: p.text2, height: 1.4))),
          ]),
        );

    Widget status(Color bg, Color fg, String icon, String text) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Ico(icon, size: 22, color: fg),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: fg, height: 1.4, fontWeight: FontWeight.w600))),
          ]),
        );

    final children = <Widget>[
      Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(gradient: p.primaryGradient, shape: BoxShape.circle),
          child: Center(child: Ico('shield', size: 36, color: p.onPrimary)),
        ),
      ),
      const SizedBox(height: 14),
      Text('Отметка «Проверен»', textAlign: TextAlign.center, style: heading(20, weight: FontWeight.w800, color: p.text)),
      const SizedBox(height: 6),
      Text('Покупатели и клиенты больше доверяют проверенным людям: отметка видна в объявлениях и профиле.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: p.muted, height: 1.45)),
      const SizedBox(height: 20),
    ];

    if (app.user == null) {
      children.add(status(p.warnbg, p.warn, 'lock', 'Войдите, чтобы пройти проверку.'));
    } else if (verified) {
      children.add(status(p.okbg, p.ok, 'check', 'Ваш профиль проверен. Спасибо!'));
    } else {
      if (v?.status == 'sent') {
        children..add(status(p.infobg, p.info, 'shield', 'Документы у модератора. Обычно проверка занимает до суток.'))
          ..add(const SizedBox(height: 16));
      } else if (v?.status == 'rejected') {
        children..add(status(p.warnbg, p.bad, 'alert',
              tr('Проверка не пройдена: {r}. Попробуйте ещё раз.', {'r': tr(v?.reason ?? 'Документ не подтверждён')})))
          ..add(const SizedBox(height: 16));
      }
      children.addAll([
        step('1', 'Нажмите кнопку ниже — откроется наш Telegram-бот.'),
        step('2', 'Пришлите боту фото документа (паспорт или ID) и селфи с ним.'),
        step('3', 'Модератор проверит и поставит отметку «Проверен». Ответ придёт в бот и на почту.'),
        const SizedBox(height: 8),
        PrimaryButton(v?.status == 'sent' ? 'Открыть бота ещё раз' : 'Пройти проверку в Telegram',
            icon: 'send', busy: busy, onPressed: openBot),
        const SizedBox(height: 10),
        OutlineBtn('Обновить статус', icon: 'check', onPressed: refresh),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.infobg, borderRadius: BorderRadius.circular(14)),
          child: Text(
              'Документы видит только модератор в Telegram. В приложении и на нашем сервере они не хранятся и никому не передаются.',
              style: TextStyle(fontSize: 12.5, color: p.info, height: 1.45)),
        ),
      ]);
    }

    return Scaffold(
      body: Column(children: [
        const SubHeader(title: 'Проверка профиля'),
        Expanded(
          child: RefreshIndicator(
            color: p.accent,
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + MediaQuery.of(context).padding.bottom),
              children: children,
            ),
          ),
        ),
      ]),
    );
  }
}

/// Админ: заявки на проверку.
class VerificationsPanel extends StatefulWidget {
  const VerificationsPanel({super.key});

  @override
  State<VerificationsPanel> createState() => _VerificationsPanelState();
}

class _VerificationsPanelState extends State<VerificationsPanel> {
  Future<List<Verification>>? future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= AppScope.of(context).fetchVerifications();
  }

  Future<void> decide(Verification v, bool ok) async {
    final app = AppScope.of(context);
    try {
      await app.adminVerify(v.userId, ok);
      if (!mounted) return;
      toast(context, ok ? 'Пользователь проверен' : 'Отклонено');
      setState(() => future = app.fetchVerifications());
    } catch (e) {
      if (mounted) toast(context, AppState.serverMessage(e, 'Не удалось. Попробуйте ещё раз.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    const names = {'new': 'Ждём документы', 'sent': 'Документы получены', 'approved': 'Проверен', 'rejected': 'Отклонено'};
    return FutureBuilder<List<Verification>>(
      future: future,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return const EmptyState(icon: 'alert', text: 'Не удалось загрузить. Проверьте, что база обновлена (v4).');
        }
        final list = snap.data ?? [];
        if (list.isEmpty) return const EmptyState(icon: 'shield', text: 'Заявок на проверку пока нет.');
        return Column(children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: p.infobg, borderRadius: BorderRadius.circular(14)),
            child: Text('Фото документов приходят вам в Telegram-бот. Подтверждать можно там кнопками или здесь.',
                style: TextStyle(fontSize: 12.5, color: p.info, height: 1.4)),
          ),
          for (final v in list) ...[
            Box(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Avatar(name: v.userName, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(v.userName.isEmpty ? 'Пользователь' : v.userName,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text)),
                      Text(
                          '${tr(v.userCity)} · ${dateText(v.date)}${v.tgUsername != null ? ' · @${v.tgUsername}' : ''} · ${tr('фото: {n}', {'n': v.photos})}',
                          style: TextStyle(fontSize: 12.5, color: p.muted)),
                    ]),
                  ),
                  Pill(names[v.status] ?? v.status,
                      bg: v.status == 'approved' ? p.okbg : v.status == 'rejected' ? p.warnbg : p.infobg,
                      fg: v.status == 'approved' ? p.ok : v.status == 'rejected' ? p.bad : p.info),
                ]),
                if (v.status == 'new' || v.status == 'sent') ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: PrimaryButton('Подтвердить', height: 40, icon: 'check', onPressed: () => decide(v, true))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlineBtn('Отклонить', height: 40, color: p.bad, onPressed: () => decide(v, false))),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 10),
          ],
        ]);
      },
    );
  }
}

// =====================================================================
// Редактор фото: обрезка и поворот
// =====================================================================

Uint8List _rotateJob(Uint8List b) {
  final s = img.decodeImage(b);
  if (s == null) return b;
  return Uint8List.fromList(img.encodeJpg(img.copyRotate(s, angle: 90), quality: 90));
}

Uint8List _cropJob(List<Object> a) {
  final s = img.decodeImage(a[0] as Uint8List);
  if (s == null) return a[0] as Uint8List;
  final r = a[1] as List<double>; // left, top, width, height (0..1)
  final x = (r[0] * s.width).round().clamp(0, s.width - 1);
  final y = (r[1] * s.height).round().clamp(0, s.height - 1);
  final w = (r[2] * s.width).round().clamp(1, s.width - x);
  final h = (r[3] * s.height).round().clamp(1, s.height - y);
  var out = img.copyCrop(s, x: x, y: y, width: w, height: h);
  if (out.width > 1600) out = img.copyResize(out, width: 1600);
  return Uint8List.fromList(img.encodeJpg(out, quality: 85));
}

class PhotoEditor extends StatefulWidget {
  const PhotoEditor({super.key, required this.bytes});
  final Uint8List bytes;

  @override
  State<PhotoEditor> createState() => _PhotoEditorState();
}

class _PhotoEditorState extends State<PhotoEditor> {
  late Uint8List bytes = widget.bytes;
  int imgW = 1, imgH = 1;
  Rect crop = const Rect.fromLTWH(0, 0, 1, 1); // доли от размеров фото
  double? aspect; // null — свободно
  bool busy = true;
  int? corner; // 0 — лв, 1 — пв, 2 — лн, 3 — пн; null — перемещение
  bool rotated = false;

  static const aspects = <List<Object?>>[
    ['Свободно', null],
    ['1:1', 1.0],
    ['4:3', 4 / 3],
    ['3:4', 3 / 4],
    ['16:9', 16 / 9],
  ];

  @override
  void initState() {
    super.initState();
    measure();
  }

  Future<void> measure() async {
    final im = await decodeImageFromList(bytes);
    if (!mounted) return;
    setState(() {
      imgW = im.width;
      imgH = im.height;
      busy = false;
    });
  }

  Future<void> rotate() async {
    setState(() => busy = true);
    final out = await compute(_rotateJob, bytes);
    if (!mounted) return;
    bytes = out;
    rotated = true;
    crop = const Rect.fromLTWH(0, 0, 1, 1);
    await measure();
    if (aspect != null) setAspect(aspect);
  }

  void setAspect(double? a) {
    setState(() {
      aspect = a;
      if (a == null) return;
      // наибольшая рамка нужной формы по центру
      var w = 1.0;
      var h = w * imgW / (imgH * a);
      if (h > 1) {
        h = 1;
        w = h * imgH * a / imgW;
      }
      crop = Rect.fromLTWH((1 - w) / 2, (1 - h) / 2, w, h);
    });
  }

  Future<void> done() async {
    final full = crop.left < .002 && crop.top < .002 && crop.width > .996 && crop.height > .996;
    if (full) {
      Navigator.pop(context, rotated ? bytes : null);
      return;
    }
    setState(() => busy = true);
    final out = await compute(_cropJob, <Object>[bytes, <double>[crop.left, crop.top, crop.width, crop.height]]);
    if (mounted) Navigator.pop(context, out);
  }

  void onStart(Offset pos, Size box) {
    final r = Rect.fromLTWH(crop.left * box.width, crop.top * box.height, crop.width * box.width, crop.height * box.height);
    final pts = [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight];
    corner = null;
    for (var i = 0; i < 4; i++) {
      if ((pts[i] - pos).distance < 32) corner = i;
    }
  }

  void onMove(Offset d, Size box) {
    final dx = d.dx / box.width, dy = d.dy / box.height;
    const minS = .08;
    var l = crop.left, t = crop.top, r = crop.right, b = crop.bottom;
    if (corner == null) {
      final w = crop.width, h = crop.height;
      l = (l + dx).clamp(0.0, 1 - w);
      t = (t + dy).clamp(0.0, 1 - h);
      setState(() => crop = Rect.fromLTWH(l, t, w, h));
      return;
    }
    if (corner == 0 || corner == 2) l = (l + dx).clamp(0.0, r - minS);
    if (corner == 1 || corner == 3) r = (r + dx).clamp(l + minS, 1.0);
    if (corner == 0 || corner == 1) t = (t + dy).clamp(0.0, b - minS);
    if (corner == 2 || corner == 3) b = (b + dy).clamp(t + minS, 1.0);
    if (aspect != null) {
      // высота подстраивается под ширину
      final w = r - l;
      var h = w * imgW / (imgH * aspect!);
      if (corner == 0 || corner == 1) {
        t = (b - h).clamp(0.0, 1.0);
        h = b - t;
      } else {
        b = (t + h).clamp(0.0, 1.0);
        h = b - t;
      }
      final w2 = h * imgH * aspect! / imgW;
      if (corner == 0 || corner == 2) {
        l = r - w2;
      } else {
        r = l + w2;
      }
    }
    setState(() => crop = Rect.fromLTRB(l, t, r, b));
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(children: [
        SubHeader(
          title: 'Редактор фото',
          leading: 'close',
          trailing: TextButton(
            onPressed: busy ? null : done,
            child: Text('Готово', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.accent)),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: AspectRatio(
                aspectRatio: imgW / imgH,
                child: LayoutBuilder(builder: (_, c) {
                  final box = Size(c.maxWidth, c.maxHeight);
                  return GestureDetector(
                    onPanStart: (d) => onStart(d.localPosition, box),
                    onPanUpdate: (d) => onMove(d.delta, box),
                    child: Stack(fit: StackFit.expand, children: [
                      Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true),
                      CustomPaint(painter: _CropPainter(crop, p.accent)),
                      if (busy) const ColoredBox(color: Color(0x66000000), child: Center(child: CircularProgressIndicator())),
                    ]),
                  );
                }),
              ),
            ),
          ),
        ),
        Container(
          color: p.bg,
          padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + MediaQuery.of(context).padding.bottom),
          child: Column(children: [
            SizedBox(
              height: 38,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final a in aspects)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(a[0] as String),
                      selected: aspect == a[1],
                      onSelected: busy ? null : (_) => setAspect(a[1] as double?),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlineBtn('Повернуть', icon: 'edit', onPressed: busy ? null : rotate)),
              const SizedBox(width: 8),
              Expanded(
                child: OutlineBtn('Сбросить',
                    icon: 'close',
                    onPressed: busy
                        ? null
                        : () => setState(() {
                              bytes = widget.bytes;
                              rotated = false;
                              aspect = null;
                              crop = const Rect.fromLTWH(0, 0, 1, 1);
                              busy = true;
                              measure();
                            })),
              ),
            ]),
            const SizedBox(height: 6),
            Text('Тяните углы рамки, чтобы обрезать, или саму рамку, чтобы сдвинуть.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: p.muted)),
          ]),
        ),
      ]),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.crop, this.color);
  final Rect crop;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(crop.left * size.width, crop.top * size.height, crop.width * size.width, crop.height * size.height);
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(r);
    canvas.drawPath(outside, Paint()..color = const Color(0x99000000));
    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(r, line);
    // сетка в третях
    final thin = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = .8;
    for (var i = 1; i < 3; i++) {
      final x = r.left + r.width * i / 3, y = r.top + r.height * i / 3;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), thin);
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), thin);
    }
    final h = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const k = 18.0;
    for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      final sx = c.dx == r.left ? 1.0 : -1.0, sy = c.dy == r.top ? 1.0 : -1.0;
      canvas.drawLine(c, c + Offset(k * sx, 0), h);
      canvas.drawLine(c, c + Offset(0, k * sy), h);
    }
  }

  @override
  bool shouldRepaint(_CropPainter o) => o.crop != crop || o.color != color;
}

// =====================================================================
// Путеводитель
// =====================================================================

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      body: Column(children: [
        const SubHeader(title: 'Путеводитель'),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
            children: [
              Text('Египет для туриста', style: heading(22, weight: FontWeight.w800, color: p.text)),
              const SizedBox(height: 4),
              Text('Города, что посмотреть, советы и важные номера.', style: TextStyle(fontSize: 14, color: p.muted)),
              const SizedBox(height: 14),
              Box(
                onTap: () => push(context, const GuideBasicsScreen()),
                child: Row(children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(gradient: p.primaryGradient, borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Ico('help', size: 24, color: p.onPrimary)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Советы туристу', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.text)),
                      Text('Виза, деньги, такси, чаевые, экстренные номера',
                          style: TextStyle(fontSize: 12.5, color: p.muted)),
                    ]),
                  ),
                  Ico('chevron', size: 16, color: p.muted),
                ]),
              ),
              const SizedBox(height: 18),
              const SectionTitle('Города'),
              const SizedBox(height: 8),
              for (final c in guideCities) ...[
                Box(
                  onTap: () => push(context, GuideCityScreen(city: c)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: Color(c.hue).withAlpha(40), borderRadius: BorderRadius.circular(14)),
                      child: Center(child: Ico(c.icon, size: 22, color: Color(c.hue))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.text)),
                        const SizedBox(height: 2),
                        Text(c.local.intro,
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: p.muted, height: 1.35)),
                      ]),
                    ),
                    const SizedBox(width: 6),
                    Padding(padding: const EdgeInsets.only(top: 14), child: Ico('chevron', size: 16, color: p.muted)),
                  ]),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

class GuideBasicsScreen extends StatelessWidget {
  const GuideBasicsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      body: Column(children: [
        const SubHeader(title: 'Советы туристу'),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
            children: [
              for (final b in guideBasics) ...[
                Box(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b[0], style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.text)),
                    const SizedBox(height: 6),
                    Text(b[1], style: TextStyle(fontSize: 14, color: p.text2, height: 1.45)),
                  ]),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

class GuideCityScreen extends StatelessWidget {
  const GuideCityScreen({super.key, required this.city});
  final GuideCity city;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final app = AppScope.of(context);
    final g = city.local;
    final hue = Color(city.hue);

    Widget block(String title, String icon, List<String> items) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Box(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Ico(icon, size: 20, color: hue),
                const SizedBox(width: 10),
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.text)),
              ]),
              const SizedBox(height: 10),
              for (final s in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Container(width: 6, height: 6, decoration: BoxDecoration(color: hue, shape: BoxShape.circle)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(s, style: TextStyle(fontSize: 14, color: p.text2, height: 1.45))),
                  ]),
                ),
            ]),
          ),
        );

    return Scaffold(
      body: Column(children: [
        SubHeader(title: city.name),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [hue.withAlpha(70), hue.withAlpha(20)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  Ico(city.icon, size: 40, color: hue, stroke: 1.6),
                  const SizedBox(width: 14),
                  Expanded(child: Text(g.intro, style: TextStyle(fontSize: 14.5, color: p.text, height: 1.45))),
                ]),
              ),
              const SizedBox(height: 14),
              block('Что посмотреть', 'eye', g.sights),
              block('Советы', 'help', g.tips),
              block('Как добраться', 'car', [g.road]),
              PrimaryButton(tr('Объявления и услуги: {c}', {'c': tr(city.name)}), icon: 'tag', onPressed: () {
                app.setCity(city.name);
                Navigator.of(context).popUntil((r) => r.isFirst);
                toast(context, tr('Город в ленте: {c}', {'c': tr(city.name)}));
              }),
            ],
          ),
        ),
      ]),
    );
  }
}
