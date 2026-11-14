// Общие помощники для серверных функций «Свои в Египте».
import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

export const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
export const SITE_URL = Deno.env.get("SITE_URL") ?? "https://dynnikovtimur40-maker.github.io/svoi-v-egipte/";

export const cors: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

let _db: SupabaseClient | null = null;
/** Клиент с сервисным ключом — обходит правила доступа, только на сервере. */
export function db(): SupabaseClient {
  _db ??= createClient(SUPABASE_URL, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  return _db;
}

/** Пользователь по токену из заголовка Authorization (или null). */
export async function userFrom(req: Request) {
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!jwt) return null;
  const { data } = await db().auth.getUser(jwt);
  return data.user ?? null;
}

export async function isAdmin(userId: string): Promise<boolean> {
  const { data } = await db().from("profiles").select("role").eq("id", userId).maybeSingle();
  return data?.role === "admin";
}

export async function emailOf(userId: string): Promise<string | null> {
  const { data } = await db().auth.admin.getUserById(userId);
  return data.user?.email ?? null;
}

export async function langOf(userId: string): Promise<string> {
  const { data } = await db().from("profiles").select("lang").eq("id", userId).maybeSingle();
  return (data?.lang as string) || "ru";
}

/** Письмо через Resend. Без ключа просто ничего не делает. */
export async function sendEmail(to: string, subject: string, text: string): Promise<boolean> {
  const key = Deno.env.get("RESEND_API_KEY");
  if (!key || !to) return false;
  const from = Deno.env.get("MAIL_FROM") ?? "Свои в Египте <noreply@svoi-egypt.com>";
  const html = `<div style="font-family:Arial,sans-serif;font-size:15px;line-height:1.5;color:#13262B">
    <div style="font-size:18px;font-weight:700;color:#0B6770;margin-bottom:12px">Свои в Египте</div>
    ${text.split("\n").map((l) => `<p style="margin:0 0 10px">${escapeHtml(l)}</p>`).join("")}
    <p style="margin-top:18px"><a href="${SITE_URL}" style="color:#0B6770">${SITE_URL}</a></p></div>`;
  const r = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from, to, subject, html, text }),
  });
  return r.ok;
}

function escapeHtml(s: string) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

/** Тексты писем и бота на языках приложения. */
export const T: Record<string, Record<string, string>> = {
  approved: {
    ru: "Ваше объявление «{t}» прошло проверку и опубликовано.",
    en: "Your ad “{t}” has been approved and published.",
    uk: "Ваше оголошення «{t}» пройшло перевірку та опубліковане.",
    ar: "تمت مراجعة إعلانك «{t}» ونشره.",
    de: "Ihre Anzeige „{t}“ wurde geprüft und veröffentlicht.",
  },
  rejected: {
    ru: "Объявление «{t}» отклонено модератором. Причина: {r}. Исправьте его в разделе «Мои объявления».",
    en: "Your ad “{t}” was rejected by a moderator. Reason: {r}. You can fix it in “My ads”.",
    uk: "Оголошення «{t}» відхилено модератором. Причина: {r}. Виправте його в розділі «Мої оголошення».",
    ar: "رفض المشرف إعلانك «{t}». السبب: {r}. يمكنك تعديله في «إعلاناتي».",
    de: "Ihre Anzeige „{t}“ wurde abgelehnt. Grund: {r}. Sie können sie unter „Meine Anzeigen“ korrigieren.",
  },
  subj_post: { ru: "Проверка объявления", en: "Ad review", uk: "Перевірка оголошення", ar: "مراجعة الإعلان", de: "Anzeigenprüfung" },
  verified: {
    ru: "Готово! Ваш профиль проверен — рядом с именем теперь отметка «Проверен».",
    en: "Done! Your profile is verified — you now have the “Verified” badge.",
    uk: "Готово! Ваш профіль перевірено — біля імені тепер позначка «Перевірений».",
    ar: "تم! تم توثيق ملفك الشخصي — تظهر الآن علامة «موثّق» بجانب اسمك.",
    de: "Fertig! Ihr Profil ist verifiziert — Sie haben jetzt das Abzeichen „Geprüft“.",
  },
  not_verified: {
    ru: "Проверка не пройдена: {r}. Попробуйте ещё раз — откройте в приложении «Профиль → Пройти проверку».",
    en: "Verification failed: {r}. Please try again via “Profile → Get verified” in the app.",
    uk: "Перевірку не пройдено: {r}. Спробуйте ще раз — «Профіль → Пройти перевірку» в застосунку.",
    ar: "لم يتم التوثيق: {r}. حاول مرة أخرى من «الملف الشخصي ← التوثيق» في التطبيق.",
    de: "Verifizierung fehlgeschlagen: {r}. Bitte erneut über „Profil → Verifizieren“ versuchen.",
  },
  subj_verify: { ru: "Проверка профиля", en: "Profile verification", uk: "Перевірка профілю", ar: "توثيق الملف الشخصي", de: "Profilprüfung" },
  paid: {
    ru: "Оплата получена: {p} для объявления «{t}». Сумма: {a} EGP. Спасибо!",
    en: "Payment received: {p} for your ad “{t}”. Amount: {a} EGP. Thank you!",
    uk: "Оплату отримано: {p} для оголошення «{t}». Сума: {a} EGP. Дякуємо!",
    ar: "تم استلام الدفع: {p} للإعلان «{t}». المبلغ: {a} جنيه. شكرًا لك!",
    de: "Zahlung erhalten: {p} für Ihre Anzeige „{t}“. Betrag: {a} EGP. Danke!",
  },
  subj_paid: { ru: "Оплата получена", en: "Payment received", uk: "Оплату отримано", ar: "تم استلام الدفع", de: "Zahlung erhalten" },
};

export function t(key: string, lang: string, vars: Record<string, string | number> = {}): string {
  const row = T[key] ?? {};
  let s = row[lang] ?? row.en ?? row.ru ?? key;
  for (const [k, v] of Object.entries(vars)) s = s.replaceAll(`{${k}}`, String(v));
  return s;
}

/** Секрет вебхука Telegram — выводится из токена бота (тот же расчёт в workflow). */
export async function webhookSecret(token: string): Promise<string> {
  const h = await crypto.subtle.digest("SHA-256", new TextEncoder().encode("svoi:" + token));
  return Array.from(new Uint8Array(h)).map((b) => b.toString(16).padStart(2, "0")).join("").slice(0, 40);
}
