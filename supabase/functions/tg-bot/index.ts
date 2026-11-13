// Telegram-бот проверки пользователей.
// Пользователь в приложении получает код и открывает бота по ссылке t.me/<бот>?start=<код>,
// присылает фото документа и селфи с ним. Фото уходят только администратору в Telegram,
// на нашем сервере документы не хранятся. Администратор жмёт ✅ или ❌.
//
// GET ?code=XXXX — приложение получает ссылку на бота с кодом.
import { cors, db, emailOf, json, langOf, sendEmail, t, webhookSecret } from "../_shared/util.ts";

const TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN") ?? "";
const ADMIN_CHAT = Deno.env.get("TELEGRAM_ADMIN_CHAT_ID") ?? "";

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
  hello: {
    ru: "Здравствуйте! Это проверка профиля «Свои в Египте».\n\nШаг 1 из 2: пришлите фото страницы паспорта (или ID) с фото и именем.\nШаг 2: селфи с этим документом в руке.\n\nДокументы видит только модератор, в приложении и на сервере они не сохраняются.",
    en: "Hello! This is the “Svoi v Egipte” profile verification.\n\nStep 1 of 2: send a photo of your passport (or ID) page with your photo and name.\nStep 2: a selfie holding that document.\n\nOnly the moderator sees the documents; they are not stored in the app or on our server.",
    uk: "Вітаємо! Це перевірка профілю «Свої в Єгипті».\n\nКрок 1 з 2: надішліть фото сторінки паспорта (або ID) з фото та ім'ям.\nКрок 2: селфі з цим документом у руці.\n\nДокументи бачить лише модератор, у застосунку та на сервері вони не зберігаються.",
    ar: "مرحبًا! هذا توثيق الملف الشخصي في «سفوي في مصر».\n\nالخطوة 1 من 2: أرسل صورة صفحة جواز السفر (أو البطاقة) التي تحتوي على صورتك واسمك.\nالخطوة 2: صورة سيلفي وأنت تمسك المستند.\n\nلا يرى المستندات إلا المشرف، ولا يتم حفظها في التطبيق أو على الخادم.",
  },
  step2: {
    ru: "Отлично! Теперь селфи с документом в руке.",
    en: "Great! Now a selfie holding the document.",
    uk: "Чудово! Тепер селфі з документом у руці.",
    ar: "ممتاز! الآن صورة سيلفي وأنت تمسك المستند.",
  },
  done: {
    ru: "Спасибо! Модератор проверит документы — обычно в течение суток. Результат придёт сюда и на почту.",
    en: "Thank you! A moderator will review the documents, usually within 24 hours. You'll get the result here and by email.",
    uk: "Дякуємо! Модератор перевірить документи — зазвичай протягом доби. Результат прийде сюди та на пошту.",
    ar: "شكرًا! سيراجع المشرف المستندات خلال 24 ساعة عادةً. ستصلك النتيجة هنا وعلى البريد.",
  },
  nocode: {
    ru: "Откройте приложение «Свои в Египте» → Профиль → «Пройти проверку» и нажмите кнопку Telegram — бот получит ваш код.",
    en: "Open the “Svoi v Egipte” app → Profile → “Get verified” and tap the Telegram button so the bot gets your code.",
    uk: "Відкрийте застосунок «Свої в Єгипті» → Профіль → «Пройти перевірку» і натисніть кнопку Telegram — бот отримає ваш код.",
    ar: "افتح تطبيق «سفوي في مصر» ← الملف الشخصي ← «التوثيق» واضغط زر تيليجرام ليحصل البوت على رمزك.",
  },
  badcode: {
    ru: "Код не найден или уже использован. Получите новый в приложении: Профиль → «Пройти проверку».",
    en: "Code not found or already used. Get a new one in the app: Profile → “Get verified”.",
    uk: "Код не знайдено або вже використано. Отримайте новий у застосунку: Профіль → «Пройти перевірку».",
    ar: "الرمز غير موجود أو مستخدم. احصل على رمز جديد من التطبيق: الملف الشخصي ← «التوثيق».",
  },
  wait: {
    ru: "Документы уже у модератора. Дождитесь ответа, пожалуйста.",
    en: "Your documents are already with the moderator. Please wait for the answer.",
    uk: "Документи вже в модератора. Дочекайтеся відповіді, будь ласка.",
    ar: "المستندات لدى المشرف بالفعل. يرجى انتظار الرد.",
  },
};

function msg(key: string, lang: string) {
  const l = lang.startsWith("uk") ? "uk" : lang.startsWith("ar") ? "ar" : lang.startsWith("ru") ? "ru" : "en";
  return M[key][l] ?? M[key].en;
}

const REJECT_REASON = "документ не читается или не совпадает с профилем";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  // Ссылка на бота для приложения
  if (req.method === "GET") {
    const code = new URL(req.url).searchParams.get("code") ?? "";
    const name = TOKEN ? await botUsername() : "";
    if (!name) return json({ error: "bot_not_configured" }, 503);
    return json({ url: `https://t.me/${name}?start=${encodeURIComponent(code)}`, bot: name });
  }

  if (!TOKEN || req.headers.get("x-telegram-bot-api-secret-token") !== (await webhookSecret(TOKEN))) {
    return new Response("forbidden", { status: 403 });
  }

  const u = await req.json().catch(() => ({}));
  const base = db();

  // Решение администратора кнопкой
  if (u.callback_query) {
    const cq = u.callback_query;
    if (String(cq.message?.chat?.id) !== ADMIN_CHAT) {
      await tg("answerCallbackQuery", { callback_query_id: cq.id, text: "Нет доступа" });
      return new Response("ok");
    }
    const [act, idStr] = String(cq.data ?? "").split(":");
    const { data: v } = await base.from("verifications").select("*").eq("id", Number(idStr)).maybeSingle();
    if (!v || !["new", "sent"].includes(v.status)) {
      await tg("answerCallbackQuery", { callback_query_id: cq.id, text: "Заявка уже обработана" });
      return new Response("ok");
    }
    const ok = act === "ok";
    await base.from("profiles").update({ verified: ok }).eq("id", v.user_id);
    await base.from("verifications").update({
      status: ok ? "approved" : "rejected",
      reason: ok ? null : REJECT_REASON,
      updated_at: new Date().toISOString(),
    }).eq("id", v.id);

    const lang = await langOf(v.user_id);
    const text = ok ? t("verified", lang) : t("not_verified", lang, { r: REJECT_REASON });
    if (v.tg_chat_id) await tg("sendMessage", { chat_id: v.tg_chat_id, text });
    const mail = await emailOf(v.user_id);
    if (mail) await sendEmail(mail, t("subj_verify", lang), text);

    await tg("editMessageReplyMarkup", { chat_id: cq.message.chat.id, message_id: cq.message.message_id, reply_markup: { inline_keyboard: [] } });
    await tg("sendMessage", { chat_id: ADMIN_CHAT, text: `${ok ? "✅ Подтверждено" : "❌ Отклонено"}: заявка #${v.id}` });
    await tg("answerCallbackQuery", { callback_query_id: cq.id, text: ok ? "Подтверждено" : "Отклонено" });
    return new Response("ok");
  }

  const m = u.message;
  if (!m) return new Response("ok");
  const chat = m.chat.id;
  const lang = String(m.from?.language_code ?? "ru");
  const reply = (key: string) => tg("sendMessage", { chat_id: chat, text: msg(key, lang) });

  if (typeof m.text === "string" && m.text.startsWith("/start")) {
    const code = (m.text.split(/\s+/)[1] ?? "").trim().toUpperCase();
    if (!code) {
      await reply("nocode");
      return new Response("ok");
    }
    const { data: v } = await base.from("verifications").select("*").eq("code", code).in("status", ["new", "sent"]).maybeSingle();
    if (!v) {
      await reply("badcode");
      return new Response("ok");
    }
    if (v.status === "sent") {
      await reply("wait");
      return new Response("ok");
    }
    await base.from("verifications").update({
      tg_chat_id: chat,
      tg_username: m.from?.username ?? null,
      photos: 0,
      updated_at: new Date().toISOString(),
    }).eq("id", v.id);
    await reply("hello");
    return new Response("ok");
  }

  const fileId: string | undefined = m.photo ? m.photo[m.photo.length - 1]?.file_id : m.document?.file_id;
  if (!fileId) {
    await reply("nocode");
    return new Response("ok");
  }

  const { data: v } = await base.from("verifications").select("*").eq("tg_chat_id", chat)
    .in("status", ["new", "sent"]).order("id", { ascending: false }).limit(1).maybeSingle();
  if (!v) {
    await reply("nocode");
    return new Response("ok");
  }
  if (v.status === "sent") {
    await reply("wait");
    return new Response("ok");
  }

  const n = (v.photos ?? 0) + 1;
  const { data: prof } = await base.from("profiles").select("name, city, created_at").eq("id", v.user_id).maybeSingle();
  const caption = `Проверка #${v.id} · фото ${n} из 2\n${prof?.name ?? "—"} · ${prof?.city ?? ""}\n` +
    `Telegram: ${m.from?.username ? "@" + m.from.username : "без ника"}\nuser: ${v.user_id}`;
  if (m.photo) {
    await tg("sendPhoto", { chat_id: ADMIN_CHAT, photo: fileId, caption });
  } else {
    await tg("sendDocument", { chat_id: ADMIN_CHAT, document: fileId, caption });
  }

  if (n < 2) {
    await base.from("verifications").update({ photos: n, updated_at: new Date().toISOString() }).eq("id", v.id);
    await reply("step2");
  } else {
    await base.from("verifications").update({ photos: n, status: "sent", updated_at: new Date().toISOString() }).eq("id", v.id);
    await tg("sendMessage", {
      chat_id: ADMIN_CHAT,
      text: `Заявка #${v.id}: ${prof?.name ?? "—"}. Документы выше. Подтвердить?`,
      reply_markup: {
        inline_keyboard: [[
          { text: "✅ Подтвердить", callback_data: `ok:${v.id}` },
          { text: "❌ Отклонить", callback_data: `no:${v.id}` },
        ]],
      },
    });
    await reply("done");
  }
  return new Response("ok");
});
