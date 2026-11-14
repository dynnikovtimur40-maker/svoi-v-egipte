import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'i18n.dart';

enum Section { ads, services, jobs }

const sectionNames = {
  Section.ads: 'Объявления',
  Section.services: 'Услуги',
  Section.jobs: 'Работа',
};

const sectionSingle = {
  Section.ads: 'Объявление',
  Section.services: 'Услуга',
  Section.jobs: 'Работа',
};

const cities = [
  'Все города',
  'Каир',
  'Новый Каир',
  'Гиза',
  'Шейх-Зайед',
  '6-го Октября',
  'Хургада',
  'Сахл-Хашиш',
  'Эль-Гуна',
  'Макади-Бей',
  'Сома-Бей',
  'Сафага',
  'Эль-Кусейр',
  'Марса-Алам',
  'Шарм-эль-Шейх',
  'Дахаб',
  'Нувейба',
  'Таба',
  'Александрия',
  'Эль-Аламейн',
  'Айн-Сохна',
  'Луксор',
  'Асуан',
];

const categories = {
  Section.ads: [
    'Аренда жилья',
    'Аренда посуточно',
    'Продажа жилья',
    'Телефоны',
    'Электроника',
    'Бытовая техника',
    'Мебель',
    'Авто',
    'Мото и скутеры',
    'Одежда',
    'Детские товары',
    'Спорт и дайвинг',
    'Животные',
    'Отдам даром',
    'Другое',
  ],
  Section.services: [
    'Ремонт',
    'Сантехника и электрика',
    'Уборка',
    'Визы и документы',
    'Юристы',
    'Переводчики',
    'Репетиторы',
    'Красота',
    'Здоровье',
    'Перевозки',
    'Трансфер и такси',
    'Экскурсии',
    'Фото и видео',
    'IT и компьютеры',
    'Няни',
    'Другое',
  ],
  Section.jobs: ['Вакансии', 'Подработка', 'Резюме', 'Удалёнка', 'Туризм', 'Отели и рестораны', 'Другое'],
};

const searchHints = {
  Section.ads: 'Квартира, iPhone, диван…',
  Section.services: 'Сантехник, виза, репетитор…',
  Section.jobs: 'Гид, няня, подработка…',
};

const priceLabels = {
  Section.ads: 'Цена, EGP',
  Section.services: 'Стоимость, EGP',
  Section.jobs: 'Зарплата в месяц, EGP',
};

/// Курс: подгружается с сервера при запуске (функция rates), здесь — запасные значения.
double rubPerEgp = 1.65;
double egpPerUsd = 49.0;
double egpPerEur = 53.0;
DateTime? ratesUpdated;

const photoBucket = 'post-photos';

String fmt(num n) {
  final s = n.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

String priceMain(int? egp) {
  if (egp == null) return tr('Договорная');
  if (egp == 0) return tr('Бесплатно');
  return '${fmt(egp)} EGP';
}

/// Цена с учётом раздела: для работы — зарплата в месяц.
String priceOf(Post p) {
  if (p.section == Section.jobs) {
    if (p.priceEgp == null || p.priceEgp == 0) return tr('Зарплата договорная');
    return tr('{n} EGP/мес', {'n': fmt(p.priceEgp!)});
  }
  return priceMain(p.priceEgp);
}

/// Телефон: 10–15 цифр, можно с «+».
String? normalizePhone(String raw) {
  final s = raw.replaceAll(RegExp(r'[\s\-()]'), '');
  if (!RegExp(r'^\+?\d{10,15}$').hasMatch(s)) return null;
  return s.startsWith('+') ? s : '+$s';
}

/// Telegram: @username, 5–32 символа, латиница, цифры, «_».
String? normalizeTelegram(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'^(https?://)?t\.me/'), '');
  if (s.startsWith('@')) s = s.substring(1);
  if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]{4,31}$').hasMatch(s)) return null;
  return '@$s';
}

String priceRub(int? egp) =>
    (egp == null || egp == 0) ? '' : '≈ ${fmt(egp * rubPerEgp)} ₽';

String dateText(DateTime d) {
  final l = d.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(l.year, l.month, l.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return tr('Сегодня');
  if (diff == 1) return tr('Вчера');
  final y = l.year == now.year ? '' : ' ${l.year}';
  return '${l.day} ${monthShort(l.month)}$y';
}

String timeText(DateTime d) {
  final l = d.toLocal();
  final now = DateTime.now();
  final hm = '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  if (l.year == now.year && l.month == now.month && l.day == now.day) return hm;
  return dateText(l);
}

String plural(int n, String one, String few, String many) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
  return many;
}

String initialOf(String name) {
  final s = name.replaceAll(RegExp(r'[«»"\s]'), '');
  return s.isEmpty ? '?' : s.characters.first.toUpperCase();
}

class Profile {
  Profile({
    required this.id,
    this.name = '',
    this.city = 'Каир',
    this.phone,
    this.avatarUrl,
    this.verified = false,
    this.role = 'user',
    this.lang = 'ru',
    this.tgUsername,
    this.lastSeen,
    this.banned = false,
    this.notifyTg = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Profile.fromMap(Map m) => Profile(
        id: (m['id'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        city: (m['city'] ?? 'Каир') as String,
        phone: m['phone'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        verified: (m['verified'] ?? false) as bool,
        role: (m['role'] ?? 'user') as String,
        lang: (m['lang'] ?? 'ru') as String,
        tgUsername: m['tg_username'] as String?,
        lastSeen: DateTime.tryParse((m['last_seen'] ?? '') as String),
        banned: (m['banned'] ?? false) as bool,
        notifyTg: (m['notify_tg'] ?? true) as bool,
        createdAt: DateTime.tryParse((m['created_at'] ?? '') as String),
      );

  final String id;
  final String name;
  final String city;
  final String? phone;
  final String? avatarUrl;
  final bool verified;
  final String role;
  final String lang;
  final String? tgUsername;
  final DateTime? lastSeen;
  final bool banned;
  final bool notifyTg;
  final DateTime createdAt;
}

/// Новость из админки.
class NewsPost {
  NewsPost({required this.id, required this.tag, required this.title, required this.body, required this.date, this.published = true,
      this.source, this.url, this.lang, this.auto = false});
  factory NewsPost.fromMap(Map m) => NewsPost(
        id: (m['id'] as num).toInt(),
        tag: (m['tag'] ?? '') as String,
        title: (m['title'] ?? '') as String,
        body: (m['body'] ?? '') as String,
        published: (m['published'] ?? true) as bool,
        source: m['source'] as String?,
        url: m['url'] as String?,
        lang: m['lang'] as String?,
        auto: (m['auto'] ?? false) as bool,
        date: DateTime.tryParse((m['created_at'] ?? '') as String) ?? DateTime.now(),
      );
  final String? source;
  final String? url;
  final String? lang;
  final bool auto;
  final int id;
  final String tag;
  final String title;
  final String body;
  final bool published;
  final DateTime date;
}

/// Подписка на поиск: бот пришлёт новые подходящие объявления.
class SavedSearch {
  SavedSearch({required this.id, required this.section, this.category, this.city, this.query = '', this.priceMax});
  factory SavedSearch.fromMap(Map m) => SavedSearch(
        id: (m['id'] as num).toInt(),
        section: Section.values.firstWhere((x) => x.name == m['section'], orElse: () => Section.ads),
        category: m['category'] as String?,
        city: m['city'] as String?,
        query: (m['query'] ?? '') as String,
        priceMax: (m['price_max'] as num?)?.toInt(),
      );
  final int id;
  final Section section;
  final String? category;
  final String? city;
  final String query;
  final int? priceMax;
}

class Post {
  Post({
    required this.id,
    required this.userId,
    required this.section,
    required this.category,
    required this.title,
    required this.description,
    required this.city,
    required this.author,
    required this.contact,
    this.priceEgp,
    this.photos = const [],
    this.status = 'active',
    this.verified = false,
    this.authorAvatar,
    this.authorSince,
    this.rejectReason,
    this.autoFlags,
    this.views = 0,
    this.contacts = 0,
    this.authorLastSeen,
    this.vipUntil,
    this.highlightUntil,
    DateTime? bumpedAt,
    DateTime? date,
  })  : date = date ?? DateTime.now(),
        bumpedAt = bumpedAt ?? date ?? DateTime.now();

  factory Post.fromMap(Map<String, dynamic> m) {
    final prof = m['profiles'] is Map ? m['profiles'] as Map : const {};
    return Post(
      id: m['id'] as String,
      userId: m['user_id'] as String,
      section: Section.values.firstWhere((s) => s.name == m['section'],
          orElse: () => Section.ads),
      category: (m['category'] ?? '') as String,
      title: (m['title'] ?? '') as String,
      description: (m['description'] ?? '') as String,
      city: (m['city'] ?? '') as String,
      contact: (m['contact'] ?? '') as String,
      priceEgp: (m['price_egp'] as num?)?.toInt(),
      photos: ((m['photos'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      status: (m['status'] ?? 'active') as String,
      author: (prof['name'] ?? 'Пользователь') as String,
      verified: (prof['verified'] ?? false) as bool,
      authorAvatar: prof['avatar_url'] as String?,
      authorSince: DateTime.tryParse((prof['created_at'] ?? '') as String),
      rejectReason: m['reject_reason'] as String?,
      autoFlags: m['auto_flags'] as String?,
      views: ((m['views'] ?? 0) as num).toInt(),
      contacts: ((m['contacts'] ?? 0) as num).toInt(),
      authorLastSeen: DateTime.tryParse((prof['last_seen'] ?? '') as String),
      vipUntil: DateTime.tryParse((m['vip_until'] ?? '') as String),
      highlightUntil: DateTime.tryParse((m['highlight_until'] ?? '') as String),
      bumpedAt: DateTime.tryParse((m['bumped_at'] ?? '') as String),
      date: DateTime.tryParse((m['created_at'] ?? '') as String),
    );
  }

  final String id;
  final String userId;
  final Section section;
  final String category;
  final String title;
  final String description;
  final String city;
  final String author;
  final String contact;
  final int? priceEgp;
  final List<String> photos;
  final String status;
  final bool verified;
  final String? authorAvatar;
  final DateTime? authorSince;
  final String? rejectReason;
  final String? autoFlags;
  final int views;
  final int contacts;
  final DateTime? authorLastSeen;
  final DateTime? vipUntil;
  final DateTime? highlightUntil;
  final DateTime bumpedAt;
  final DateTime date;

  bool get isVip => vipUntil != null && vipUntil!.isAfter(DateTime.now());
  bool get isHighlighted => isVip || (highlightUntil != null && highlightUntil!.isAfter(DateTime.now()));
}

/// Платная услуга продвижения.
class Product {
  Product({required this.code, required this.title, required this.price, required this.days});
  factory Product.fromMap(Map m) => Product(
        code: m['code'] as String,
        title: (m['title'] ?? '') as String,
        price: (m['price_egp'] as num).toInt(),
        days: ((m['days'] ?? 0) as num).toInt(),
      );
  final String code;
  final String title;
  final int price;
  final int days;
}

/// Заявка на проверку профиля.
class Verification {
  Verification({required this.id, required this.userId, required this.status, this.reason, this.photos = 0,
      this.tgUsername, this.userName = '', this.userCity = '', DateTime? date})
      : date = date ?? DateTime.now();
  factory Verification.fromMap(Map m) {
    final u = m['user'] is Map ? m['user'] as Map : const {};
    return Verification(
      id: (m['id'] as num).toInt(),
      userId: m['user_id'] as String,
      status: (m['status'] ?? 'new') as String,
      reason: m['reason'] as String?,
      photos: ((m['photos'] ?? 0) as num).toInt(),
      tgUsername: m['tg_username'] as String?,
      userName: (u['name'] ?? '') as String,
      userCity: (u['city'] ?? '') as String,
      date: DateTime.tryParse((m['updated_at'] ?? m['created_at'] ?? '') as String),
    );
  }
  final int id;
  final String userId;
  final String status;
  final String? reason;
  final int photos;
  final String? tgUsername;
  final String userName;
  final String userCity;
  final DateTime date;
}

class Review {
  Review({
    required this.id,
    required this.author,
    this.authorAvatar,
    required this.stars,
    required this.text,
    required this.date,
    this.postTitle = '',
    this.reply,
  });
  final int id;
  final String author;
  final String? authorAvatar;
  final int stars;
  final String text;
  final DateTime date;
  final String postTitle;
  final String? reply;
}

/// Подтверждённая продавцом сделка — только после неё можно оставить отзыв.
class Deal {
  Deal({required this.id, required this.sellerId, required this.buyerId, this.postId, this.reviewed = false});
  factory Deal.fromMap(Map m, {bool reviewed = false}) => Deal(
        id: (m['id'] as num).toInt(),
        sellerId: m['seller_id'] as String,
        buyerId: m['buyer_id'] as String,
        postId: m['post_id'] as String?,
        reviewed: reviewed,
      );
  final int id;
  final String sellerId;
  final String buyerId;
  final String? postId;
  final bool reviewed;
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.date,
    this.postId,
    this.read = false,
    this.imageUrl,
  });

  factory ChatMessage.fromMap(Map m) => ChatMessage(
        id: (m['id'] as num).toInt(),
        senderId: m['sender_id'] as String,
        receiverId: m['receiver_id'] as String,
        postId: m['post_id'] as String?,
        text: (m['text'] ?? '') as String,
        read: (m['read'] ?? false) as bool,
        imageUrl: m['image_url'] as String?,
        date: DateTime.tryParse((m['created_at'] ?? '') as String) ?? DateTime.now(),
      );

  final int id;
  final String senderId;
  final String receiverId;
  final String? postId;
  final String text;
  final bool read;
  final String? imageUrl;
  final DateTime date;
}

class ChatThread {
  ChatThread({
    required this.otherId,
    required this.otherName,
    this.otherAvatar,
    this.postId,
    this.postTitle = '',
    required this.last,
    this.unread = 0,
  });
  final String otherId;
  final String otherName;
  final String? otherAvatar;
  final String? postId;
  final String postTitle;
  final ChatMessage last;
  final int unread;
}

class NewsItem {
  const NewsItem(this.tag, this.title, this.summary, this.date);
  final String tag;
  final String title;
  final String summary;
  final String date;
}

class DirItem {
  const DirItem(this.name, this.note, this.phone);
  final String name;
  final String note;
  final String phone;
}

enum SortMode { fresh, cheap, expensive }

class Filters {
  SortMode sort = SortMode.fresh;
  int? priceFrom;
  int? priceTo;
  bool verifiedOnly = false;
  bool get active =>
      sort != SortMode.fresh || priceFrom != null || priceTo != null || verifiedOnly;
}

class AppState extends ChangeNotifier {
  SupabaseClient get sb => Supabase.instance.client;

  String city = cities.first;
  Set<String> favorites = {};
  List<Post> posts = [];
  List<Post> myPosts = [];
  Map<String, double> ratings = {};
  Map<String, int> reviewCounts = {};
  Profile? profile;
  List<ChatThread> threads = [];
  bool loading = false;
  String? error;
  bool guest = false;
  ThemeMode themeMode = ThemeMode.dark;
  int accent = 0;
  String lang = appLang;
  List<Product> products = [];
  Verification? myVerification;
  Set<String> blockedIds = {}; // кого заблокировал я
  Set<String> blockedMe = {}; // кто заблокировал меня
  Map<String, int> myFavCounts = {};
  List<NewsPost> news = [];
  bool newsLoaded = false;
  List<SavedSearch> savedSearches = [];
  bool hasMore = false;
  bool loadingMore = false;
  RealtimeChannel? _inbox;
  Timer? _presence;
  String _device = '';

  User? get user => sb.auth.currentUser;
  String get userName {
    final p = profile?.name ?? '';
    if (p.isNotEmpty) return p;
    return (user?.userMetadata?['name'] as String?) ?? (user?.email ?? tr('Гость'));
  }

  bool get isAdmin => profile?.role == 'admin';

  int get unreadTotal => threads.fold(0, (a, t) => a + t.unread);

  // ---------- Настройки ----------

  Future<void> loadSettings() async {
    try {
      final p = await SharedPreferences.getInstance();
      final t = p.getString('theme');
      themeMode = t == 'light'
          ? ThemeMode.light
          : t == 'system'
              ? ThemeMode.system
              : ThemeMode.dark;
      accent = p.getInt('accent') ?? 0;
      final l = p.getString('lang');
      if (l != null && appLanguages.any((x) => x[0] == l)) {
        lang = l;
        appLang = l;
      }
      _device = p.getString('device') ?? '';
      if (_device.isEmpty) {
        final r = math.Random.secure();
        _device = List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
        await p.setString('device', _device);
      }
      final c = p.getString('city');
      if (c != null && cities.contains(c)) city = c;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setTheme(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('theme', m == ThemeMode.dark ? 'dark' : m == ThemeMode.system ? 'system' : 'light');
    } catch (_) {}
  }

  Future<void> setAccent(int i) async {
    accent = i;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('accent', i);
    } catch (_) {}
  }

  Future<void> setLang(String l) async {
    lang = l;
    appLang = l;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('lang', l);
    } catch (_) {}
    final u = user;
    if (u != null) {
      try {
        await sb.from('profiles').update({'lang': l}).eq('id', u.id);
      } catch (_) {}
    }
  }

  void toggleTheme(Brightness current) =>
      setTheme(current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);

  Future<void> setCity(String c) async {
    city = c;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('city', c);
    } catch (_) {}
  }

  void setGuest(bool v) {
    guest = v;
    notifyListeners();
  }

  // ---------- Загрузка ----------

  static const _postSelect =
      '*, profiles!posts_user_id_fkey(name, verified, avatar_url, created_at, last_seen)';

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      List<Map<String, dynamic>> rows;
      try {
        rows = await sb.from('posts').select(_postSelect).eq('status', 'active')
            .order('bumped_at', ascending: false).limit(300);
      } on PostgrestException {
        // база ещё без v4 — обычная сортировка по дате
        rows = await sb.from('posts').select(_postSelect).eq('status', 'active')
            .order('created_at', ascending: false).limit(300);
      }
      posts = rows.map<Post>((m) => Post.fromMap(m)).toList();
      hasMore = posts.length >= 300;
      // VIP — сверху ленты (порядок внутри групп сохраняется)
      posts = [...posts.where((p) => p.isVip), ...posts.where((p) => !p.isVip)];
      error = null;
    } catch (e) {
      error = 'Нет связи с сервером. Потяните вниз, чтобы обновить.';
    }
    loading = false;
    notifyListeners();
    loadRatings();
  }

  Future<void> loadRatings() async {
    try {
      final rows = await sb.from('reviews').select('seller_id, stars').not('deal_id', 'is', null).limit(2000);
      final sum = <String, int>{};
      final cnt = <String, int>{};
      for (final r in rows) {
        final id = r['seller_id'] as String;
        sum[id] = (sum[id] ?? 0) + (r['stars'] as num).toInt();
        cnt[id] = (cnt[id] ?? 0) + 1;
      }
      ratings = {for (final id in sum.keys) id: sum[id]! / cnt[id]!};
      reviewCounts = cnt;
      notifyListeners();
    } catch (_) {}
  }

  /// Вызывается при входе/выходе.
  Future<void> onAuthChanged() async {
    if (user == null) {
      profile = null;
      favorites = {};
      myPosts = [];
      threads = [];
      myVerification = null;
      blockedIds = {};
      blockedMe = {};
      myFavCounts = {};
      _presence?.cancel();
      _presence = null;
      if (_inbox != null) sb.removeChannel(_inbox!);
      _inbox = null;
      savedSearches = [];
      notifyListeners();
      return;
    }
    touchOnline();
    _presence ??= Timer.periodic(const Duration(seconds: 60), (t) {
      touchOnline();
      if (t.tick % 30 == 0) loadNews(); // новости — раз в полчаса
    });
    _listenInbox();
    loadSavedSearches();
    await Future.wait([loadProfile(), loadFavorites(), loadMyPosts(), loadThreads(), loadMyVerification(), loadBlocks()]);
    final pl = profile?.lang;
    if (pl != null && pl != lang) {
      try {
        await sb.from('profiles').update({'lang': lang}).eq('id', user!.id);
      } catch (_) {}
    }
  }

  Future<void> loadProfile() async {
    final u = user;
    if (u == null) return;
    try {
      final row = await sb.from('profiles').select().eq('id', u.id).maybeSingle();
      profile = row == null ? Profile(id: u.id, name: userName) : Profile.fromMap(row);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadFavorites() async {
    final u = user;
    if (u == null) {
      favorites = {};
      notifyListeners();
      return;
    }
    try {
      final rows = await sb.from('favorites').select('post_id').eq('user_id', u.id);
      favorites = rows.map<String>((m) => m['post_id'] as String).toSet();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadMyPosts() async {
    final u = user;
    if (u == null) return;
    try {
      final rows = await sb
          .from('posts')
          .select(_postSelect)
          .eq('user_id', u.id)
          .order('created_at', ascending: false);
      myPosts = rows.map<Post>((m) => Post.fromMap(m)).toList();
      notifyListeners();
      try {
        final f = await sb.rpc('my_post_favs') as List;
        myFavCounts = {for (final r in f) r['post_id'] as String: (r['favs'] as num).toInt()};
        notifyListeners();
      } catch (_) {}
    } catch (_) {}
  }

  List<Post> get favoritePosts {
    final all = {for (final p in [...myPosts, ...posts]) p.id: p};
    return favorites.where(all.containsKey).map((id) => all[id]!).toList();
  }

  // ---------- Профиль ----------

  Future<void> updateProfile({required String name, required String city, String? phone}) async {
    final u = user;
    if (u == null) throw Exception('Нужно войти');
    await sb.from('profiles').update({
      'name': name,
      'city': city,
      'phone': (phone == null || phone.isEmpty) ? null : phone,
    }).eq('id', u.id);
    await loadProfile();
    await load();
    await loadMyPosts();
  }

  Future<String> uploadImage(Uint8List bytes, String prefix) async {
    final u = user;
    if (u == null) throw Exception('Нужно войти');
    final path = '${u.id}/${prefix}_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await sb.storage.from(photoBucket).uploadBinary(path, bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
    return sb.storage.from(photoBucket).getPublicUrl(path);
  }

  String? _storagePath(String url) {
    final marker = '/$photoBucket/';
    final i = url.indexOf(marker);
    if (i < 0) return null;
    final path = Uri.decodeComponent(url.substring(i + marker.length));
    return user != null && path.startsWith('${user!.id}/') ? path : null;
  }

  /// Скачать своё фото из хранилища (для редактирования).
  Future<Uint8List> downloadPhoto(String url) async {
    final marker = '/$photoBucket/';
    final i = url.indexOf(marker);
    if (i < 0) throw Exception('url');
    return sb.storage.from(photoBucket).download(Uri.decodeComponent(url.substring(i + marker.length)));
  }

  Future<void> updateAvatar(Uint8List bytes) async {
    final u = user;
    if (u == null) throw Exception('Нужно войти');
    final url = await uploadImage(bytes, 'avatar');
    await sb.from('profiles').update({'avatar_url': url}).eq('id', u.id);
    await loadProfile();
  }

  Future<void> removeAvatar() async {
    final u = user;
    if (u == null) return;
    await sb.from('profiles').update({'avatar_url': null}).eq('id', u.id);
    await loadProfile();
  }

  Future<void> changePassword(String pass) async {
    await sb.auth.updateUser(UserAttributes(password: pass));
  }

  Future<void> signOut() async {
    await sb.auth.signOut();
    favorites = {};
    profile = null;
    myPosts = [];
    threads = [];
    guest = false;
    notifyListeners();
  }

  // ---------- Объявления ----------

  Future<void> savePost({
    String? id,
    required Section section,
    required String category,
    required String title,
    required String description,
    required String city,
    required String contact,
    required List<String> photos,
    int? priceEgp,
  }) async {
    final u = user;
    if (u == null) throw Exception('Войдите, чтобы разместить объявление');
    final data = {
      'section': section.name,
      'category': category,
      'title': title,
      'description': description,
      'city': city,
      'contact': contact,
      'price_egp': priceEgp,
      'photos': photos,
    };
    if (id == null) {
      await sb.from('posts').insert({...data, 'user_id': u.id});
    } else {
      await sb.from('posts').update(data).eq('id', id);
    }
    await Future.wait([load(), loadMyPosts()]);
  }

  Future<void> setPostStatus(String id, String status) async {
    await sb.from('posts').update({'status': status}).eq('id', id);
    await Future.wait([load(), loadMyPosts()]);
  }

  Future<void> deletePost(String id) async {
    final post = myPosts.where((p) => p.id == id).firstOrNull;
    await sb.from('posts').delete().eq('id', id);
    // фото удалённого объявления больше не нужны
    final paths = (post?.photos ?? []).map(_storagePath).whereType<String>().toList();
    if (paths.isNotEmpty) {
      try {
        await sb.storage.from(photoBucket).remove(paths);
      } catch (_) {}
    }
    await Future.wait([load(), loadMyPosts()]);
  }

  /// Возвращает false, если нужно войти.
  Future<bool> toggleFav(String id) async {
    final u = user;
    if (u == null) return false;
    final had = favorites.contains(id);
    had ? favorites.remove(id) : favorites.add(id);
    notifyListeners();
    try {
      if (had) {
        await sb.from('favorites').delete().eq('user_id', u.id).eq('post_id', id);
      } else {
        await sb.from('favorites').insert({'user_id': u.id, 'post_id': id});
      }
    } catch (_) {
      had ? favorites.add(id) : favorites.remove(id);
      notifyListeners();
    }
    return true;
  }

  /// Жалоба на объявление или пользователя. Возвращает 'ok', 'dup' или 'error'.
  Future<String> report({String? postId, String? userId, String reason = ''}) async {
    final u = user;
    if (u == null) return 'error';
    try {
      await sb.from('reports').insert({
        'post_id': postId,
        'target_user': userId,
        'user_id': u.id,
        'reason': reason,
      });
      return 'ok';
    } on PostgrestException catch (e) {
      return e.code == '23505' ? 'dup' : 'error';
    } catch (_) {
      return 'error';
    }
  }

  // ---------- Блокировки, онлайн, просмотры ----------

  Future<void> loadBlocks() async {
    final u = user;
    if (u == null) return;
    try {
      final rows = await sb.from('blocks').select('blocker, blocked');
      blockedIds = {for (final r in rows) if (r['blocker'] == u.id) r['blocked'] as String};
      blockedMe = {for (final r in rows) if (r['blocked'] == u.id) r['blocker'] as String};
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setBlocked(String otherId, bool block) async {
    final u = user;
    if (u == null) throw Exception('Нужно войти');
    if (block) {
      await sb.from('blocks').upsert({'blocker': u.id, 'blocked': otherId});
      blockedIds = {...blockedIds, otherId};
    } else {
      await sb.from('blocks').delete().eq('blocker', u.id).eq('blocked', otherId);
      blockedIds = {...blockedIds}..remove(otherId);
    }
    notifyListeners();
  }

  Future<List<Profile>> fetchProfiles(Iterable<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final rows = await sb.from('profiles').select().inFilter('id', ids.toList());
      return rows.map<Profile>((m) => Profile.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  // ---------- Мгновенные уведомления о сообщениях ----------

  void _listenInbox() {
    final u = user;
    if (u == null || _inbox != null) return;
    try {
      _inbox = sb
          .channel('inbox-${u.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'receiver_id', value: u.id),
            callback: (_) {
              loadThreads();
              _onMessage?.call();
            },
          )
          .subscribe();
    } catch (_) {}
  }

  /// Открытый чат подписывается сюда, чтобы обновиться сразу при новом сообщении.
  VoidCallback? _onMessage;
  void onIncomingMessage(VoidCallback? cb) => _onMessage = cb;

  // ---------- Курс, новости, подписки, подгрузка, поиск ----------

  Future<void> loadRates() async {
    try {
      final res = await sb.functions.invoke('rates', method: HttpMethod.get);
      final d = res.data;
      if (d is Map && d['rub'] is num) {
        rubPerEgp = (d['rub'] as num).toDouble();
        egpPerUsd = (d['egp_per_usd'] as num).toDouble();
        egpPerEur = (d['egp_per_eur'] as num).toDouble();
        ratesUpdated = DateTime.tryParse('${d['updated'] ?? ''}');
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> loadNews() async {
    try {
      final rows = await sb.from('news').select().order('created_at', ascending: false).limit(120);
      news = rows.map<NewsPost>((m) => NewsPost.fromMap(m)).toList();
    } catch (_) {}
    newsLoaded = true;
    notifyListeners();
  }

  Future<void> saveNews({int? id, required String tag, required String title, required String body, bool published = true}) async {
    final data = {'tag': tag, 'title': title, 'body': body, 'published': published};
    if (id == null) {
      await sb.from('news').insert(data);
    } else {
      await sb.from('news').update(data).eq('id', id);
    }
    await loadNews();
  }

  Future<void> deleteNews(int id) async {
    await sb.from('news').delete().eq('id', id);
    await loadNews();
  }

  Future<void> loadSavedSearches() async {
    if (user == null) return;
    try {
      final rows = await sb.from('saved_searches').select().order('id', ascending: false);
      savedSearches = rows.map<SavedSearch>((m) => SavedSearch.fromMap(m)).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> addSavedSearch(Section section, {String? category, String? city, String query = '', int? priceMax}) async {
    final u = user;
    if (u == null) throw Exception('Нужно войти');
    await sb.from('saved_searches').insert({
      'user_id': u.id,
      'section': section.name,
      'category': category,
      'city': city,
      'query': query.trim(),
      'price_max': priceMax,
    });
    await loadSavedSearches();
  }

  Future<void> deleteSavedSearch(int id) async {
    await sb.from('saved_searches').delete().eq('id', id);
    await loadSavedSearches();
  }

  Future<void> setNotifyTg(bool on) async {
    final u = user;
    if (u == null) return;
    await sb.from('profiles').update({'notify_tg': on}).eq('id', u.id);
    await loadProfile();
  }

  /// Следующая порция ленты.
  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    loadingMore = true;
    notifyListeners();
    try {
      final rows = await sb.from('posts').select(_postSelect).eq('status', 'active')
          .order('bumped_at', ascending: false).range(posts.length, posts.length + 299);
      final more = rows.map<Post>((m) => Post.fromMap(m)).toList();
      final have = posts.map((p) => p.id).toSet();
      posts = [...posts, ...more.where((p) => !have.contains(p.id))];
      hasMore = more.length >= 300;
    } catch (_) {}
    loadingMore = false;
    notifyListeners();
  }

  /// Поиск по всем объявлениям на сервере (если в ленте загружено не всё).
  Future<void> searchRemote(String q) async {
    final s = q.replaceAll(RegExp(r'[%,()*]'), ' ').trim();
    if (s.length < 2 || !hasMore) return;
    try {
      final rows = await sb.from('posts').select(_postSelect).eq('status', 'active')
          .or('title.ilike.%$s%,description.ilike.%$s%').order('bumped_at', ascending: false).limit(100);
      final found = rows.map<Post>((m) => Post.fromMap(m)).toList();
      final have = posts.map((p) => p.id).toSet();
      final add = found.where((p) => !have.contains(p.id)).toList();
      if (add.isNotEmpty) {
        posts = [...posts, ...add];
        notifyListeners();
      }
    } catch (_) {}
  }

  // ---------- Аккаунт и администрирование ----------

  /// Удалить свой аккаунт со всеми объявлениями, сообщениями и фото.
  Future<void> deleteAccount() async {
    final u = user;
    if (u == null) return;
    try {
      final files = await sb.storage.from(photoBucket).list(path: u.id);
      final paths = files.map((f) => '${u.id}/${f.name}').toList();
      if (paths.isNotEmpty) await sb.storage.from(photoBucket).remove(paths);
    } catch (_) {}
    await sb.rpc('delete_my_account');
    await signOut();
  }

  Future<void> adminBan(String userId, bool ban) async {
    await sb.rpc('admin_ban', params: {'p_user': userId, 'p_ban': ban});
    await load();
  }

  Future<Map<String, dynamic>> adminStats() async {
    final r = await sb.rpc('admin_stats');
    return Map<String, dynamic>.from(r as Map);
  }

  Future<void> touchOnline() async {
    if (user == null) return;
    try {
      await sb.rpc('touch_online');
    } catch (_) {}
  }

  /// Просмотр ('view') или обращение ('contact'): один раз в сутки от человека, свои не считаются.
  Future<void> registerEvent(String postId, String kind) async {
    try {
      await sb.rpc('register_event', params: {'p_post': postId, 'p_kind': kind, 'p_device': _device});
    } catch (_) {}
  }

  Future<Post?> fetchPost(String id) async {
    for (final p in [...posts, ...myPosts]) {
      if (p.id == id) return p;
    }
    try {
      final r = await sb.from('posts').select(_postSelect).eq('id', id).maybeSingle();
      return r == null ? null : Post.fromMap(r);
    } catch (_) {
      return null;
    }
  }

  List<Post> filter(Section s, String? category, String query, Filters f) {
    final q = query.trim().toLowerCase();
    final list = posts.where((p) {
      if (p.section != s) return false;
      if (blockedIds.contains(p.userId)) return false;
      if (city != cities.first && p.city != city) return false;
      if (category != null && p.category != category) return false;
      if (f.verifiedOnly && !p.verified) return false;
      final price = p.priceEgp;
      if (f.priceFrom != null && (price == null || price < f.priceFrom!)) return false;
      if (f.priceTo != null && (price == null || price > f.priceTo!)) return false;
      if (q.isNotEmpty &&
          !p.title.toLowerCase().contains(q) &&
          !p.description.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
    if (f.sort == SortMode.cheap) {
      list.sort((a, b) => (a.priceEgp ?? 1 << 40).compareTo(b.priceEgp ?? 1 << 40));
    } else if (f.sort == SortMode.expensive) {
      list.sort((a, b) => (b.priceEgp ?? -1).compareTo(a.priceEgp ?? -1));
    }
    return list;
  }

  // ---------- Продавцы и отзывы ----------

  Future<Profile?> fetchProfile(String id) async {
    try {
      final row = await sb.from('profiles').select().eq('id', id).maybeSingle();
      return row == null ? null : Profile.fromMap(row);
    } catch (_) {
      return null;
    }
  }

  Future<List<Post>> fetchSellerPosts(String id) async {
    try {
      final rows = await sb
          .from('posts')
          .select(_postSelect)
          .eq('user_id', id)
          .eq('status', 'active')
          .order('created_at', ascending: false);
      return rows.map<Post>((m) => Post.fromMap(m)).toList();
    } catch (_) {
      return posts.where((p) => p.userId == id).toList();
    }
  }

  /// Только честные отзывы — оставленные после подтверждённой сделки.
  Future<List<Review>> fetchReviews(String sellerId) async {
    try {
      final rows = await sb
          .from('reviews')
          .select('id, stars, text, created_at, post_title, reply, author:profiles!reviews_author_id_fkey(name, avatar_url)')
          .eq('seller_id', sellerId)
          .not('deal_id', 'is', null)
          .order('created_at', ascending: false);
      return rows.map<Review>((m) {
        final a = m['author'] is Map ? m['author'] as Map : const {};
        return Review(
          id: (m['id'] as num).toInt(),
          author: (a['name'] ?? 'Пользователь') as String,
          authorAvatar: a['avatar_url'] as String?,
          stars: (m['stars'] as num).toInt(),
          text: (m['text'] ?? '') as String,
          date: DateTime.tryParse((m['created_at'] ?? '') as String) ?? DateTime.now(),
          postTitle: (m['post_title'] ?? '') as String,
          reply: m['reply'] as String?,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Сделки между мной и другим человеком (в обе стороны), с отметкой «отзыв уже оставлен».
  Future<List<Deal>> fetchDealsWith(String otherId) async {
    final u = user;
    if (u == null) return [];
    try {
      final rows = await sb
          .from('deals')
          .select()
          .or('and(seller_id.eq.${u.id},buyer_id.eq.$otherId),and(seller_id.eq.$otherId,buyer_id.eq.${u.id})')
          .order('created_at', ascending: false);
      final ids = rows.map((m) => (m['id'] as num).toInt()).toList();
      var reviewed = <int>{};
      if (ids.isNotEmpty) {
        final rv = await sb.from('reviews').select('deal_id').eq('author_id', u.id).inFilter('deal_id', ids);
        reviewed = rv.map<int>((m) => (m['deal_id'] as num).toInt()).toSet();
      }
      return rows.map<Deal>((m) => Deal.fromMap(m, reviewed: reviewed.contains((m['id'] as num).toInt()))).toList();
    } catch (_) {
      return [];
    }
  }

  /// Продавец подтверждает, что сделка с покупателем состоялась.
  Future<void> confirmDeal(String buyerId, String? postId) async {
    final u = user;
    if (u == null) throw Exception('Нужно войти');
    await sb.from('deals').insert({'seller_id': u.id, 'buyer_id': buyerId, 'post_id': postId});
  }

  Future<void> addReview(Deal deal, int stars, String text, String postTitle) async {
    final u = user;
    if (u == null) throw Exception('Нужно войти');
    await sb.from('reviews').insert({
      'seller_id': deal.sellerId,
      'author_id': u.id,
      'deal_id': deal.id,
      'post_title': postTitle,
      'stars': stars,
      'text': text,
    });
    await loadRatings();
  }

  Future<void> replyReview(int reviewId, String text) async {
    await sb.from('reviews').update({'reply': text}).eq('id', reviewId);
  }

  Future<String> postTitleOf(String? postId) async {
    if (postId == null) return '';
    for (final p in [...posts, ...myPosts]) {
      if (p.id == postId) return p.title;
    }
    try {
      final r = await sb.from('posts').select('title').eq('id', postId).maybeSingle();
      return (r?['title'] ?? '') as String;
    } catch (_) {
      return '';
    }
  }

  // ---------- Модерация (администратор) ----------

  Future<List<Post>> fetchPending() async {
    final rows = await sb
        .from('posts')
        .select(_postSelect)
        .eq('status', 'pending')
        .order('created_at', ascending: true)
        .limit(200);
    return rows.map<Post>((m) => Post.fromMap(m)).toList();
  }

  /// Жалобы: id жалобы, причина, объявление.
  Future<List<Map<String, dynamic>>> fetchReports() async {
    final rows = await sb
        .from('reports')
        .select('id, reason, created_at, target_user, target:profiles!reports_target_user_fkey(id, name, avatar_url, created_at), post:posts(*, profiles!posts_user_id_fkey(name, verified, avatar_url, created_at))')
        .order('created_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> moderate(String postId, String status, {String? reason}) async {
    await sb.from('posts').update({'status': status, 'reject_reason': reason}).eq('id', postId);
    // письмо автору (если подключена почта)
    sb.functions.invoke('notify', body: {'kind': 'post', 'post_id': postId}).ignore();
    await load();
  }

  // ---------- Проверка профиля ----------

  Future<void> loadMyVerification() async {
    final u = user;
    if (u == null) return;
    try {
      final r = await sb.from('verifications').select().eq('user_id', u.id).order('id', ascending: false).limit(1).maybeSingle();
      myVerification = r == null ? null : Verification.fromMap(r);
      notifyListeners();
    } catch (_) {}
  }

  /// Код-ссылка для бота (готовится заранее, чтобы кнопка открывала Telegram без задержки).
  Future<String> prepareVerificationCode() async {
    final code = await sb.rpc('start_verification') as String;
    return code;
  }

  /// Код для бота и ссылка t.me на него.
  Future<String> verificationLink() async {
    final code = await sb.rpc('start_verification') as String;
    await loadMyVerification();
    final res = await sb.functions.invoke('tg-bot', method: HttpMethod.get, queryParameters: {'code': code});
    final data = res.data;
    if (data is Map && data['url'] is String) return data['url'] as String;
    throw Exception('bot');
  }

  /// Код из бота. Результат: ok, wrong, expired, locked, none, taken.
  Future<String> confirmVerification(String code) async {
    final r = await sb.rpc('confirm_verification', params: {'p_code': code.trim()}) as String;
    if (r == 'ok') await Future.wait([loadProfile(), loadMyVerification(), load()]);
    return r;
  }

  Future<List<Verification>> fetchVerifications() async {
    final rows = await sb
        .from('verifications')
        .select('*, user:profiles!verifications_user_id_fkey(name, city)')
        .order('id', ascending: false)
        .limit(100);
    return rows.map<Verification>((m) => Verification.fromMap(m)).toList();
  }

  Future<void> adminVerify(String userId, bool ok) async {
    await sb.rpc('admin_verify', params: {'p_user': userId, 'p_ok': ok, 'p_reason': ok ? null : 'Документ не подтверждён'});
    sb.functions.invoke('notify', body: {'kind': 'verify', 'user_id': userId}).ignore();
  }

  // ---------- Продвижение и оплата ----------

  Future<void> loadProducts() async {
    try {
      final rows = await sb.from('products').select().eq('active', true).order('price_egp');
      products = rows.map<Product>((m) => Product.fromMap(m)).toList();
      notifyListeners();
    } catch (_) {}
  }

  /// Ссылка на оплату Paymob. Бросает 'not_configured', если оплата ещё не подключена.
  Future<String> paymentLink(String postId, String product) async {
    try {
      final res = await sb.functions.invoke('payments', body: {'post_id': postId, 'product': product});
      final data = res.data;
      if (data is Map && data['url'] is String) return data['url'] as String;
    } on FunctionException catch (e) {
      final d = e.details;
      if (d is Map && d['error'] == 'payments_not_configured') throw Exception('not_configured');
      rethrow;
    }
    throw Exception('payment');
  }

  Future<void> adminPromote(String postId, String product) async {
    await sb.rpc('admin_promote', params: {'p_post': postId, 'p_product': product});
    await Future.wait([load(), loadMyPosts()]);
  }

  Future<void> deleteReport(int id) async {
    await sb.from('reports').delete().eq('id', id);
  }

  /// Сообщение об ошибке от сервера (наши проверки) — понятным текстом.
  static String serverMessage(Object e, String fallback) {
    if (e is PostgrestException && e.code == 'P0001') return e.message;
    return fallback;
  }

  // ---------- Сообщения ----------

  Future<void> loadThreads() async {
    final u = user;
    if (u == null) return;
    try {
      final rows = await sb
          .from('messages')
          .select()
          .or('sender_id.eq.${u.id},receiver_id.eq.${u.id}')
          .order('created_at', ascending: false)
          .limit(500);
      final msgs = rows.map<ChatMessage>((m) => ChatMessage.fromMap(m)).toList();
      final byKey = <String, List<ChatMessage>>{};
      for (final m in msgs) {
        final other = m.senderId == u.id ? m.receiverId : m.senderId;
        byKey.putIfAbsent('$other|${m.postId ?? ''}', () => []).add(m);
      }
      final otherIds = byKey.keys.map((k) => k.split('|').first).toSet().toList();
      final postIds = msgs.map((m) => m.postId).whereType<String>().toSet().toList();
      final names = <String, Map>{};
      if (otherIds.isNotEmpty) {
        final ps = await sb.from('profiles').select('id, name, avatar_url').inFilter('id', otherIds);
        for (final p in ps) {
          names[p['id'] as String] = p;
        }
      }
      final titles = <String, String>{for (final p in [...posts, ...myPosts]) p.id: p.title};
      final missing = postIds.where((id) => !titles.containsKey(id)).toList();
      if (missing.isNotEmpty) {
        final ps = await sb.from('posts').select('id, title').inFilter('id', missing);
        for (final p in ps) {
          titles[p['id'] as String] = (p['title'] ?? '') as String;
        }
      }
      threads = byKey.entries.map((e) {
        final parts = e.key.split('|');
        final other = parts.first;
        final postId = parts[1].isEmpty ? null : parts[1];
        final prof = names[other] ?? const {};
        return ChatThread(
          otherId: other,
          otherName: (prof['name'] ?? 'Пользователь') as String,
          otherAvatar: prof['avatar_url'] as String?,
          postId: postId,
          postTitle: postId == null ? '' : (titles[postId] ?? ''),
          last: e.value.first,
          unread: e.value.where((m) => m.receiverId == u.id && !m.read).length,
        );
      }).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<List<ChatMessage>> fetchMessages(String otherId, String? postId) async {
    final u = user;
    if (u == null) return [];
    final rows = await sb
        .from('messages')
        .select()
        .or('and(sender_id.eq.${u.id},receiver_id.eq.$otherId),and(sender_id.eq.$otherId,receiver_id.eq.${u.id})')
        .order('created_at', ascending: true)
        .limit(500);
    final list = rows
        .map<ChatMessage>((m) => ChatMessage.fromMap(m))
        .where((m) => m.postId == postId)
        .toList();
    if (list.any((m) => m.receiverId == u.id && !m.read)) {
      try {
        var q = sb
            .from('messages')
            .update({'read': true})
            .eq('receiver_id', u.id)
            .eq('sender_id', otherId)
            .eq('read', false);
        if (postId != null) q = q.eq('post_id', postId);
        await q;
        loadThreads();
      } catch (_) {}
    }
    return list;
  }

  Future<void> sendMessage(String otherId, String? postId, String text, {String? imageUrl}) async {
    final u = user;
    if (u == null) throw Exception('Нужно войти');
    await sb.from('messages').insert({
      'sender_id': u.id,
      'receiver_id': otherId,
      'post_id': postId,
      'text': text,
      if (imageUrl != null) 'image_url': imageUrl,
    });
    loadThreads();
  }
}

// ---------- Новости и справочник (пока статичные) ----------

const demoNews = <NewsItem>[
  NewsItem('Визы', 'Как продлить туристическую визу',
      'Куда идти, какие документы взять и сколько это стоит в разных городах.', 'Сегодня'),
  NewsItem('Курс', 'Курс фунта на этой неделе',
      'Короткая сводка по курсу EGP к рублю, доллару и евро.', 'Вчера'),
  NewsItem('События', 'Русскоязычная встреча в Хургаде',
      'Знакомства, обмен опытом, детская зона. В субботу в 18:00.', '2 дня назад'),
  NewsItem('Важно', 'Осторожно: мошенники с арендой',
      'Не переводите предоплату до просмотра квартиры. Как проверить хозяина.', '3 дня назад'),
];

const demoDirectory = <DirItem>[
  DirItem('Скорая помощь', 'Вся страна, бесплатно', '123'),
  DirItem('Полиция', 'Вся страна', '122'),
  DirItem('Туристическая полиция', 'Вся страна', '126'),
  DirItem('Пожарная служба', 'Вся страна', '180'),
  DirItem('Аварийная газовая служба', 'Утечка газа', '129'),
  DirItem('Аварийная служба электросетей', 'Нет света, обрыв провода', '121'),
];

/// «5 мин назад», «3 ч назад», дальше — дата.
String agoText(DateTime d) {
  final diff = DateTime.now().difference(d.toLocal());
  if (diff.inMinutes < 60) return tr('{n} мин назад', {'n': diff.inMinutes.clamp(1, 59)});
  if (diff.inHours < 24) return tr('{n} ч назад', {'n': diff.inHours});
  return dateText(d);
}

// ---------- Онлайн-статус ----------

bool isOnline(DateTime? d) => d != null && DateTime.now().difference(d.toLocal()).inMinutes < 3;

/// «в сети», «был(а) 5 мин назад», «был(а) сегодня в 14:30», «был(а) вчера в 09:10», «был(а) 12 нояб.»
String onlineText(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  final now = DateTime.now();
  final diff = now.difference(l);
  if (diff.inMinutes < 3) return tr('в сети');
  if (diff.inMinutes < 60) return tr('был(а) {n} мин назад', {'n': diff.inMinutes});
  final hm = '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(l.year, l.month, l.day);
  final days = today.difference(day).inDays;
  if (days == 0) return tr('был(а) сегодня в {t}', {'t': hm});
  if (days == 1) return tr('был(а) вчера в {t}', {'t': hm});
  return tr('был(а) {d}', {'d': dateText(l)});
}
