// Письма пользователям через Resend. Вызывает приложение администратора после модерации.
// POST {kind: "post", post_id} — объявление одобрено/отклонено.
// POST {kind: "verify", user_id} — решение по проверке профиля из приложения.
import { cors, db, emailOf, isAdmin, json, langOf, sendEmail, t, userFrom } from "../_shared/util.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const me = await userFrom(req);
    if (!me || !(await isAdmin(me.id))) return json({ error: "forbidden" }, 403);
    const { kind, post_id, user_id } = await req.json().catch(() => ({}));
    const base = db();

    if (kind === "post") {
      const { data: post } = await base.from("posts").select("user_id, title, status, reject_reason").eq("id", post_id).maybeSingle();
      if (!post || !["active", "blocked"].includes(post.status)) return json({ sent: false });
      const lang = await langOf(post.user_id);
      const text = post.status === "active"
        ? t("approved", lang, { t: post.title })
        : t("rejected", lang, { t: post.title, r: post.reject_reason ?? "—" });
      const mail = await emailOf(post.user_id);
      return json({ sent: mail ? await sendEmail(mail, t("subj_post", lang), text) : false });
    }

    if (kind === "verify") {
      const { data: prof } = await base.from("profiles").select("verified").eq("id", user_id).maybeSingle();
      const lang = await langOf(user_id);
      const text = prof?.verified ? t("verified", lang) : t("not_verified", lang, { r: "—" });
      const mail = await emailOf(user_id);
      const { data: v } = await base.from("verifications").select("tg_chat_id").eq("user_id", user_id)
        .order("id", { ascending: false }).limit(1).maybeSingle();
      const token = Deno.env.get("TELEGRAM_BOT_TOKEN");
      if (token && v?.tg_chat_id) {
        await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ chat_id: v.tg_chat_id, text }),
        });
      }
      return json({ sent: mail ? await sendEmail(mail, t("subj_verify", lang), text) : false });
    }
    return json({ error: "unknown_kind" }, 400);
  } catch (e) {
    console.error(e);
    return json({ error: "server_error" }, 500);
  }
});
