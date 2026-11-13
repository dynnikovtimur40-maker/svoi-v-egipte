// Оплата продвижения объявлений через Paymob (Египет: карты, кошельки, Fawry и т.д.).
// POST {post_id, product} с токеном пользователя → ссылка на страницу оплаты Paymob.
// POST ?hook=1 — уведомление Paymob об оплате (проверка подписи HMAC), включаем услугу.
import { cors, db, emailOf, json, langOf, sendEmail, SITE_URL, SUPABASE_URL, t, userFrom } from "../_shared/util.ts";

const SECRET = Deno.env.get("PAYMOB_SECRET_KEY") ?? "";
const PUBLIC = Deno.env.get("PAYMOB_PUBLIC_KEY") ?? "";
const INTEGRATIONS = (Deno.env.get("PAYMOB_INTEGRATION_IDS") ?? "").split(",").map((s) => Number(s.trim())).filter((n) => n > 0);
const HMAC = Deno.env.get("PAYMOB_HMAC") ?? "";
const API = Deno.env.get("PAYMOB_API") ?? "https://accept.paymob.com";

// Порядок полей для подписи уведомления о транзакции (документация Paymob)
const HMAC_FIELDS = [
  "amount_cents", "created_at", "currency", "error_occured", "has_parent_transaction", "id",
  "integration_id", "is_3d_secure", "is_auth", "is_capture", "is_refunded", "is_standalone_payment",
  "is_voided", "order.id", "owner", "pending", "source_data.pan", "source_data.sub_type",
  "source_data.type", "success",
];

function pick(obj: Record<string, unknown>, path: string): string {
  let cur: unknown = obj;
  for (const k of path.split(".")) cur = (cur as Record<string, unknown> | undefined)?.[k];
  return cur === undefined || cur === null ? "" : String(cur);
}

async function hmacHex(data: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(HMAC), { name: "HMAC", hash: "SHA-512" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(data));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function create(req: Request): Promise<Response> {
  if (!SECRET || !PUBLIC || INTEGRATIONS.length === 0) return json({ error: "payments_not_configured" }, 503);
  const user = await userFrom(req);
  if (!user) return json({ error: "login_required" }, 401);
  const { post_id, product } = await req.json().catch(() => ({}));
  const base = db();

  const { data: post } = await base.from("posts").select("id, user_id, title, status").eq("id", post_id).maybeSingle();
  if (!post || post.user_id !== user.id) return json({ error: "not_your_post" }, 403);
  if (post.status !== "active") return json({ error: "post_not_active" }, 400);
  const { data: prod } = await base.from("products").select("*").eq("code", product).eq("active", true).maybeSingle();
  if (!prod) return json({ error: "unknown_product" }, 400);

  const { data: prof } = await base.from("profiles").select("name, phone").eq("id", user.id).maybeSingle();
  const { data: pay, error } = await base.from("payments").insert({
    user_id: user.id, post_id, product, amount_egp: prod.price_egp,
  }).select().single();
  if (error || !pay) return json({ error: "db_error" }, 500);

  const cents = prod.price_egp * 100;
  const name = String(prof?.name || "Client").trim().split(/\s+/);
  const r = await fetch(`${API}/v1/intention/`, {
    method: "POST",
    headers: { Authorization: `Token ${SECRET}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      amount: cents,
      currency: "EGP",
      payment_methods: INTEGRATIONS,
      items: [{ name: prod.title, amount: cents, description: String(post.title).slice(0, 50), quantity: 1 }],
      billing_data: {
        first_name: name[0] || "Client",
        last_name: name.slice(1).join(" ") || "-",
        email: user.email ?? "client@example.com",
        phone_number: prof?.phone || "+201000000000",
        country: "EG", city: "NA", street: "NA", building: "NA", floor: "NA", apartment: "NA",
      },
      special_reference: pay.id,
      extras: { payment_id: pay.id },
      notification_url: `${SUPABASE_URL}/functions/v1/payments?hook=1`,
      redirection_url: SITE_URL,
    }),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || !j.client_secret) {
    await base.from("payments").update({ status: "failed" }).eq("id", pay.id);
    console.error("paymob intention error", r.status, JSON.stringify(j));
    return json({ error: "provider_error" }, 502);
  }
  await base.from("payments").update({ provider_ref: String(j.id ?? "") }).eq("id", pay.id);
  return json({
    url: `${API}/unifiedcheckout/?publicKey=${encodeURIComponent(PUBLIC)}&clientSecret=${encodeURIComponent(j.client_secret)}`,
    payment_id: pay.id,
  });
}

async function hook(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const body = await req.json().catch(() => ({}));
  const obj = (body.obj ?? {}) as Record<string, unknown>;
  const given = url.searchParams.get("hmac") ?? "";
  const calc = await hmacHex(HMAC_FIELDS.map((f) => pick(obj, f)).join(""));
  if (!HMAC || given.toLowerCase() !== calc) return new Response("bad hmac", { status: 401 });

  const payId = pick(obj, "order.merchant_order_id") || pick(obj, "payment_key_claims.extra.payment_id") ||
    pick(obj, "payment_key_claims.extra.extras.payment_id");
  if (!payId) return new Response("no ref");
  const base = db();
  const { data: pay } = await base.from("payments").select("*").eq("id", payId).maybeSingle();
  if (!pay || pay.status === "paid") return new Response("ok");

  const success = pick(obj, "success") === "true" && pick(obj, "pending") !== "true";
  const amountOk = Number(pick(obj, "amount_cents")) >= pay.amount_egp * 100;
  if (!success || !amountOk) {
    await base.from("payments").update({ status: "failed" }).eq("id", pay.id);
    return new Response("ok");
  }
  await base.from("payments").update({ status: "paid", paid_at: new Date().toISOString(), provider_ref: pick(obj, "id") }).eq("id", pay.id);
  if (pay.post_id) await base.rpc("apply_promotion", { p_post: pay.post_id, p_product: pay.product });

  const [{ data: prod }, { data: post }] = await Promise.all([
    base.from("products").select("title").eq("code", pay.product).maybeSingle(),
    base.from("posts").select("title").eq("id", pay.post_id).maybeSingle(),
  ]);
  const lang = await langOf(pay.user_id);
  const mail = await emailOf(pay.user_id);
  if (mail) {
    await sendEmail(mail, t("subj_paid", lang), t("paid", lang, { p: prod?.title ?? pay.product, t: post?.title ?? "", a: pay.amount_egp }));
  }
  return new Response("ok");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const url = new URL(req.url);
  try {
    if (url.searchParams.get("hook")) return await hook(req);
    if (req.method === "POST") return await create(req);
    return json({ ok: true });
  } catch (e) {
    console.error(e);
    return json({ error: "server_error" }, 500);
  }
});
