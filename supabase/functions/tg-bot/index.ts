// Telegram-бот @svoi_egypt_bot.
// 1) Проверка профиля: приложение открывает t.me/<бот>?start=<ссылка>, бот присылает 6-значный код,
//    человек вводит его в приложении — профиль получает отметку «Проверен» (Telegram подтверждён).
// 2) Модерация: о подозрительных объявлениях и жалобах бот сразу пишет администратору с кнопками.
//
// GET  ?code=XXXX           — ссылка на бота для приложения
// POST ?notify=post|report  — вызывается из базы (pg_net)
// POST (вебхук Telegram)    — с секретным заголовком
import { cors, db, emailOf, json, langOf, sendEmail, t, webhookSecret } from "../_shared/util.ts";

const TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN") ?? "";
const ADMIN_CHAT = Deno.env.get("TELEGRAM_ADMIN_CHAT_ID") ?? "";
const TEST_DOMAIN = "@svoi-test.dev"; // тестовые аккаунты — без уведомлений администратору

async function tg(method: string, body: Record<string, unknown>) {
  const r = await fetch(`https://api.telegram.org/bot${TOKEN}/${method}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return r.json().catch(() => ({}));
}

let botName = "";
async function botUsername(): Promise<string> {
  if (!botName) {
    const r = await tg("getMe", {});
    botName = r?.result?.username ?? "";
  }
  return botName;
}

const M: Record<string, Record<string, string>> = {
  code: {
    ru: "Ваш код проверки: {c}\n\nВведите его в приложении «Свои в Египте». Код действует 10 минут.",
    en: "Your verification code: {c}\n\nEnter it in the Svoi in Egypt app. The code is valid for 10 minutes.",
    uk: "Ваш код перевірки: {c}\n\nВведіть його в застосунку «Свої в Єгипті». Код діє 10 хвилин.",
    ar: "رمز التوثيق الخاص بك: {c}\n\nأدخله في تطبيق «سفوي في مصر». الرمز صالح لمدة 10 دقائق.",
  },
  nocode: {
    ru: "Это бот проверки профиля «Свои в Египте».\n\nОткройте приложение → Профиль → «Проверка профиля» и нажмите «Получить код в Telegram» — бот пришлёт код.",
    en: "This is the Svoi in Egypt verification bot.\n\nOpen the app → Profile → “Profile verification” and tap “Get code in Telegram” — the bot will send you a code.",
    uk: "Це бот перевірки профілю «Свої в Єгипті».\n\nВідкрийте застосунок → Профіль → «Перевірка профілю» і натисніть «Отримати код у Telegram» — бот надішле код.",
    ar: "هذا بوت توثيق الملف في «سفوي في مصر».\n\nافتح التطبيق ← الملف الشخصي ← «توثيق الملف» واضغط «احصل على الرمز في تيليجرام» — سيرسل لك البوت رمزًا.",
  },
  badcode: {
    ru: "Ссылка устарела или уже использована. Откройте её заново из приложения: Профиль → «Проверка профиля».",
    en: "This link is outdated or already used. Open it again from the app: Profile → “Profile verification”.",
    uk: "Посилання застаріло або вже використане. Відкрийте його знову із застосунку: Профіль → «Перевірка профілю».",
    ar: "الرابط منتهٍ أو مستخدم. افتحه مجددًا من التطبيق: الملف الشخصي ← «توثيق الملف».",
  },
  taken: {
    ru: "Этот Telegram уже привязан к другому профилю. Один Telegram — один профиль.",
    en: "This Telegram account is already linked to another profile. One Telegram — one profile.",
    uk: "Цей Telegram уже прив'язаний до іншого профілю. Один Telegram — один профіль.",
    ar: "حساب تيليجرام هذا مرتبط بملف آخر بالفعل. حساب واحد لملف واحد.",
  },
  verified: {
    ru: "Готово! Ваш профиль проверен ✅",
    en: "Done! Your profile is verified ✅",
    uk: "Готово! Ваш профіль перевірено ✅",
    ar: "تم! تم توثيق ملفك ✅",
  },
};

function lang(code: string) {
  return code.startsWith("uk") ? "uk" : code.startsWith("ar") ? "ar" : code.startsWith("ru") ? "ru" : "en";
}
function msg(key: string, l: string, c = "") {
  return (M[key][lang(l)] ?? M[key].en).replace("{c}", c);
}
function otp(): string {
  const a = new Uint32Array(1);
  crypto.getRandomValues(a);
  return String(100000 + (a[0] % 900000));
}
function esc(s: string) {
  return String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

async function isTestUser(userId: string | null | undefined): Promise<boolean> {
  if (!userId) return false;
  const e = await emailOf(userId);
  return !!e && e.endsWith(TEST_DOMAIN);
}

// ---------- Уведомления администратору ----------

async function notifyPost(postId: string) {
  const base = db();
  const { data: p } = await base.from("posts")
    .select("id, user_id, title, description, price_egp, city, category, contact, photos, status, auto_flags, mod_notified_at, profiles!posts_user_id_fkey(name)")
    .eq("id", postId).maybeSingle();
  if (!p || p.status !== "pending" || p.mod_notified_at) return;
  await base.from("posts").update({ mod_notified_at: new Date().toISOString() }).eq("id", postId);
  if (!ADMIN_CHAT || await isTestUser(p.user_id)) return;
  // deno-lint-ignore no-explicit-any
  const author = (p as any).profiles?.name ?? "—";
  const price = p.price_egp == null ? "договорная" : `${p.price_egp} EGP`;
  const text = `🕵️ <b>Объявление на проверке</b>\n${p.auto_flags ? "⚠️ " + esc(p.auto_flags) + "\n" : ""}\n` +
    `<b>${esc(p.title)}</b>\n${esc(price)} · ${esc(p.city)} · ${esc(p.category)}\n` +
    `${esc(String(p.description ?? "").slice(0, 600))}\n\nАвтор: ${esc(author)} · ${esc(p.contact)}`;
  const kb = {
    inline_keyboard: [[
      { text: "✅ Опубликовать", callback_data: `pa:${p.id}` },
      { text: "❌ Отклонить", callback_data: `pr:${p.id}` },
    ]],
  };
  const photo = Array.isArray(p.photos) && p.photos.length ? p.photos[0] : null;
  if (photo) {
    await tg("sendPhoto", { chat_id: ADMIN_CHAT, photo, caption: text.slice(0, 1000), parse_mode: "HTML", reply_markup: kb });
  } else {
    await tg("sendMessage", { chat_id: ADMIN_CHAT, text, parse_mode: "HTML", reply_markup: kb });
  }
}

async function notifyReport(reportId: number) {
  const base = db();
  const { data: r } = await base.from("reports")
    .select("id, user_id, reason, post_id, target_user, post:posts(id, title, status, user_id), target:profiles!reports_target_user_fkey(name)")
    .eq("id", reportId).maybeSingle();
  if (!r || !ADMIN_CHAT || await isTestUser(r.user_id)) return;
  // deno-lint-ignore no-explicit-any
  const x = r as any;
  const what = x.post
    ? `на объявление «${esc(x.post.title)}»${x.post.status === "pending" ? " — скрыто после 3 жалоб" : ""}`
    : `на пользователя ${esc(x.target?.name ?? "—")}`;
  const kb = x.post && x.post.status === "pending"
    ? { inline_keyboard: [[{ text: "✅ Вернуть в ленту", callback_data: `pa:${x.post.id}` }, { text: "❌ Снять", callback_data: `pr:${x.post.id}` }]] }
    : undefined;
  await tg("sendMessage", {
    chat_id: ADMIN_CHAT,
    text: `🚩 <b>Жалоба</b> ${what}\nПричина: ${esc(x.reason || "не указана")}\n\nПодробнее: приложение → Модерация → Жалобы`,
    parse_mode: "HTML",
    ...(kb ? { reply_markup: kb } : {}),
  });
}

// ---------- Проверка профиля ----------

async function sendCode(chat: number, from: Record<string, unknown>, v: Record<string, unknown>) {
  const base = db();
  const l = String(from?.language_code ?? "ru");
  const { data: other } = await base.from("profiles").select("id").eq("tg_id", chat).neq("id", v.user_id as string).maybeSingle();
  if (other) {
    await tg("sendMessage", { chat_id: chat, text: msg("taken", l) });
    return;
  }
  const code = otp();
  await base.from("verifications").update({
    otp: code,
    otp_expires: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
    attempts: 0,
    tg_chat_id: chat,
    tg_username: (from?.username as string) ?? null,
    status: "sent",
    updated_at: new Date().toISOString(),
  }).eq("id", v.id as number);
  await tg("sendMessage", { chat_id: chat, text: msg("code", l, code) });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const url = new URL(req.url);

  if (req.method === "GET") {
    const code = url.searchParams.get("code") ?? "";
    const name = TOKEN ? await botUsername() : "";
    if (!name) return json({ error: "bot_not_configured" }, 503);
    return json({ url: `https://t.me/${name}?start=${encodeURIComponent(code)}`, bot: name });
  }

  const notify = url.searchParams.get("notify");
  if (notify) {
    try {
      const b = await req.json().catch(() => ({}));
      if (notify === "post" && b.post_id) await notifyPost(String(b.post_id));
      if (notify === "report" && b.report_id) await notifyReport(Number(b.report_id));
    } catch (e) {
      console.error("notify", e);
    }
    return json({ ok: true });
  }

  if (!TOKEN || req.headers.get("x-telegram-bot-api-secret-token") !== (await webhookSecret(TOKEN))) {
    return new Response("forbidden", { status: 403 });
  }

  try {
    const u = await req.json().catch(() => ({}));
    const base = db();

    // Кнопки модератора
    if (u.callback_query) {
      const cq = u.callback_query;
      const answer = (text: string) => tg("answerCallbackQuery", { callback_query_id: cq.id, text });
      if (String(cq.message?.chat?.id) !== ADMIN_CHAT) {
        await answer("Нет доступа");
        return new Response("ok");
      }
      const [act, id] = String(cq.data ?? "").split(":");
      if (act === "pa" || act === "pr") {
        const ok = act === "pa";
        const { data: post } = await base.from("posts").select("id, user_id, title, status").eq("id", id).maybeSingle();
        if (!post) {
          await answer("Объявление уже удалено");
        } else {
          await base.from("posts").update({
            status: ok ? "active" : "blocked",
            reject_reason: ok ? null : "Нарушение правил сервиса",
            auto_flags: null,
          }).eq("id", id);
          const l = await langOf(post.user_id);
          const mail = await emailOf(post.user_id);
          if (mail) {
            await sendEmail(mail, t("subj_post", l), ok
              ? t("approved", l, { t: post.title })
              : t("rejected", l, { t: post.title, r: "Нарушение правил сервиса" }));
          }
          await answer(ok ? "Опубликовано" : "Отклонено");
        }
        await tg("editMessageReplyMarkup", { chat_id: cq.message.chat.id, message_id: cq.message.message_id, reply_markup: { inline_keyboard: [] } });
        await tg("sendMessage", {
          chat_id: ADMIN_CHAT,
          reply_to_message_id: cq.message.message_id,
          text: post ? (ok ? "✅ Опубликовано" : "❌ Отклонено") : "Объявление уже удалено",
        });
      } else {
        await answer("Неизвестная команда");
      }
      return new Response("ok");
    }

    const m = u.message;
    if (!m || m.chat?.type !== "private") return new Response("ok");
    const chat = m.chat.id as number;
    const l = String(m.from?.language_code ?? "ru");
    const text = typeof m.text === "string" ? m.text.trim() : "";

    if (text.startsWith("/start")) {
      const code = (text.split(/\s+/)[1] ?? "").trim().toUpperCase();
      if (code) {
        const { data: v } = await base.from("verifications").select("*").eq("code", code).in("status", ["new", "sent"]).maybeSingle();
        if (!v) {
          await tg("sendMessage", { chat_id: chat, text: msg("badcode", l) });
          return new Response("ok");
        }
        const { data: prof } = await base.from("profiles").select("verified").eq("id", v.user_id).maybeSingle();
        if (prof?.verified) {
          await tg("sendMessage", { chat_id: chat, text: msg("verified", l) });
          return new Response("ok");
        }
        await sendCode(chat, m.from, v);
        return new Response("ok");
      }
      // /start без ссылки: если этот Telegram уже начинал проверку — новый код
      const { data: v } = await base.from("verifications").select("*").eq("tg_chat_id", chat).eq("status", "sent")
        .order("id", { ascending: false }).limit(1).maybeSingle();
      if (v) {
        await sendCode(chat, m.from, v);
        return new Response("ok");
      }
    }
    await tg("sendMessage", { chat_id: chat, text: msg("nocode", l) });
    return new Response("ok");
  } catch (e) {
    console.error(e);
    return new Response("ok");
  }
});
