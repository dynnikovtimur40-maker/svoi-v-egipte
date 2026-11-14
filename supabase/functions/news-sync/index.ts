// Автоматические новости: каждые 3 часа забирает свежие новости про Египет (для туристов и экспатов)
// из Google Новостей. Хранит только заголовок, источник и ссылку — читать полностью на сайте источника.
import { cors, db, json } from "../_shared/util.ts";

const FEEDS: { lang: string; q: string }[] = [
  { lang: "ru", q: "Египет туристы when:3d" },
  { lang: "ru", q: "Хургада OR Шарм-эль-Шейх when:3d" },
  { lang: "ru", q: "Египет виза OR въезд when:7d" },
  { lang: "ru", q: "Египет курс фунта when:7d" },
  { lang: "en", q: "Egypt tourists when:3d" },
  { lang: "en", q: "Hurghada OR \"Sharm El Sheikh\" when:3d" },
  { lang: "en", q: "Egypt visa OR \"e-visa\" when:7d" },
];

// Не туда: спорт, криминальная хроника без пользы и т.п.
const SKIP = /(футбол|матч|сборн|лига чемпионов|football|soccer|premier league|гороскоп|horoscope)/i;

function decode(s: string): string {
  return s.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")
    .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").trim();
}
function tag(x: string, name: string): string {
  const m = x.match(new RegExp(`<${name}[^>]*>([\\s\\S]*?)</${name}>`));
  return m ? decode(m[1]) : "";
}
function classify(t: string, lang: string): string {
  const s = t.toLowerCase();
  if (/(виз|visa|въезд|паспорт|границ|entry)/.test(s)) return "Визы";
  if (/(курс|фунт|доллар|рубл|exchange|pound|currency|цен)/.test(s)) return "Курс";
  if (/(безопасн|мошенн|предупрежд|акул|shark|scam|warning|safety|шторм|storm)/.test(s)) return "Безопасность";
  if (/(рейс|авиа|flight|airline|аэропорт|airport)/.test(s)) return "Туризм";
  if (/(турист|отел|курорт|отдых|tourist|hotel|resort|travel|пляж|beach)/.test(s)) return "Туризм";
  return lang === "ru" ? "Новости" : "Новости";
}
function norm(t: string) {
  return t.toLowerCase().replace(/[^a-zа-яё0-9]+/gi, " ").trim().slice(0, 70);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const base = db();
  const force = new URL(req.url).searchParams.get("force") === "1";

  // не чаще раза в 20 минут
  const { data: last } = await base.from("bot_log").select("created_at").eq("kind", "news-sync")
    .order("id", { ascending: false }).limit(1).maybeSingle();
  if (!force && last && Date.now() - new Date(last.created_at).getTime() < 20 * 60 * 1000) {
    return json({ skipped: true });
  }

  const { data: existing } = await base.from("news").select("url, title").order("id", { ascending: false }).limit(500);
  const urls = new Set((existing ?? []).map((n) => n.url).filter(Boolean));
  const titles = new Set((existing ?? []).map((n) => norm(n.title)));

  const fresh: Record<string, unknown>[] = [];
  const errors: string[] = [];
  for (const f of FEEDS) {
    const hl = f.lang === "ru" ? "hl=ru&gl=RU&ceid=RU:ru" : "hl=en-US&gl=US&ceid=US:en";
    try {
      const r = await fetch(`https://news.google.com/rss/search?q=${encodeURIComponent(f.q)}&${hl}`, {
        headers: { "User-Agent": "Mozilla/5.0 (compatible; SvoiVEgipteBot/1.0)" },
      });
      const xml = await r.text();
      for (const it of xml.split("<item>").slice(1, 15)) {
        let title = tag(it, "title");
        const link = tag(it, "link");
        const source = tag(it, "source");
        const pub = new Date(tag(it, "pubDate"));
        if (!title || !link) continue;
        if (source && title.endsWith(" - " + source)) title = title.slice(0, -(source.length + 3));
        if (SKIP.test(title)) continue;
        if (isNaN(pub.getTime()) || Date.now() - pub.getTime() > 7 * 24 * 3600 * 1000) continue;
        const key = norm(title);
        if (urls.has(link) || titles.has(key)) continue;
        urls.add(link);
        titles.add(key);
        fresh.push({
          tag: classify(title, f.lang), title: title.slice(0, 200), body: "", source: source.slice(0, 80) || null,
          url: link, lang: f.lang, auto: true, published: true, created_at: pub.toISOString(),
        });
      }
    } catch (e) {
      errors.push(`${f.q}: ${e}`);
    }
  }

  // самые свежие, не больше 12 за раз
  fresh.sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)));
  const add = fresh.slice(0, 12);
  if (add.length) {
    const { error } = await base.from("news").insert(add);
    if (error) errors.push(error.message);
  }
  // старые автоматические новости убираем
  await base.from("news").delete().eq("auto", true).lt("created_at", new Date(Date.now() - 21 * 24 * 3600 * 1000).toISOString());
  await base.from("bot_log").insert({ kind: "news-sync", detail: `added=${add.length} errors=${errors.join(" | ").slice(0, 300)}` });
  return json({ added: add.length, errors });
});
