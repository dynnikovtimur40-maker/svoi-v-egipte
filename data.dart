import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum Section { ads, services, jobs }

const sectionNames = {
  Section.ads: 'Объявления',
  Section.services: 'Услуги',
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
    'Репетиторы',
    'Красота',
    'Перевозки',
    'Визы и документы',
    'Переводчики',
    'Фото и видео',
  ],
  Section.jobs: ['Вакансии', 'Резюме', 'Удалёнка', 'Туризм'],
};

/// Примерный курс (демо). Позже будет загружаться с сервера.
const rubPerEgp = 1.65;
const egpPerUsd = 49.0;
const egpPerEur = 53.0;

String fmt(num n) {
  final s = n.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

String priceText(int? egp) {
  if (egp == null) return 'Цена договорная';
  if (egp == 0) return 'Бесплатно';
  return '${fmt(egp)} EGP  ·  ≈ ${fmt(egp * rubPerEgp)} ₽';
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
    this.verified = false,
    this.rating,
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
      priceEgp: m['price_egp'] as int?,
      author: (prof['name'] ?? 'Пользователь') as String,
      verified: (prof['verified'] ?? false) as bool,
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
  final bool verified;
  final double? rating;
  final DateTime date;
}

class NewsItem {
  const NewsItem(this.tag, this.title, this.summary, this.date);
  final String tag;
  final String title;
  final String summary;
  final String date;
}

class DirItem {
  const DirItem(this.category, this.name, this.city, this.phone, this.note);
  final String category;
  final String name;
  final String city;
  final String phone;
  final String note;
}

class AppState extends ChangeNotifier {
  SupabaseClient get sb => Supabase.instance.client;

  String city = cities.first;
  Set<String> favorites = {};
  List<Post> posts = [];
  bool loading = false;
  String? error;
  bool guest = false;

  User? get user => sb.auth.currentUser;
  String get userName =>
      (user?.userMetadata?['name'] as String?) ?? (user?.email ?? 'Гость');

  void setCity(String c) {
    city = c;
    notifyListeners();
  }

  void setGuest(bool v) {
    guest = v;
    notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      final rows = await sb
          .from('posts')
          .select('*, profiles(name, verified)')
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
  }

  Future<void> loadFavorites() async {
    final u = user;
    if (u == null) {
      favorites = {};
      notifyListeners();
      return;
    }
    try {
      final rows =
          await sb.from('favorites').select('post_id').eq('user_id', u.id);
      favorites = rows.map<String>((m) => m['post_id'] as String).toSet();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> addPost({
    required Section section,
    required String category,
    required String title,
    required String description,
    required String city,
    required String contact,
    int? priceEgp,
  }) async {
    final u = user;
    if (u == null) throw Exception('Войдите, чтобы разместить объявление');
    await sb.from('posts').insert({
      'user_id': u.id,
      'section': section.name,
      'category': category,
      'title': title,
      'description': description,
      'city': city,
      'contact': contact,
      'price_egp': priceEgp,
    });
    await load();
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

  Future<void> signOut() async {
    await sb.auth.signOut();
    favorites = {};
    guest = false;
    notifyListeners();
  }

  List<Post> filter(Section s, String? category, String query) {
    final q = query.trim().toLowerCase();
    return posts.where((p) {
      if (p.section != s) return false;
      if (city != cities.first && p.city != city) return false;
      if (category != null && p.category != category) return false;
      if (q.isNotEmpty &&
          !p.title.toLowerCase().contains(q) &&
          !p.description.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }
}

// ---------- Демо-данные (заменятся на реальные из базы) ----------

const demoNews = <NewsItem>[
  NewsItem('Визы', 'Как продлить туристическую визу: порядок действий',
      'Куда идти, какие документы взять и сколько это стоит в разных городах.', 'Сегодня'),
  NewsItem('Курс', 'Курс фунта: что происходит с EGP',
      'Короткая сводка по курсу к рублю, доллару и евро.', 'Вчера'),
  NewsItem('События', 'Русскоязычная встреча в Хургаде в субботу',
      'Знакомства, обмен опытом, детская зона.', '2 дня назад'),
  NewsItem('Важно', 'Осторожно: мошенники с арендой жилья',
      'Не переводите предоплату до просмотра квартиры. Как проверить хозяина.', '3 дня назад'),
];

const demoDirectory = <DirItem>[
  DirItem('Экстренные номера', 'Скорая помощь', 'Вся страна', '123', 'Бесплатно'),
  DirItem('Экстренные номера', 'Полиция', 'Вся страна', '122', 'Бесплатно'),
  DirItem('Экстренные номера', 'Туристическая полиция', 'Вся страна', '126', ''),
  DirItem('Врачи', 'Русскоговорящий педиатр (демо)', 'Хургада', '+20 100 000 0003',
      'Приём по записи'),
  DirItem('Врачи', 'Стоматология (демо)', 'Каир', '+20 100 000 0004', 'Говорят по-русски'),
  DirItem('Школы', 'Русская школа (демо)', 'Каир', '+20 100 000 0005', 'Онлайн и очно'),
  DirItem('Юристы', 'Юрист по недвижимости (демо)', 'Хургада', '+20 100 000 0006',
      'Проверка договоров'),
];
