// Этап 6: язык, проверка профиля, продвижение, редактор фото, путеводитель.
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
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
// Проверка профиля: код из Telegram-бота
// =====================================================================

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  bool busy = false;
  bool checking = false;
  bool started = false;
  bool opened = false;
  final code = TextEditingController();
  String? err;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    refresh();
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
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
      if (mounted) setState(() => opened = true);
    } catch (e) {
      if (mounted) toast(context, AppState.serverMessage(e, 'Бот проверки ещё не подключён. Попробуйте позже.'));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> confirm() async {
    final c = code.text.replaceAll(RegExp(r'\D'), '');
    if (c.length != 6) {
      setState(() => err = tr('Введите 6 цифр из сообщения бота.'));
      return;
    }
    setState(() {
      checking = true;
      err = null;
    });
    try {
      final r = await AppScope.of(context).confirmVerification(c);
      if (!mounted) return;
      const msgs = {
        'wrong': 'Неверный код. Проверьте цифры и попробуйте ещё раз.',
        'expired': 'Код устарел. Нажмите «Получить код» ещё раз.',
        'locked': 'Слишком много попыток. Получите новый код в боте.',
        'none': 'Сначала нажмите «Получить код в Telegram».',
        'taken': 'Этот Telegram уже привязан к другому профилю.',
      };
      if (r == 'ok') {
        code.clear();
        toast(context, 'Готово! Профиль проверен.');
      } else {
        setState(() => err = tr(msgs[r] ?? 'Не удалось. Попробуйте ещё раз.'));
      }
    } catch (_) {
      if (mounted) setState(() => err = tr('Нет связи с сервером, попробуйте ещё раз'));
    }
    if (mounted) setState(() => checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final verified = app.profile?.verified == true;
    final sent = app.myVerification?.status == 'sent' || opened;

    Widget step(String n, String text, {bool done = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: done ? p.okbg : p.sel, shape: BoxShape.circle),
              child: Center(
                  child: done
                      ? Ico('check', size: 14, color: p.ok, stroke: 2.6)
                      : Text(n, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: p.accent))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(fontSize: 14.5, color: p.text2, height: 1.4))),
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
      Text('Подтвердите свой Telegram — займёт полминуты. Покупатели больше доверяют проверенным людям, а ваш Telegram станет кнопкой связи в профиле.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: p.muted, height: 1.45)),
      const SizedBox(height: 20),
    ];

    if (app.user == null) {
      children.add(Text('Войдите, чтобы пройти проверку.', textAlign: TextAlign.center, style: TextStyle(color: p.warn)));
    } else if (verified) {
      children.addAll([
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: p.okbg, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Ico('check', size: 22, color: p.ok),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                  (app.profile?.tgUsername ?? '').isNotEmpty
                      ? tr('Профиль проверен. Telegram: @{u}', {'u': app.profile!.tgUsername})
                      : tr('Ваш профиль проверен. Спасибо!'),
                  style: TextStyle(fontSize: 14, color: p.ok, height: 1.4, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ]);
    } else {
      children.addAll([
        step('1', 'Нажмите «Получить код в Telegram» — откроется наш бот @svoi_egypt_bot. Нажмите в нём «Старт».', done: sent),
        step('2', 'Бот пришлёт 6-значный код.'),
        step('3', 'Вернитесь сюда и введите код.'),
        const SizedBox(height: 8),
        PrimaryButton(sent ? 'Получить новый код' : 'Получить код в Telegram', icon: 'send', busy: busy, onPressed: openBot),
        const SizedBox(height: 16),
        Field(
          label: 'Код из бота',
          controller: code,
          hint: '123456',
          keyboard: TextInputType.number,
          autocorrect: false,
        ),
        if (err != null) ...[
          const SizedBox(height: 8),
          Text(err!, style: TextStyle(fontSize: 13, color: p.bad)),
        ],
        const SizedBox(height: 12),
        OutlineBtn('Подтвердить код', icon: 'check', onPressed: checking ? null : confirm),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.infobg, borderRadius: BorderRadius.circular(14)),
          child: Text('Один Telegram можно привязать только к одному профилю. Код действует 10 минут, даётся 5 попыток.',
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

/// Админ: проверенные пользователи и заявки.
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
    if (!ok) {
      final yes = await confirmDialog(context, 'Снять отметку «Проверен»?', 'Пользователь сможет пройти проверку заново.', 'Снять');
      if (!yes || !mounted) return;
    }
    try {
      await app.adminVerify(v.userId, ok);
      if (!mounted) return;
      toast(context, ok ? 'Пользователь проверен' : 'Отметка снята');
      setState(() => future = app.fetchVerifications());
    } catch (e) {
      if (mounted) toast(context, AppState.serverMessage(e, 'Не удалось. Попробуйте ещё раз.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    const names = {'new': 'Открыл ссылку', 'sent': 'Код отправлен', 'approved': 'Проверен', 'rejected': 'Отметка снята'};
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
            child: Text('Проверка проходит автоматически по коду из Telegram-бота. Здесь можно снять отметку или поставить её вручную.',
                style: TextStyle(fontSize: 12.5, color: p.info, height: 1.4)),
          ),
          for (final v in list) ...[
            Box(
              padding: const EdgeInsets.all(12),
              onTap: () => push(context, SellerScreen(userId: v.userId, name: v.userName)),
              child: Row(children: [
                Avatar(name: v.userName, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(v.userName.isEmpty ? 'Пользователь' : v.userName,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text)),
                    Text('${tr(v.userCity)} · ${dateText(v.date)}${v.tgUsername != null ? ' · @${v.tgUsername}' : ''}',
                        style: TextStyle(fontSize: 12.5, color: p.muted)),
                  ]),
                ),
                const SizedBox(width: 6),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Pill(names[v.status] ?? v.status,
                      bg: v.status == 'approved' ? p.okbg : v.status == 'rejected' ? p.warnbg : p.infobg,
                      fg: v.status == 'approved' ? p.ok : v.status == 'rejected' ? p.bad : p.info),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => decide(v, v.status != 'approved'),
                    child: Text(v.status == 'approved' ? 'Снять' : 'Подтвердить',
                        style: TextStyle(fontSize: 12.5, color: v.status == 'approved' ? p.bad : p.accent, fontWeight: FontWeight.w700)),
                  ),
                ]),
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
  final maxSide = a[2] as int;
  final x = (r[0] * s.width).round().clamp(0, s.width - 1);
  final y = (r[1] * s.height).round().clamp(0, s.height - 1);
  final w = (r[2] * s.width).round().clamp(1, s.width - x);
  final h = (r[3] * s.height).round().clamp(1, s.height - y);
  var out = img.copyCrop(s, x: x, y: y, width: w, height: h);
  if (out.width >= out.height && out.width > maxSide) out = img.copyResize(out, width: maxSide);
  if (out.height > out.width && out.height > maxSide) out = img.copyResize(out, height: maxSide);
  return Uint8List.fromList(img.encodeJpg(out, quality: 85));
}

class PhotoEditor extends StatefulWidget {
  const PhotoEditor({super.key, required this.bytes, this.fixedAspect, this.circle = false, this.maxSide = 1600});
  final Uint8List bytes;
  final double? fixedAspect; // например 1 — квадрат для аватара
  final bool circle; // показать круглую рамку (аватар)
  final int maxSide;

  @override
  State<PhotoEditor> createState() => _PhotoEditorState();
}

class _PhotoEditorState extends State<PhotoEditor> {
  late Uint8List bytes = widget.bytes;
  int imgW = 1, imgH = 1;
  Rect crop = const Rect.fromLTWH(0, 0, 1, 1); // доли от размеров фото
  late double? aspect = widget.fixedAspect; // null — свободно
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
    if (aspect != null) setAspect(aspect);
  }

  Future<void> rotate() async {
    setState(() => busy = true);
    final out = await compute(_rotateJob, bytes);
    if (!mounted) return;
    bytes = out;
    rotated = true;
    crop = const Rect.fromLTWH(0, 0, 1, 1);
    await measure();
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
    if (full && widget.fixedAspect == null) {
      Navigator.pop(context, rotated ? bytes : null);
      return;
    }
    setState(() => busy = true);
    final out = await compute(_cropJob, <Object>[bytes, <double>[crop.left, crop.top, crop.width, crop.height], widget.maxSide]);
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
                      CustomPaint(painter: _CropPainter(crop, p.accent, widget.circle)),
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
            if (widget.fixedAspect == null)
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
                              aspect = widget.fixedAspect;
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
  _CropPainter(this.crop, this.color, this.circle);
  final Rect crop;
  final Color color;
  final bool circle;

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
    if (circle) {
      canvas.drawOval(r, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
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
  bool shouldRepaint(_CropPainter o) => o.crop != crop || o.color != color || o.circle != circle;
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

// =====================================================================
// Жалобы, блокировка, контакты, онлайн
// =====================================================================

const reportReasons = [
  'Мошенничество',
  'Запрещённый товар или услуга',
  'Спам или реклама',
  'Неверный контакт или цена',
  'Объявление неактуально',
  'Нецензурные слова или оскорбления',
  'Другое',
];

const userReportReasons = [
  'Мошенничество',
  'Оскорбления или угрозы',
  'Спам в сообщениях',
  'Выдаёт себя за другого',
  'Другое',
];

/// Меню «⋯» для другого пользователя: жалоба и блокировка.
Future<void> showUserMenu(BuildContext context, {required String userId, required String name}) async {
  final app = AppScope.of(context);
  if (app.user == null) {
    askLogin(context, 'Войдите, чтобы пожаловаться или заблокировать пользователя.');
    return;
  }
  final blocked = app.blockedIds.contains(userId);
  Profile? target;
  if (app.isAdmin) target = await app.fetchProfile(userId);
  if (!context.mounted) return;
  final act = await pickOption(context, name, [
    'Пожаловаться на пользователя',
    blocked ? 'Разблокировать' : 'Заблокировать',
    if (app.isAdmin) target?.banned == true ? 'Снять бан (админ)' : 'Забанить нарушителя (админ)',
  ], '');
  if (act == null || !context.mounted) return;
  if (act.endsWith('(админ)')) {
    final ban = act.startsWith('Забанить');
    if (ban) {
      final yes = await confirmDialog(context, tr('Забанить {n}?', {'n': name}),
          'Все его объявления будут сняты, публиковать и писать он больше не сможет.', 'Забанить');
      if (!yes || !context.mounted) return;
    }
    try {
      await app.adminBan(userId, ban);
      if (context.mounted) toast(context, ban ? 'Пользователь забанен' : 'Бан снят');
    } catch (e) {
      if (context.mounted) toast(context, AppState.serverMessage(e, 'Не удалось. Попробуйте ещё раз.'));
    }
    return;
  }
  if (act == 'Пожаловаться на пользователя') {
    final reason = await pickOption(context, 'Причина жалобы', userReportReasons, '');
    if (reason == null || !context.mounted) return;
    final r = await app.report(userId: userId, reason: reason);
    if (!context.mounted) return;
    toast(context, r == 'ok'
        ? 'Спасибо! Модератор разберётся.'
        : r == 'dup'
            ? 'Вы уже жаловались на этого пользователя.'
            : 'Не удалось отправить. Проверьте интернет.');
    return;
  }
  if (!blocked) {
    final yes = await confirmDialog(context, tr('Заблокировать {n}?', {'n': name}),
        'Он не сможет писать вам, а его объявления скроются из вашей ленты. Разблокировать можно в профиле.', 'Заблокировать');
    if (!yes || !context.mounted) return;
  }
  try {
    await app.setBlocked(userId, !blocked);
    if (context.mounted) toast(context, blocked ? 'Пользователь разблокирован' : 'Пользователь заблокирован');
  } catch (e) {
    if (context.mounted) toast(context, AppState.serverMessage(e, 'Не удалось. Попробуйте ещё раз.'));
  }
}

/// Открыть WhatsApp, Telegram или звонок по контакту из объявления/профиля.
void openContact(BuildContext context, String kind, String contact, {String? postId}) {
  final c = contact.trim();
  final d = contactDigits(c);
  final tg = telegramUser(c);
  final hasPhone = d.length >= 8;
  if (postId != null) AppScope.of(context).registerEvent(postId, 'contact');
  if (kind == 'wa' && hasPhone) {
    openUrl(context, 'https://wa.me/$d', c);
  } else if (kind == 'tg' && tg != null) {
    openUrl(context, 'https://t.me/$tg', c);
  } else if (kind == 'tg' && hasPhone) {
    openUrl(context, 'https://t.me/+$d', c);
  } else if (kind == 'call' && hasPhone) {
    openUrl(context, 'tel:+$d', c);
  } else {
    Clipboard.setData(ClipboardData(text: c));
    toast(context, tr('Контакт скопирован: {c}', {'c': c}));
  }
}

class ContactButtons extends StatelessWidget {
  const ContactButtons({super.key, required this.contact, this.postId});
  final String contact;
  final String? postId;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final hasPhone = contactDigits(contact).length >= 8;
    final hasTg = telegramUser(contact) != null || hasPhone;
    Widget btn(String label, String icon, Color bg, Color fg, String kind) => Expanded(
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => openContact(context, kind, contact, postId: postId),
              child: SizedBox(
                height: 46,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Ico(icon, size: 18, color: fg),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(label,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: fg)),
                  ),
                ]),
              ),
            ),
          ),
        );
    return Row(children: [
      if (hasPhone) btn('WhatsApp', 'phone', const Color(0xFF22C55E), Colors.white, 'wa'),
      if (hasPhone && hasTg) const SizedBox(width: 8),
      if (hasTg) btn('Telegram', 'send', const Color(0xFF229ED9), Colors.white, 'tg'),
      if (hasPhone) ...[
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: tr('Позвонить'),
          child: Material(
            color: p.soft,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => openContact(context, 'call', contact, postId: postId),
              child: SizedBox(width: 52, height: 46, child: Center(child: Ico('phoneCall', size: 20, color: p.text))),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// Зелёная точка «в сети» или время последнего захода.
class OnlineDot extends StatelessWidget {
  const OnlineDot({super.key, required this.lastSeen});
  final DateTime? lastSeen;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final on = isOnline(lastSeen);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: on ? p.ok : p.line2, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(onlineText(lastSeen), style: TextStyle(fontSize: 12.5, color: on ? p.ok : p.muted, fontWeight: on ? FontWeight.w600 : FontWeight.w400)),
    ]);
  }
}

/// Список заблокированных пользователей.
class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    return Scaffold(
      body: Column(children: [
        const SubHeader(title: 'Заблокированные'),
        Expanded(
          child: FutureBuilder<List<Profile>>(
            future: app.fetchProfiles(app.blockedIds),
            builder: (_, snap) {
              final list = snap.data ?? [];
              if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (list.isEmpty) {
                return const EmptyState(icon: 'lock', text: 'Вы никого не блокировали.\nЗаблокировать можно в чате или профиле через «⋯».');
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final x in list) ...[
                    Box(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Avatar(name: x.name, url: x.avatarUrl, size: 40),
                        const SizedBox(width: 10),
                        Expanded(child: Text(x.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text))),
                        TextButton(
                          onPressed: () async {
                            await app.setBlocked(x.id, false);
                            if (context.mounted) toast(context, 'Пользователь разблокирован');
                          },
                          child: Text('Разблокировать', style: TextStyle(color: p.accent, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ),
      ]),
    );
  }
}

// =====================================================================
// Отзывы: сводка рейтинга, карточка, экран всех отзывов
// =====================================================================

Color starColor(int s) => s >= 4 ? const Color(0xFF22C55E) : s == 3 ? const Color(0xFFF59E0B) : const Color(0xFFF43F5E);

class RatingSummary extends StatelessWidget {
  const RatingSummary({super.key, required this.reviews, this.onTap});
  final List<Review> reviews;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final n = reviews.length;
    final avg = n == 0 ? 0.0 : reviews.fold<int>(0, (a, r) => a + r.stars) / n;
    final counts = List<int>.filled(6, 0);
    for (final r in reviews) {
      counts[r.stars.clamp(1, 5)]++;
    }
    return Box(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(children: [
        SizedBox(
          width: 104,
          child: Column(children: [
            Text(n == 0 ? '—' : avg.toStringAsFixed(1), style: heading(42, weight: FontWeight.w800, color: p.text, height: 1)),
            const SizedBox(height: 6),
            StarsRow(value: avg, size: 15),
            const SizedBox(height: 6),
            Text('$n ${reviewsWord(n)}', style: TextStyle(fontSize: 12.5, color: p.muted)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(children: [
            for (var s = 5; s >= 1; s--)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  SizedBox(width: 14, child: Text('$s', style: TextStyle(fontSize: 12.5, color: p.text2, fontWeight: FontWeight.w600))),
                  const Ico('star', size: 11, color: Color(0xFFF5B82E), fill: Color(0xFFF5B82E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(4)),
                      alignment: AlignmentDirectional.centerStart,
                      child: FractionallySizedBox(
                        widthFactor: n == 0 ? 0 : counts[s] / n,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)]),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 22, child: Text('${counts[s]}', textAlign: TextAlign.end, style: TextStyle(fontSize: 12, color: p.muted))),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review, this.onReply});
  final Review review;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final r = review;
    final c = starColor(r.stars);
    return Box(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Avatar(name: r.author, url: r.authorAvatar, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.author, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: p.text)),
              const SizedBox(height: 2),
              StarsRow(value: r.stars.toDouble(), size: 13),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: c.withAlpha(36), borderRadius: BorderRadius.circular(10)),
            child: Text('${r.stars}.0', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c)),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(dateText(r.date), style: TextStyle(fontSize: 12, color: p.muted)),
          if (r.postTitle.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: p.okbg, borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Ico('check', size: 12, color: p.ok, stroke: 2.6),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(tr('Сделка: {t}', {'t': r.postTitle}),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: p.ok, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
        ]),
        if (r.text.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(r.text, style: TextStyle(fontSize: 14.5, color: p.text, height: 1.5)),
        ],
        if ((r.reply ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.sel,
              borderRadius: const BorderRadiusDirectional.only(
                topEnd: Radius.circular(14), bottomStart: Radius.circular(14), bottomEnd: Radius.circular(14), topStart: Radius.circular(4)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Ico('chat', size: 14, color: p.accent),
                const SizedBox(width: 6),
                Text('Ответ продавца', style: TextStyle(fontSize: 12, color: p.accent, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
              Text(r.reply!, style: TextStyle(fontSize: 13.5, color: p.text2, height: 1.45)),
            ]),
          ),
        ] else if (onReply != null) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onReply,
            style: TextButton.styleFrom(foregroundColor: p.accent, padding: EdgeInsets.zero),
            icon: Ico('chat', size: 16, color: p.accent),
            label: const Text('Ответить', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
    );
  }
}

/// Все отзывы пользователя (свои — с возможностью ответить).
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key, required this.userId, required this.name});
  final String userId;
  final String name;

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  List<Review> reviews = [];
  bool loading = true;
  int filter = 0; // 0 — все, 5..3 — звёзды, 2 — плохие (1–2)
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    load();
  }

  Future<void> load() async {
    final r = await AppScope.of(context).fetchReviews(widget.userId);
    if (mounted) {
      setState(() {
        reviews = r;
        loading = false;
      });
    }
  }

  Future<void> reply(Review r) async {
    final app = AppScope.of(context);
    final c = TextEditingController();
    final ok = await showGlassSheet<bool>(context, (ctx) {
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
    });
    if (ok != true || c.text.trim().isEmpty) return;
    try {
      await app.replyReview(r.id, c.text.trim());
      if (mounted) {
        toast(context, 'Ответ опубликован');
        load();
      }
    } catch (e) {
      if (mounted) toast(context, AppState.serverMessage(e, 'Не удалось ответить. Попробуйте позже.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final self = app.user?.id == widget.userId;
    final shown = reviews.where((r) {
      if (filter == 0) return true;
      if (filter == 2) return r.stars <= 2;
      return r.stars == filter;
    }).toList();
    const chips = [
      [0, 'Все'],
      [5, '★ 5'],
      [4, '★ 4'],
      [3, '★ 3'],
      [2, '★ 1–2'],
    ];
    return Scaffold(
      body: Column(children: [
        SubHeader(title: self ? 'Мои отзывы' : tr('Отзывы: {n}', {'n': widget.name})),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  color: p.accent,
                  onRefresh: load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
                    children: [
                      RatingSummary(reviews: reviews),
                      const SizedBox(height: 12),
                      if (reviews.isNotEmpty)
                        SizedBox(
                          height: 36,
                          child: ListView(scrollDirection: Axis.horizontal, children: [
                            for (final c in chips)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(end: 8),
                                child: ChoiceChip(
                                  label: Text(c[1] as String),
                                  selected: filter == c[0],
                                  onSelected: (_) => setState(() => filter = c[0] as int),
                                ),
                              ),
                          ]),
                        ),
                      const SizedBox(height: 12),
                      if (reviews.isEmpty)
                        EmptyState(
                          icon: 'star',
                          text: self
                              ? 'У вас пока нет отзывов.\nПосле сделки нажмите в чате «Сделка состоялась» — покупатель сможет оценить вас.'
                              : 'Отзывов пока нет.',
                        )
                      else if (shown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text('Нет отзывов с такой оценкой.', textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
                        ),
                      for (final r in shown) ...[
                        ReviewCard(review: r, onReply: self && (r.reply ?? '').isEmpty ? () => reply(r) : null),
                        const SizedBox(height: 10),
                      ],
                      if (reviews.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Отзывы оставляют только после подтверждённой сделки — поэтому они настоящие.',
                              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: p.muted, height: 1.4)),
                        ),
                    ],
                  ),
                ),
        ),
      ]),
    );
  }
}


// =====================================================================
// Поделиться объявлением
// =====================================================================

String postLink(Post p) => '$siteUrl?post=${p.id}';

Future<void> sharePost(BuildContext context, Post p) async {
  final link = postLink(p);
  final text = '${p.title} · ${priceOf(p)}';
  final act = await pickOption(context, 'Поделиться объявлением', ['Отправить в Telegram', 'Отправить в WhatsApp', 'Скопировать ссылку'], '');
  if (act == null || !context.mounted) return;
  if (act == 'Скопировать ссылку') {
    await Clipboard.setData(ClipboardData(text: '$text\n$link'));
    if (context.mounted) toast(context, 'Ссылка скопирована');
  } else if (act == 'Отправить в Telegram') {
    await openUrl(context, 'https://t.me/share/url?url=${Uri.encodeComponent(link)}&text=${Uri.encodeComponent(text)}', link);
  } else {
    await openUrl(context, 'https://wa.me/?text=${Uri.encodeComponent('$text\n$link')}', link);
  }
}

// =====================================================================
// Подписки на поиск
// =====================================================================

Future<void> subscribeToSearch(BuildContext context,
    {required Section section, String? category, String? city, String query = '', int? priceMax}) async {
  final app = AppScope.of(context);
  if (app.user == null) {
    askLogin(context, 'Войдите, чтобы подписаться на новые объявления.');
    return;
  }
  if (app.profile?.verified != true) {
    final go = await confirmDialog(context, 'Нужен Telegram',
        'Новые объявления по подписке присылает наш Telegram-бот. Подтвердите Telegram — это займёт полминуты.', 'Подтвердить',
        danger: false);
    if (go && context.mounted) push(context, const VerifyScreen());
    return;
  }
  final parts = [
    tr(sectionNames[section]!),
    if (category != null) tr(category),
    tr(city ?? 'Все города'),
    if (query.trim().isNotEmpty) '«${query.trim()}»',
    if (priceMax != null) tr('до {n} EGP', {'n': fmt(priceMax)}),
  ];
  final yes = await confirmDialog(context, 'Подписаться на поиск?',
      '${parts.join(' · ')}\n\n${tr('Бот пришлёт новые подходящие объявления, как только они появятся.')}', 'Подписаться',
      danger: false);
  if (!yes || !context.mounted) return;
  try {
    await app.addSavedSearch(section, category: category, city: city, query: query, priceMax: priceMax);
    if (context.mounted) toast(context, 'Готово! Новые объявления придут в Telegram.');
  } catch (e) {
    if (context.mounted) toast(context, AppState.serverMessage(e, 'Не удалось. Попробуйте ещё раз.'));
  }
}

class SavedSearchesScreen extends StatelessWidget {
  const SavedSearchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final list = app.savedSearches;
    return Scaffold(
      body: Column(children: [
        const SubHeader(title: 'Подписки на поиск'),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(
                  icon: 'bell',
                  text: 'Подписок пока нет.\nВ ленте нажмите 🔔 рядом с поиском — бот пришлёт новые подходящие объявления в Telegram.')
              : ListView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
                  children: [
                    for (final x in list) ...[
                      Box(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: p.sel, borderRadius: BorderRadius.circular(12)),
                            child: Center(child: Ico('bell', size: 20, color: p.accent)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(
                                  [tr(sectionNames[x.section]!), if (x.category != null) tr(x.category!)].join(' · '),
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text)),
                              const SizedBox(height: 2),
                              Text(
                                  [
                                    tr(x.city ?? 'Все города'),
                                    if (x.query.isNotEmpty) '«${x.query}»',
                                    if (x.priceMax != null) tr('до {n} EGP', {'n': fmt(x.priceMax!)}),
                                  ].join(' · '),
                                  style: TextStyle(fontSize: 13, color: p.muted)),
                            ]),
                          ),
                          IconBtn('trash', plain: true, color: p.bad, label: 'Удалить', onTap: () async {
                            await app.deleteSavedSearch(x.id);
                            if (context.mounted) toast(context, 'Подписка удалена');
                          }),
                        ]),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (app.profile?.notifyTg == false)
                      Text('Уведомления в Telegram выключены в профиле — включите их, чтобы получать подписки.',
                          style: TextStyle(fontSize: 12.5, color: p.warn)),
                  ],
                ),
        ),
      ]),
    );
  }
}

// =====================================================================
// Удаление аккаунта
// =====================================================================

Future<void> deleteAccountFlow(BuildContext context) async {
  final app = AppScope.of(context);
  final yes = await confirmDialog(context, 'Удалить аккаунт?',
      'Удалятся профиль, все ваши объявления, фото, сообщения и отзывы. Восстановить будет нельзя.', 'Удалить навсегда');
  if (!yes || !context.mounted) return;
  final sure = await confirmDialog(context, 'Точно удалить?', 'Это последнее подтверждение.', 'Да, удалить');
  if (!sure || !context.mounted) return;
  try {
    Navigator.of(context).popUntil((r) => r.isFirst);
    await app.deleteAccount();
    if (context.mounted) toast(context, 'Аккаунт удалён');
  } catch (e) {
    if (context.mounted) toast(context, AppState.serverMessage(e, 'Не удалось удалить аккаунт. Попробуйте позже.'));
  }
}

// =====================================================================
// Новости
// =====================================================================

const _newsTags = ['Важно', 'Визы', 'Безопасность', 'События', 'Курс', 'Сервис'];
const _tagHue = {
  'Визы': 0xFF6366F1,
  'Курс': 0xFF14B8A6,
  'События': 0xFFF59E0B,
  'Важно': 0xFFF43F5E,
  'Безопасность': 0xFFF97316,
  'Сервис': 0xFF3B82F6,
};
const _tagIcon = {'Визы': 'doc', 'Курс': 'coin', 'События': 'people', 'Важно': 'alert', 'Безопасность': 'shield', 'Сервис': 'pyramid'};

class NewsTab extends StatelessWidget {
  const NewsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final list = app.news.where((n) => n.published || app.isAdmin).toList();
    return UnderBar(
      bar: GlassBar(
        title: 'Новости',
        subtitle: 'Важное для своих в Египте',
        trailing: app.isAdmin ? IconBtn('plus', glass: true, label: 'Добавить новость', onTap: () => editNews(context)) : null,
      ),
      onRefresh: app.loadNews,
      slivers: [
        if (!app.newsLoaded)
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())))
        else if (list.isEmpty)
          const SliverToBoxAdapter(child: EmptyState(icon: 'news', text: 'Новостей пока нет.'))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            sliver: SliverList.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final n = list[i];
                final hue = Color(_tagHue[n.tag] ?? 0xFF14B8A6);
                return Box(
                  padding: const EdgeInsets.all(14),
                  onTap: () => push(context, NewsDetailScreen(item: n)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [hue.withAlpha(p.dark ? 90 : 60), hue.withAlpha(p.dark ? 30 : 22)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(child: Ico(_tagIcon[n.tag] ?? 'news', size: 22, stroke: 1.9, color: Color.lerp(hue, p.text, .1))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(n.tag, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color.lerp(hue, p.text, p.dark ? .25 : 0))),
                          Text('  ·  ${dateText(n.date)}', style: TextStyle(fontSize: 12.5, color: p.muted)),
                          if (!n.published) Text('  ·  ${tr('черновик')}', style: TextStyle(fontSize: 12.5, color: p.warn)),
                        ]),
                        const SizedBox(height: 4),
                        Text(n.title, style: heading(16, weight: FontWeight.w800, color: p.text)),
                        const SizedBox(height: 4),
                        Text(n.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: p.text2, height: 1.45)),
                      ]),
                    ),
                  ]),
                );
              },
            ),
          ),
      ],
    );
  }
}

class NewsDetailScreen extends StatelessWidget {
  const NewsDetailScreen({super.key, required this.item});
  final NewsPost item;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    return Scaffold(
      body: Column(children: [
        SubHeader(
          title: 'Новости',
          trailing: app.isAdmin
              ? IconBtn('edit', label: 'Редактировать', onTap: () async {
                  await editNews(context, item: item);
                  if (context.mounted) Navigator.maybePop(context);
                })
              : null,
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 30 + MediaQuery.of(context).padding.bottom),
            children: [
              Text('${tr(item.tag)} · ${dateText(item.date)}', style: TextStyle(fontSize: 13, color: p.muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(item.title, style: heading(22, weight: FontWeight.w800, color: p.text)),
              const SizedBox(height: 14),
              SelectionArea(child: Text(item.body, style: TextStyle(fontSize: 15.5, color: p.body, height: 1.6))),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Админ: добавить или изменить новость.
Future<void> editNews(BuildContext context, {NewsPost? item}) async {
  final app = AppScope.of(context);
  final title = TextEditingController(text: item?.title ?? '');
  final body = TextEditingController(text: item?.body ?? '');
  var tag = item?.tag ?? _newsTags.first;
  var published = item?.published ?? true;
  final res = await showGlassSheet<String>(
    context,
    (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      final p = Pal.of(ctx);
      return Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SheetHandle(),
            Text(item == null ? 'Новая новость' : 'Изменить новость', style: heading(20, weight: FontWeight.w800, color: p.text)),
            const SizedBox(height: 12),
            PickField(label: 'Рубрика', value: tag, options: _newsTags, onChanged: (v) => setSheet(() => tag = v)),
            const SizedBox(height: 12),
            Field(label: 'Заголовок', controller: title, hint: 'Коротко и понятно', capitalization: TextCapitalization.sentences),
            const SizedBox(height: 12),
            Field(label: 'Текст', controller: body, maxLines: 8, hint: 'Подробности', capitalization: TextCapitalization.sentences),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text('Опубликована', style: TextStyle(fontSize: 15, color: p.text))),
              Switch(value: published, onChanged: (v) => setSheet(() => published = v)),
            ]),
            const SizedBox(height: 12),
            PrimaryButton('Сохранить', onPressed: () => Navigator.pop(ctx, 'save')),
            if (item != null)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'delete'),
                style: TextButton.styleFrom(foregroundColor: p.bad),
                child: const Text('Удалить новость'),
              ),
          ]),
        ),
      );
    }),
  );
  if (res == null || !context.mounted) return;
  try {
    if (res == 'delete') {
      await app.deleteNews(item!.id);
    } else {
      if (title.text.trim().length < 3) {
        toast(context, 'Заголовок должен быть не короче 3 символов');
        return;
      }
      await app.saveNews(id: item?.id, tag: tag, title: title.text.trim(), body: body.text.trim(), published: published);
    }
    if (context.mounted) toast(context, 'Готово');
  } catch (e) {
    if (context.mounted) toast(context, AppState.serverMessage(e, 'Не удалось. Попробуйте ещё раз.'));
  }
}

// =====================================================================
// Админ: статистика
// =====================================================================

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  Future<Map<String, dynamic>>? future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= AppScope.of(context).adminStats();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    const labels = [
      ['users', 'Пользователей'],
      ['users_7d', 'Новых за 7 дней'],
      ['online', 'Сейчас в сети'],
      ['verified', 'Проверенных'],
      ['posts_active', 'Объявлений в ленте'],
      ['posts_pending', 'На проверке'],
      ['posts_7d', 'Объявлений за 7 дней'],
      ['messages_24h', 'Сообщений за сутки'],
      ['views', 'Просмотров всего'],
      ['deals', 'Сделок'],
      ['reviews', 'Отзывов'],
      ['banned', 'Забанено'],
    ];
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
        }
        final d = snap.data ?? {};
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: [
              for (final l in labels)
                Box(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('${d[l[0]] ?? '—'}', style: heading(22, weight: FontWeight.w800, color: p.text)),
                    Text(l[1], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: p.muted)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 12),
          OutlineBtn('Обновить', icon: 'check', onPressed: () => setState(() => future = AppScope.of(context).adminStats())),
          const SizedBox(height: 8),
          PrimaryButton('Добавить новость', icon: 'plus', onPressed: () => editNews(context)),
          const SizedBox(height: 8),
          Text('Забанить нарушителя: откройте его профиль → «⋯» → «Забанить нарушителя».',
              style: TextStyle(fontSize: 12.5, color: p.muted, height: 1.4)),
        ]);
      },
    );
  }
}
