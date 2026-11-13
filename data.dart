import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  'Хургада',
  'Шарм-эль-Шейх',
  'Александрия',
  'Эль-Гуна',
];

const categories = {
  Section.ads: [
    'Аренда жилья',
    'Продажа жилья',
    'Электроника',
    'Мебель',
    'Авто',
    'Одежда',
    'Отдам даром',
  ],
  Section.services: [
    'Ремонт',
    'Визы и документы',
    'Репетиторы',
    'Красота',
    'Перевозки',
    'Переводчики',
    'Фото и видео',
  ],
  Section.jobs: ['Вакансии', 'Резюме', 'Удалёнка', 'Туризм'],
};

/// Примерный курс. Позже будет загружаться с сервера.
const rubPerEgp = 1.65;
const egpPerUsd = 49.0;
const egpPerEur = 53.0;

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
  if (egp == null) return 'Договорная';
  if (egp == 0) return 'Бесплатно';
  return '${fmt(egp)} EGP';
}

String priceRub(int? egp) =>
    (egp == null || egp == 0) ? '' : '≈ ${fmt(egp * rubPerEgp)} ₽';

const _months = [
  'янв.', 'февр.', 'марта', 'апр.', 'мая', 'июня',
  'июля', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'
];

String dateText(DateTime d) {
  final l = d.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(l.year, l.month, l.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Сегодня';
  if (diff == 1) return 'Вчера';
  final y = l.year == now.year ? '' : ' ${l.year}';
  return '${l.day} ${_months[l.month - 1]}$y';
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
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Profile.fromMap(Map m) => Profile(
        id: (m['id'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        city: (m['city'] ?? 'Каир') as String,
        phone: m['phone'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        verified: (m['verified'] ?? false) as bool,
        createdAt: DateTime.tryParse((m['created_at'] ?? '') as String),
      );

  final String id;
  final String name;
  final String city;
  final String? phone;
  final String? avatarUrl;
  final bool verified;
  final DateTime createdAt;
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
    DateTime? date,
  }) : date = date ?? DateTime.now();

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
  final DateTime date;
}

class Review {
  Review(this.author, this.stars, this.text, this.date);
  final String author;
  final int stars;
  final String text;
  final DateTime date;
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
  });

  factory ChatMessage.fromMap(Map m) => ChatMessage(
        id: (m['id'] as num).toInt(),
        senderId: m['sender_id'] as String,
        receiverId: m['receiver_id'] as String,
        postId: m['post_id'] as String?,
        text: (m['text'] ?? '') as String,
        read: (m['read'] ?? false) as bool,
        date: DateTime.tryParse((m['created_at'] ?? '') as String) ?? DateTime.now(),
      );

  final int id;
  final String senderId;
  final String receiverId;
  final String? postId;
  final String text;
  final bool read;
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
  ThemeMode themeMode = ThemeMode.light;

  User? get user => sb.auth.currentUser;
  String get userName {
    final p = profile?.name ?? '';
    if (p.isNotEmpty) return p;
    return (user?.userMetadata?['name'] as String?) ?? (user?.email ?? 'Гость');
  }

  int get unreadTotal => threads.fold(0, (a, t) => a + t.unread);

  // ---------- Настройки ----------

  Future<void> loadSettings() async {
    try {
      final p = await SharedPreferences.getInstance();
      final t = p.getString('theme');
      themeMode = t == 'dark'
          ? ThemeMode.dark
          : t == 'system'
              ? ThemeMode.system
              : ThemeMode.light;
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
      '*, profiles!posts_user_id_fkey(name, verified, avatar_url, created_at)';

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      final rows = await sb
          .from('posts')
          .select(_postSelect)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(300);
      posts = rows.map<Post>((m) => Post.fromMap(m)).toList();
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
      final rows = await sb.from('reviews').select('seller_id, stars').limit(2000);
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
      notifyListeners();
      return;
    }
    await Future.wait([loadProfile(), loadFavorites(), loadMyPosts(), loadThreads()]);
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
    await sb.from('posts').delete().eq('id', id);
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

  Future<void> report(String postId) async {
    final u = user;
    if (u == null) return;
    try {
      await sb.from('reports').insert({'post_id': postId, 'user_id': u.id});
    } catch (_) {}
  }

  List<Post> filter(Section s, String? category, String query, Filters f) {
    final q = query.trim().toLowerCase();
    final list = posts.where((p) {
      if (p.section != s) return false;
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

  Future<List<Review>> fetchReviews(String sellerId) async {
    try {
      final rows = await sb
          .from('reviews')
          .select('stars, text, created_at, author:profiles!reviews_author_id_fkey(name)')
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);
      return rows.map<Review>((m) {
        final a = m['author'] is Map ? m['author'] as Map : const {};
        return Review(
          (a['name'] ?? 'Пользователь') as String,
          (m['stars'] as num).toInt(),
          (m['text'] ?? '') as String,
          DateTime.tryParse((m['created_at'] ?? '') as String) ?? DateTime.now(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addReview(String sellerId, int stars, String text) async {
    final u = user;
    if (u == null) throw Exception('Нужно войти');
    await sb.from('reviews').insert({
      'seller_id': sellerId,
      'author_id': u.id,
      'stars': stars,
      'text': text,
    });
    await loadRatings();
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

  Future<void> sendMessage(String otherId, String? postId, String text) async {
    final u = user;
    if (u == null) throw Exception('Нужно войти');
    await sb.from('messages').insert({
      'sender_id': u.id,
      'receiver_id': otherId,
      'post_id': postId,
      'text': text,
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
];
