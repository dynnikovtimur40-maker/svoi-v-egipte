import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const SvoiApp());
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

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
      child: MaterialApp(
        title: 'Свои в Египте',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF0E7C86),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

// ---------------- Вход и регистрация ----------------

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
    app.load();
    app.loadFavorites();
    sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      app.loadFavorites();
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
    if (l.contains('invalid login')) return 'Неверная почта или пароль';
    if (l.contains('already registered') || l.contains('already been registered')) {
      return 'Эта почта уже зарегистрирована — войдите';
    }
    if (l.contains('password should be')) return 'Пароль должен быть не короче 6 символов';
    if (l.contains('invalid') && l.contains('email')) return 'Проверьте адрес почты';
    if (l.contains('rate limit')) return 'Слишком много попыток, подождите минуту';
    return m;
  }

  Future<void> submit() async {
    final e = email.text.trim();
    final p = pass.text;
    if (!e.contains('@') || p.length < 6 || (register && name.text.trim().isEmpty)) {
      setState(() => message = register
          ? 'Заполните имя, почту и пароль (от 6 символов)'
          : 'Введите почту и пароль (от 6 символов)');
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
            email: e, password: p, data: {'name': name.text.trim()});
        if (res.session == null && mounted) {
          setState(() => message = 'Готово! Проверьте почту и подтвердите адрес, затем войдите.');
        }
      } else {
        await auth.signInWithPassword(email: e, password: p);
      }
    } on AuthException catch (err) {
      if (mounted) setState(() => message = translate(err.message));
    } catch (_) {
      if (mounted) setState(() => message = 'Нет связи с сервером, попробуйте ещё раз');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> resetPassword() async {
    final e = email.text.trim();
    if (!e.contains('@')) {
      setState(() => message = 'Введите почту, и мы пришлём ссылку для сброса пароля');
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(e);
      if (mounted) setState(() => message = 'Письмо для сброса пароля отправлено');
    } catch (_) {
      if (mounted) setState(() => message = 'Не удалось отправить письмо, попробуйте позже');
    }
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0B6770);
    InputDecoration deco(String label, {Widget? suffix}) => InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          suffixIcon: suffix,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        );
    return Scaffold(
      backgroundColor: teal,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 40, 24, 24), children: [
          const Text('Свои в Египте',
              style: TextStyle(
                  color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Объявления, услуги, работа и новости для русскоязычных в Египте',
              style: TextStyle(color: Color(0xFFD6EEF0), fontSize: 16, height: 1.4)),
          const SizedBox(height: 32),
          SegmentedButton<bool>(
            style: SegmentedButton.styleFrom(
              backgroundColor: const Color(0xFF0E7C86),
              foregroundColor: Colors.white,
              selectedBackgroundColor: Colors.white,
              selectedForegroundColor: teal,
            ),
            segments: const [
              ButtonSegment(value: false, label: Text('Вход')),
              ButtonSegment(value: true, label: Text('Регистрация')),
            ],
            selected: {register},
            onSelectionChanged: (v) => setState(() {
              register = v.first;
              message = null;
            }),
          ),
          const SizedBox(height: 16),
          if (register) ...[
            TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: deco('Ваше имя')),
            const SizedBox(height: 12),
          ],
          TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: deco('Электронная почта')),
          const SizedBox(height: 12),
          TextField(
            controller: pass,
            obscureText: hide,
            decoration: deco('Пароль (от 6 символов)',
                suffix: IconButton(
                  icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => hide = !hide),
                )),
            onSubmitted: (_) => submit(),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, style: const TextStyle(color: Color(0xFFFFE3B0), fontSize: 15)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : submit,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: teal,
              minimumSize: const Size.fromHeight(54),
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            child: busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text(register ? 'Зарегистрироваться' : 'Войти'),
          ),
          if (!register)
            TextButton(
              onPressed: resetPassword,
              child: const Text('Забыли пароль?', style: TextStyle(color: Color(0xFFD6EEF0))),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => AppScope.of(context).setGuest(true),
            child: const Text('Пропустить, просто посмотреть',
                style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ]),
      ),
    );
  }
}

// ---------------- Главный каркас ----------------

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;

  static const pages = <Widget>[
    PostListPage(section: Section.ads),
    PostListPage(section: Section.services),
    PostListPage(section: Section.jobs),
    NewsPage(),
    MorePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Свои в Египте',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Город',
            onSelected: app.setCity,
            itemBuilder: (_) => cities
                .map((c) => PopupMenuItem(value: c, child: Text(c)))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                const Icon(Icons.place_outlined, size: 20),
                const SizedBox(width: 4),
                Text(app.city),
                const Icon(Icons.arrow_drop_down),
              ]),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: tab, children: pages),
      floatingActionButton: tab <= 2
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AddPostScreen(section: Section.values[tab])),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Разместить'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.sell_outlined), label: 'Объявления'),
          NavigationDestination(
              icon: Icon(Icons.handyman_outlined), label: 'Услуги'),
          NavigationDestination(
              icon: Icon(Icons.work_outline), label: 'Работа'),
          NavigationDestination(
              icon: Icon(Icons.newspaper_outlined), label: 'Новости'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'Ещё'),
        ],
      ),
    );
  }
}

Future<void> favOrLogin(BuildContext context, String id) async {
  final ok = await AppScope.of(context).toggleFav(id);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите, чтобы добавлять в избранное')));
  }
}

// ---------------- Лента объявлений / услуг / работы ----------------

class PostListPage extends StatefulWidget {
  const PostListPage({super.key, required this.section});
  final Section section;

  @override
  State<PostListPage> createState() => _PostListPageState();
}

class _PostListPageState extends State<PostListPage> {
  String? category;
  String query = '';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final items = app.filter(widget.section, category, query);
    final cats = categories[widget.section]!;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: InputDecoration(
            hintText: 'Поиск: ${sectionNames[widget.section]!.toLowerCase()}',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: const Text('Все'),
                selected: category == null,
                onSelected: (_) => setState(() => category = null),
              ),
            ),
            for (final c in cats)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(c),
                  selected: category == c,
                  onSelected: (_) => setState(() => category = c),
                ),
              ),
          ],
        ),
      ),
      if (app.error != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(app.error!, style: const TextStyle(color: Color(0xFFA33A2B))),
        ),
      if (app.loading) const LinearProgressIndicator(minHeight: 2),
      Expanded(
        child: RefreshIndicator(
          onRefresh: app.load,
          child: items.isEmpty
            ? ListView(children: const [Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Пока ничего нет.\nСтаньте первым — нажмите «Разместить».',
                    textAlign: TextAlign.center,
                  ),
                ),
              )])
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                itemCount: items.length,
                itemBuilder: (_, i) => PostCard(post: items[i]),
              ),
        ),
      ),
    ]);
  }
}

IconData iconFor(Post p) {
  switch (p.section) {
    case Section.ads:
      return p.category.contains('жил') ? Icons.home_outlined : Icons.sell_outlined;
    case Section.services:
      return Icons.handyman_outlined;
    case Section.jobs:
      return Icons.work_outline;
  }
}

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final fav = app.favorites.contains(post.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => PostDetailScreen(post: post))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconFor(post), size: 32, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(priceText(post.priceEgp),
                    style: TextStyle(
                        color: cs.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text('${post.city} · ${post.category}',
                      style: Theme.of(context).textTheme.bodySmall),
                  if (post.verified) const VerifiedBadge(),
                  if (post.rating != null)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      Text(post.rating!.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.bodySmall),
                    ]),
                ]),
              ]),
            ),
            IconButton(
              icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                  color: fav ? Colors.redAccent : null),
              onPressed: () => favOrLogin(context, post.id),
            ),
          ]),
        ),
      ),
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F6E8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.verified, size: 14, color: Color(0xFF1E8E3E)),
        SizedBox(width: 3),
        Text('Проверен',
            style: TextStyle(fontSize: 11, color: Color(0xFF1E8E3E))),
      ]),
    );
  }
}

// ---------------- Карточка объявления ----------------

class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final fav = app.favorites.contains(post.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(sectionNames[post.section]!),
        actions: [
          IconButton(
            icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                color: fav ? Colors.redAccent : null),
            onPressed: () => favOrLogin(context, post.id),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(iconFor(post), size: 72, color: cs.onPrimaryContainer),
        ),
        const SizedBox(height: 16),
        Text(post.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(priceText(post.priceEgp),
            style: TextStyle(
                fontSize: 18, color: cs.primary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          Chip(avatar: const Icon(Icons.place_outlined, size: 18), label: Text(post.city)),
          Chip(label: Text(post.category)),
          if (post.verified) const VerifiedBadge(),
        ]),
        const SizedBox(height: 12),
        Text(post.description, style: const TextStyle(fontSize: 16, height: 1.4)),
        const Divider(height: 32),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Text(post.author.isEmpty ? '?' : post.author.characters.first)),
          title: Text(post.author),
          subtitle: Text(post.rating != null
              ? 'Рейтинг ${post.rating!.toStringAsFixed(1)} ★'
              : 'Новый пользователь'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: post.contact));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Контакт скопирован: ${post.contact}')));
          },
          icon: const Icon(Icons.chat_outlined),
          label: Text('Связаться: ${post.contact}'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            app.report(post.id);
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Спасибо! Модератор проверит объявление.')));
          },
          icon: const Icon(Icons.flag_outlined),
          label: const Text('Пожаловаться'),
        ),
        const SizedBox(height: 8),
        Card(
          color: const Color(0xFFFFF4E0),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              '⚠️ Не переводите предоплату до встречи и проверки. '
              'Пользуйтесь продавцами с отметкой «Проверен».',
            ),
          ),
        ),
      ]),
    );
  }
}

// ---------------- Размещение ----------------

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key, required this.section});
  final Section section;

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final formKey = GlobalKey<FormState>();
  late Section section = widget.section;
  late String category = categories[section]!.first;
  String city = cities[1];
  final title = TextEditingController();
  final desc = TextEditingController();
  final price = TextEditingController();
  final contact = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    for (final c in [title, desc, price, contact]) {
      c.dispose();
    }
    super.dispose();
  }

  String? notEmpty(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Заполните поле' : null;

  Future<void> save() async {
    final app = AppScope.of(context);
    if (app.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Войдите или зарегистрируйтесь, чтобы разместить объявление')));
      return;
    }
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await app.addPost(
        section: section,
        category: category,
        title: title.text.trim(),
        description: desc.text.trim(),
        city: city,
        contact: contact.text.trim(),
        priceEgp: int.tryParse(price.text.replaceAll(' ', '')),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Опубликовано!')));
    } catch (_) {
      if (!mounted) return;
      setState(() => busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось опубликовать. Проверьте интернет.')));
    }
  }

  Widget dropdown(String label, String value, List<String> items,
      ValueChanged<String> onChanged) {
    return InputDecorator(
      decoration: InputDecoration(
          labelText: label, border: const OutlineInputBorder()),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(title: const Text('Новое объявление')),
      body: Form(
        key: formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SegmentedButton<Section>(
            segments: Section.values
                .map((s) => ButtonSegment(value: s, label: Text(sectionNames[s]!)))
                .toList(),
            selected: {section},
            onSelectionChanged: (s) => setState(() {
              section = s.first;
              category = categories[section]!.first;
            }),
          ),
          gap,
          dropdown('Категория', category, categories[section]!,
              (v) => setState(() => category = v)),
          gap,
          dropdown('Город', city, cities.sublist(1),
              (v) => setState(() => city = v)),
          gap,
          TextFormField(
            controller: title,
            validator: notEmpty,
            decoration: const InputDecoration(
                labelText: 'Заголовок', border: OutlineInputBorder()),
          ),
          gap,
          TextFormField(
            controller: desc,
            validator: notEmpty,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: 'Описание', border: OutlineInputBorder()),
          ),
          gap,
          TextFormField(
            controller: price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Цена в EGP (пусто — договорная, 0 — бесплатно)',
                border: OutlineInputBorder()),
          ),
          gap,
          TextFormField(
            controller: contact,
            validator: notEmpty,
            decoration: const InputDecoration(
                labelText: 'Контакт (Telegram, WhatsApp или телефон)',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Опубликовать'),
          ),
        ]),
      ),
    );
  }
}

// ---------------- Новости ----------------

class NewsPage extends StatelessWidget {
  const NewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: demoNews.length,
      itemBuilder: (_, i) {
        final n = demoNews[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(n.tag, style: const TextStyle(fontSize: 12)),
                ),
                const Spacer(),
                Text(n.date, style: Theme.of(context).textTheme.bodySmall),
              ]),
              const SizedBox(height: 8),
              Text(n.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(n.summary),
            ]),
          ),
        );
      },
    );
  }
}

// ---------------- Ещё: конвертер, справочник, избранное ----------------

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final favs = app.posts.where((p) => app.favorites.contains(p.id)).toList();
    final groups = <String, List<DirItem>>{};
    for (final d in demoDirectory) {
      groups.putIfAbsent(d.category, () => []).add(d);
    }

    return ListView(padding: const EdgeInsets.all(12), children: [
      Card(
        child: ListTile(
          leading: CircleAvatar(child: Text(app.userName.isEmpty ? '?' : app.userName.characters.first.toUpperCase())),
          title: Text(app.user == null ? 'Гость' : app.userName),
          subtitle: Text(app.user?.email ?? 'Войдите, чтобы размещать объявления'),
          trailing: TextButton(
            onPressed: () => app.signOut(),
            child: Text(app.user == null ? 'Войти' : 'Выйти'),
          ),
        ),
      ),
      const SizedBox(height: 8),
      const ConverterCard(),
      const SizedBox(height: 8),
      Card(
        child: ExpansionTile(
          leading: const Icon(Icons.favorite_outline),
          title: Text('Избранное (${favs.length})'),
          children: favs.isEmpty
              ? [const ListTile(title: Text('Нажмите ♡ на объявлении'))]
              : favs
                  .map((p) => ListTile(
                        title: Text(p.title),
                        subtitle: Text(priceText(p.priceEgp)),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => PostDetailScreen(post: p))),
                      ))
                  .toList(),
        ),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text('Справочник',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      for (final e in groups.entries)
        Card(
          child: ExpansionTile(
            leading: Icon(e.key == 'Экстренные номера'
                ? Icons.emergency_outlined
                : Icons.local_hospital_outlined),
            title: Text(e.key),
            children: e.value
                .map((d) => ListTile(
                      title: Text(d.name),
                      subtitle: Text(
                          [d.city, d.note].where((s) => s.isNotEmpty).join(' · ')),
                      trailing: TextButton(
                        child: Text(d.phone),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: d.phone));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Номер скопирован: ${d.phone}')));
                        },
                      ),
                    ))
                .toList(),
          ),
        ),
      const SizedBox(height: 16),
      const Center(
        child: Text('Свои в Египте · версия 0.1 (демо)',
            style: TextStyle(color: Colors.grey)),
      ),
    ]);
  }
}

class ConverterCard extends StatefulWidget {
  const ConverterCard({super.key});

  @override
  State<ConverterCard> createState() => _ConverterCardState();
}

class _ConverterCardState extends State<ConverterCard> {
  double egp = 1000;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.currency_exchange),
            SizedBox(width: 8),
            Text('Конвертер валют',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: '1000',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Сумма в египетских фунтах (EGP)',
                border: OutlineInputBorder()),
            onChanged: (v) =>
                setState(() => egp = double.tryParse(v.replaceAll(',', '.')) ?? 0),
          ),
          const SizedBox(height: 10),
          Text('≈ ${fmt(egp * rubPerEgp)} ₽', style: style),
          Text('≈ ${(egp / egpPerUsd).toStringAsFixed(2)} \$', style: style),
          Text('≈ ${(egp / egpPerEur).toStringAsFixed(2)} €', style: style),
          const SizedBox(height: 4),
          Text('Примерный курс, для ориентира',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}
