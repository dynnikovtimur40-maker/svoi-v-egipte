// Курс египетского фунта к рублю, доллару и евро. Обновляется раз в 6 часов.
import { cors, json } from "../_shared/util.ts";

let cache: { at: number; data: Record<string, unknown> } | null = null;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (cache && Date.now() - cache.at < 6 * 3600 * 1000) return json(cache.data);
  try {
    const r = await fetch("https://open.er-api.com/v6/latest/EGP");
    const j = await r.json();
    const x = j?.rates ?? {};
    if (!x.RUB || !x.USD || !x.EUR) throw new Error("bad rates");
    const data = {
      rub: Math.round(x.RUB * 1000) / 1000,
      egp_per_usd: Math.round((1 / x.USD) * 100) / 100,
      egp_per_eur: Math.round((1 / x.EUR) * 100) / 100,
      updated: new Date((j.time_last_update_unix ?? Date.now() / 1000) * 1000).toISOString(),
    };
    cache = { at: Date.now(), data };
    return json(data);
  } catch (e) {
    console.error(e);
    return cache ? json(cache.data) : json({ error: "rates_unavailable" }, 503);
  }
});
