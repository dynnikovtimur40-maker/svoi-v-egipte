# Подключение сервисов (этап 6)

Код уже в репозитории. Ключи вставляются один раз: GitHub → репозиторий → **Settings → Secrets and variables → Actions → New repository secret**. После добавления: **Actions → Supabase functions → Run workflow**.

## 1. База (обязательно)
Применяется автоматически (db/run.txt). Вручную: SQL Editor → `db/schema_v4.sql` → Run (должно вывести `v4 ok`).

## 2. Публикация серверных функций — подключено ✅
Supabase → аватар → **Account → Access Tokens → Generate** → секрет `SUPABASE_ACCESS_TOKEN`.

## 3. Telegram-бот @svoi_egypt_bot — подключён ✅
Проверка профиля: бот присылает 6-значный код, человек вводит его в приложении.
Модерация: о подозрительных объявлениях и жалобах бот пишет администратору с кнопками ✅/❌.

## 4. Оплата Paymob
Аккаунт на accept.paymob.com (нужны документы ИП/компании в Египте). В кабинете → Settings / Developers:
- `PAYMOB_SECRET_KEY` — Secret key
- `PAYMOB_PUBLIC_KEY` — Public key
- `PAYMOB_HMAC` — HMAC secret
- `PAYMOB_INTEGRATION_IDS` — ID способов оплаты через запятую (карта, кошелёк)
Сначала тестовый режим (test keys), потом боевой.

## 5. Почта Resend
1. resend.com → добавить свой домен (например `svoi-egypt.com`) и DNS-записи → Verify.
2. API Keys → ключ → секрет `RESEND_API_KEY`; секрет `MAIL_FROM` = `Свои в Египте <noreply@ваш-домен>`.
3. Письма входа/регистрации: Supabase → Authentication → **SMTP Settings** → Enable:
   host `smtp.resend.com`, port `465`, user `resend`, password = API-ключ, sender = `noreply@ваш-домен`.

## Что работает без ключей
Языки, редактор фото, путеводитель, автопроверка объявлений, VIP/выделение (админ выдаёт бесплатно кнопкой в «Продвинуть»), подтверждение пользователей админом в «Модерация → Люди».

## Автоматические проверки (GitHub Actions)
- `E2E tests` — сценарии на временных тестовых аккаунтах (@svoi-test.dev), после теста аккаунты удаляются.
- `Database` — применяет SQL из `db/run.txt`.
- `Supabase functions` — публикует бота, оплату и письма.
