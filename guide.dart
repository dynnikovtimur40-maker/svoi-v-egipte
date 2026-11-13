// Путеводитель для туриста: города, что посмотреть, советы.
// Тексты на русском и английском; на других языках показывается английский вариант.
import 'i18n.dart';

class GuidePart {
  const GuidePart({required this.intro, required this.sights, required this.tips, required this.road});
  final String intro;
  final List<String> sights;
  final List<String> tips;
  final String road;
}

class GuideCity {
  const GuideCity(this.name, this.icon, this.hue, this.ru, this.en);
  final String name; // как в списке городов (ключ перевода)
  final String icon;
  final int hue;
  final GuidePart ru;
  final GuidePart en;
  GuidePart get local => appLang == 'ru' ? ru : en;
}

/// Общие советы туристу (заголовок, текст).
List<List<String>> get guideBasics => appLang == 'ru' ? _basicsRu : _basicsEn;

const _basicsRu = [
  ['Виза', 'Для россиян, украинцев и большинства европейцев — виза по прилёту в аэропорту или электронная e-Visa заранее. Для отдыха только в Шарм-эль-Шейхе, Дахабе и Табе до 15 дней достаточно бесплатного штампа «Синай». Актуальную стоимость уточняйте перед поездкой.'],
  ['Деньги', 'Валюта — египетский фунт (EGP). Карты принимают в отелях и торговых центрах, но наличные нужны на рынках, в такси и кафе. Меняйте деньги в банках и официальных обменниках, не на улице.'],
  ['Чаевые', 'Бакшиш — часть местной культуры: 10–20 EGP носильщику и уборщице, 10% в кафе, если сервис не включён в счёт.'],
  ['Такси', 'Удобнее всего Uber и Careem — цена известна заранее. В обычном такси договаривайтесь о цене до поездки.'],
  ['Одежда', 'В курортах свободно, в городах и мечетях — закрытые плечи и колени. Женщинам в мечети нужен платок.'],
  ['Вода и еда', 'Пейте только бутилированную воду, не берите лёд в уличных кафе первые дни. Фрукты мойте бутилированной водой.'],
  ['Солнце', 'Солнце очень активное даже зимой: крем SPF 50, головной убор, вода с собой. Летом днём лучше не гулять с 12 до 16.'],
  ['Связь', 'SIM-карты Vodafone, Orange, Etisalat (e&) и WE продаются в аэропорту и салонах по паспорту.'],
  ['Экстренные номера', 'Полиция — 122, скорая — 123, туристическая полиция — 126, пожарные — 180.'],
];

const _basicsEn = [
  ['Visa', 'Most visitors get a visa on arrival at the airport or an e-Visa in advance. If you stay only in Sharm El Sheikh, Dahab or Taba for up to 15 days, the free “Sinai only” stamp is enough. Check the current fee before you travel.'],
  ['Money', 'The currency is the Egyptian pound (EGP). Cards work in hotels and malls, but you need cash for markets, taxis and cafés. Exchange money in banks and official exchange offices, not on the street.'],
  ['Tipping', 'Baksheesh is part of local culture: 10–20 EGP for porters and housekeeping, 10% in cafés if service is not included.'],
  ['Taxi', 'Uber and Careem are the easiest — you know the price in advance. In a regular taxi, agree on the fare before the ride.'],
  ['Clothing', 'Resorts are relaxed; in cities and mosques cover shoulders and knees. Women need a headscarf in mosques.'],
  ['Water and food', 'Drink only bottled water and avoid ice in street cafés for the first days. Wash fruit with bottled water.'],
  ['Sun', 'The sun is strong even in winter: SPF 50, a hat and water. In summer avoid walking between 12:00 and 16:00.'],
  ['Mobile', 'SIM cards from Vodafone, Orange, Etisalat (e&) and WE are sold at the airport and in shops with your passport.'],
  ['Emergency', 'Police — 122, ambulance — 123, tourist police — 126, fire — 180.'],
];

const guideCities = <GuideCity>[
  GuideCity('Каир', 'pyramid', 0xFFF59E0B,
    GuidePart(
      intro: 'Столица и крупнейший город арабского мира: музеи, старые кварталы, базары и Нил. Минимум 2–3 дня.',
      sights: [
        'Пирамиды Гизы и Сфинкс — лучше приехать к открытию',
        'Большой Египетский музей (GEM) у пирамид — сокровища Тутанхамона',
        'Египетский музей на площади Тахрир',
        'Исламский Каир: улица Аль-Муизз, мечеть Аль-Азхар',
        'Базар Хан-эль-Халили — сувениры и кофе в «Эль-Фишауи»',
        'Коптский Каир: Висячая церковь',
        'Цитадель Салах ад-Дина и мечеть Мухаммеда Али',
        'Прогулка на фелуке по Нилу на закате',
      ],
      tips: [
        'Пробки огромные — закладывайте время, ездите на метро или Uber',
        'У пирамид навязчивые «гиды» и верблюды — договаривайтесь о цене заранее',
        'Билеты в музеи удобно покупать онлайн',
      ],
      road: 'Международный аэропорт Каира. Из курортов — самолёт (около часа) или автобус Go Bus / Blue Bus.',
    ),
    GuidePart(
      intro: 'The capital and the largest city of the Arab world: museums, old quarters, bazaars and the Nile. Plan at least 2–3 days.',
      sights: [
        'Giza Pyramids and the Sphinx — come at opening time',
        'Grand Egyptian Museum (GEM) near the pyramids — Tutankhamun treasures',
        'Egyptian Museum on Tahrir Square',
        'Islamic Cairo: Al-Muizz Street, Al-Azhar Mosque',
        'Khan el-Khalili bazaar — souvenirs and coffee at El Fishawy',
        'Coptic Cairo: the Hanging Church',
        'Saladin Citadel and the Muhammad Ali Mosque',
        'Felucca ride on the Nile at sunset',
      ],
      tips: [
        'Traffic is heavy — allow extra time, use the metro or Uber',
        'At the pyramids touts and camel owners are pushy — agree on prices first',
        'Museum tickets are easiest to buy online',
      ],
      road: 'Cairo International Airport. From resorts — a flight (about an hour) or Go Bus / Blue Bus coaches.',
    )),
  GuideCity('Хургада', 'sun', 0xFF14B8A6,
    GuidePart(
      intro: 'Главный курорт Красного моря: пляжи, коралловые рифы, дайвинг и большое русскоязычное сообщество.',
      sights: [
        'Острова Гифтун и Махмея — белый песок и снорклинг',
        'Набережная Марина и Старый город (Эль-Дахар)',
        'Сафари на квадроциклах и ужин у бедуинов',
        'Подводная лодка или лодка со стеклянным дном',
        'Аквапарки и Grand Aquarium',
        'Однодневная поездка в Луксор',
      ],
      tips: [
        'Экскурсии дешевле у проверенных местных агентств, чем у отеля',
        'Не трогайте кораллы и рыб, используйте коралло-безопасный крем',
        'Зимой вечером прохладно и ветрено — возьмите кофту',
      ],
      road: 'Международный аэропорт Хургады, прямые рейсы из многих стран. До Каира — 5–6 часов на автобусе.',
    ),
    GuidePart(
      intro: 'The main Red Sea resort: beaches, coral reefs, diving and a large expat community.',
      sights: [
        'Giftun and Mahmya islands — white sand and snorkelling',
        'The Marina promenade and the old town (El Dahar)',
        'Quad bike safari and dinner with Bedouins',
        'Submarine or glass-bottom boat trip',
        'Water parks and the Grand Aquarium',
        'Day trip to Luxor',
      ],
      tips: [
        'Trusted local agencies are cheaper than hotel excursions',
        'Do not touch corals or fish, use reef-safe sunscreen',
        'Winter evenings are cool and windy — bring a sweater',
      ],
      road: 'Hurghada International Airport with direct flights from many countries. Cairo is 5–6 hours by bus.',
    )),
  GuideCity('Эль-Гуна', 'home', 0xFF3B82F6,
    GuidePart(
      intro: 'Город-курорт на лагунах в 25 км от Хургады: каналы, яхты, кайтсёрфинг, тихо и чисто.',
      sights: ['Марина Абу-Тиг — рестораны и яхты', 'Кайт-станции на Мангровом пляже', 'Прогулка по лагунам на лодке', 'Пляж Зейтуна'],
      tips: ['Внутри города удобно ездить на тук-туке или городском автобусе', 'Цены выше, чем в Хургаде'],
      road: '30 минут на такси из аэропорта Хургады.',
    ),
    GuidePart(
      intro: 'A lagoon resort town 25 km from Hurghada: canals, yachts, kitesurfing, quiet and clean.',
      sights: ['Abu Tig Marina — restaurants and yachts', 'Kite stations at Mangroovy Beach', 'Boat ride through the lagoons', 'Zeytuna Beach'],
      tips: ['Tuk-tuks and the town bus are handy inside El Gouna', 'Prices are higher than in Hurghada'],
      road: '30 minutes by taxi from Hurghada airport.',
    )),
  GuideCity('Шарм-эль-Шейх', 'star', 0xFF6366F1,
    GuidePart(
      intro: 'Курорт на Синае с лучшими рифами Египта, горами и пустыней.',
      sights: [
        'Национальный парк Рас-Мохаммед',
        'Остров Тиран — снорклинг и дайвинг',
        'Наама-Бей и площадь Сохо вечером',
        'Старый рынок и мечеть Аль-Мустафа',
        'Гора Моисея и монастырь Святой Екатерины (ночной подъём)',
      ],
      tips: ['На рифы заходите только по понтонам', 'Для отдыха только на Синае до 15 дней достаточно бесплатного штампа'],
      road: 'Международный аэропорт Шарм-эль-Шейха. Из Каира — около 1 часа самолётом.',
    ),
    GuidePart(
      intro: 'A Sinai resort with Egypt’s best reefs, mountains and desert.',
      sights: [
        'Ras Mohammed National Park',
        'Tiran Island — snorkelling and diving',
        'Naama Bay and SOHO Square in the evening',
        'Old Market and Al Mustafa Mosque',
        'Mount Sinai and St Catherine’s Monastery (night climb)',
      ],
      tips: ['Enter the reefs only from pontoons', 'For a stay only in South Sinai up to 15 days the free stamp is enough'],
      road: 'Sharm El Sheikh International Airport. About 1 hour by plane from Cairo.',
    )),
  GuideCity('Дахаб', 'heart', 0xFF22C55E,
    GuidePart(
      intro: 'Расслабленный городок на Синае для дайверов, кайтеров и любителей спокойной жизни.',
      sights: ['Голубая дыра и Каньон', 'Лагуна — кайт и виндсёрфинг', 'Набережная с кафе прямо у воды', 'Цветной каньон', 'Национальный парк Рас-Абу-Галум'],
      tips: ['Голубая дыра опасна для глубоких погружений без подготовки', 'Многие кафе принимают только наличные'],
      road: '1–1,5 часа на такси или автобусе от Шарм-эль-Шейха.',
    ),
    GuidePart(
      intro: 'A laid-back Sinai town for divers, kiters and anyone who loves a slow life.',
      sights: ['The Blue Hole and the Canyon', 'The Lagoon — kite and windsurfing', 'Seafront cafés right by the water', 'Coloured Canyon', 'Ras Abu Galum protected area'],
      tips: ['The Blue Hole is dangerous for deep dives without training', 'Many cafés accept cash only'],
      road: '1–1.5 hours by taxi or bus from Sharm El Sheikh.',
    )),
  GuideCity('Марса-Алам', 'search', 0xFF14B8A6,
    GuidePart(
      intro: 'Дикий юг Красного моря: дюгони, черепахи, дельфины и почти пустые пляжи.',
      sights: ['Бухта Абу-Дабаб — черепахи и дюгони', 'Риф Самадай — дом дельфинов', 'Национальный парк Вади-эль-Гимал', 'Порт Галиб'],
      tips: ['Отели далеко друг от друга — выбирайте отель с хорошим домашним рифом', 'Сеть телефона местами слабая'],
      road: 'Аэропорт Марса-Алам или 3–4 часа на машине от Хургады.',
    ),
    GuidePart(
      intro: 'The wild south of the Red Sea: dugongs, turtles, dolphins and almost empty beaches.',
      sights: ['Abu Dabbab Bay — turtles and dugongs', 'Samadai Reef — the dolphin house', 'Wadi El Gemal National Park', 'Port Ghalib'],
      tips: ['Hotels are far apart — choose one with a good house reef', 'Mobile signal can be weak'],
      road: 'Marsa Alam airport or 3–4 hours by car from Hurghada.',
    )),
  GuideCity('Луксор', 'pyramid', 0xFFA855F7,
    GuidePart(
      intro: 'Крупнейший музей под открытым небом: храмы и гробницы фараонов на двух берегах Нила.',
      sights: [
        'Карнакский храм',
        'Луксорский храм — красив вечером с подсветкой',
        'Долина царей — гробница Тутанхамона',
        'Храм царицы Хатшепсут',
        'Колоссы Мемнона',
        'Полёт на воздушном шаре на рассвете',
      ],
      tips: ['Летом очень жарко — смотрите храмы рано утром', 'Фото внутри гробниц часто по отдельному билету'],
      road: 'Аэропорт Луксора, поезд из Каира (в том числе ночной), 4 часа на машине из Хургады.',
    ),
    GuidePart(
      intro: 'The world’s largest open-air museum: pharaohs’ temples and tombs on both banks of the Nile.',
      sights: [
        'Karnak Temple',
        'Luxor Temple — beautiful when lit at night',
        'Valley of the Kings — Tutankhamun’s tomb',
        'Temple of Queen Hatshepsut',
        'Colossi of Memnon',
        'Hot-air balloon flight at sunrise',
      ],
      tips: ['Summers are very hot — visit temples early in the morning', 'Photos inside tombs often need a separate ticket'],
      road: 'Luxor airport, train from Cairo (including the sleeper), 4 hours by car from Hurghada.',
    )),
  GuideCity('Асуан', 'globe', 0xFFF43F5E,
    GuidePart(
      intro: 'Самый спокойный и красивый город на Ниле: нубийские деревни, гранитные острова, фелуки.',
      sights: ['Храмы Абу-Симбел (рано утром)', 'Храм Филе на острове', 'Нубийская деревня Гарб-Сохейль', 'Ботанический сад на острове Китченер', 'Асуанская плотина'],
      tips: ['Отсюда начинаются круизы по Нилу до Луксора', 'До Абу-Симбела 3 часа пути — выезд ночью'],
      road: 'Аэропорт Асуана, поезд из Каира и Луксора.',
    ),
    GuidePart(
      intro: 'The calmest and most beautiful city on the Nile: Nubian villages, granite islands, feluccas.',
      sights: ['Abu Simbel temples (early morning)', 'Philae Temple on its island', 'Nubian village of Gharb Soheil', 'Botanical garden on Kitchener Island', 'Aswan Dam'],
      tips: ['Nile cruises to Luxor start here', 'Abu Simbel is 3 hours away — departure at night'],
      road: 'Aswan airport, trains from Cairo and Luxor.',
    )),
  GuideCity('Александрия', 'book', 0xFF3B82F6,
    GuidePart(
      intro: 'Средиземноморская «жемчужина» с греческой историей, набережной Корниш и морепродуктами.',
      sights: ['Библиотека Александрина', 'Цитадель Кайт-бей на месте Фаросского маяка', 'Катакомбы Ком-эль-Шукафа', 'Дворец и сады Монтаза', 'Набережная Корниш'],
      tips: ['Летом много отдыхающих египтян — бронируйте заранее', 'Попробуйте рыбу в ресторанах у порта'],
      road: '2,5–3 часа на поезде или автобусе из Каира.',
    ),
    GuidePart(
      intro: 'The Mediterranean pearl with Greek history, the Corniche promenade and seafood.',
      sights: ['Bibliotheca Alexandrina', 'Qaitbay Citadel on the site of the Pharos lighthouse', 'Catacombs of Kom El Shoqafa', 'Montaza Palace and gardens', 'The Corniche'],
      tips: ['Summer is busy with Egyptian holidaymakers — book ahead', 'Try fish in the restaurants by the port'],
      road: '2.5–3 hours by train or bus from Cairo.',
    )),
];
