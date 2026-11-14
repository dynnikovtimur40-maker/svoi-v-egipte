// Подключение к серверу Supabase.
// Публичный ключ (publishable) можно хранить в приложении — доступ ограничен правилами базы.
const supabaseUrl = 'https://pjjeypdxwnbtyqabhroi.supabase.co';
const supabaseKey = 'sb_publishable_HxEmexB9o3LDXsbNQ3xTCQ_t46rqmne';

// Адрес веб-версии: сюда ведут ссылки из писем (подтверждение почты, сброс пароля).
const siteUrl = 'https://dynnikovtimur40-maker.github.io/svoi-v-egipte/';

// Языки приложения: код, название (на самом языке).
const appLanguages = <List<String>>[
  ['ru', 'Русский'],
  ['en', 'English'],
  ['uk', 'Українська'],
  ['ar', 'العربية'],
  ['de', 'Deutsch'],
];

// Telegram-бот проверки профиля и уведомлений.
const telegramBot = 'svoi_egypt_bot';

/// Онлайн-оплата (Paymob). Пока выключена: кнопку «Продвинуть» видит только админ.
const paymentsEnabled = false;
