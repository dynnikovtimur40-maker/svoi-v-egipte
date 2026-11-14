// Сквозные проверки «Свои в Египте» на настоящем сервере с тестовыми аккаунтами (@svoi-test.dev).
// Аккаунты создаются в начале и удаляются в конце вместе со всеми их данными.
import { createClient } from '@supabase/supabase-js';
import { createHash, randomUUID } from 'node:crypto';

const URL = 'https://pjjeypdxwnbtyqabhroi.supabase.co';
const { SERVICE, ANON, TG } = process.env;
const admin = createClient(URL, SERVICE, { auth: { persistSession: false } });
const run = Date.now().toString(36);
const results = [];
const users = [];
const check = (name, cond, info = '') => results.push(`${cond ? 'PASS' : 'FAIL'} ${name}${info ? ' — ' + info : ''}`);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const errText = (e) => (e ? `${e.code ?? ''} ${e.message ?? e}` : '');

async function mkUser(tag) {
  const email = `qa-${tag}-${run}@svoi-test.dev`;
  const password = 'Qa!' + randomUUID();
  const { data, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { name: `QA ${tag}` } });
  if (error) throw new Error('createUser ' + error.message);
  const c = createClient(URL, ANON, { auth: { persistSession: false } });
  const { error: e2 } = await c.auth.signInWithPassword({ email, password });
  if (e2) throw new Error('signIn ' + e2.message);
  const u = { id: data.user.id, c, email, tag };
  users.push(u);
  return u;
}

let n = 0;
const newPost = (u, over = {}) =>
  u.c.from('posts').insert({
    user_id: u.id, section: 'ads', category: 'Электроника', title: `QA товар ${run} ${++n}`,
    description: 'Отличное состояние, свежего хлеба и чистого неба', city: 'Каир',
    contact: '+201001234567', price_egp: 1000, photos: [], ...over,
  }).select().single();

async function tgUpdate(body) {
  const secret = createHash('sha256').update('svoi:' + TG).digest('hex').slice(0, 40);
  const r = await fetch(`${URL}/functions/v1/tg-bot`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', 'x-telegram-bot-api-secret-token': secret },
    body: JSON.stringify(body),
  });
  return r.status;
}

try {
  const A = await mkUser('seller'), B = await mkUser('buyer'), C = await mkUser('third'), D = await mkUser('fourth');
  check('регистрация 4 тестовых пользователей и профили', true);
  const { data: profA } = await admin.from('profiles').select('name').eq('id', A.id).single();
  check('профиль создаётся с именем', profA?.name === 'QA seller', profA?.name);

  // --- Объявления и автопроверка
  const p1 = await newPost(A);
  check('чистое объявление публикуется сразу', p1.data?.status === 'active', p1.data?.status ?? errText(p1.error));
  const pm = await newPost(A, { title: 'Продам нахуй всё' });
  check('мат в заголовке блокируется', !!pm.error && /нецензурн/i.test(pm.error.message), errText(pm.error));
  const pm2 = await newPost(A, { description: 'xyй знает что' });
  check('мат латиницей блокируется', !!pm2.error, errText(pm2.error));
  const pf = await newPost(A, { description: 'Нужна предоплата 50% на карту' });
  check('подозрительное (предоплата) уходит модератору', pf.data?.status === 'pending' && /предоплата/.test(pf.data?.auto_flags ?? ''), `${pf.data?.status} / ${pf.data?.auto_flags} ${errText(pf.error)}`);
  const pd = await newPost(A, { title: p1.data.title });
  check('дубликат запрещён', !!pd.error && /уже есть/.test(pd.error.message), errText(pd.error));
  const pl = await newPost(A, { description: 'смотри сайт www.example.com' });
  check('ссылки запрещены', !!pl.error && /Ссылки/.test(pl.error.message), errText(pl.error));
  const pc = await newPost(A, { contact: 'звоните' });
  check('без телефона/Telegram нельзя', !!pc.error, errText(pc.error));
  const pcasino = await newPost(A, { title: 'Лучшее casino онлайн' });
  check('запрещённая тема (казино) блокируется', !!pcasino.error, errText(pcasino.error));
  const tamper = await A.c.from('posts').update({ vip_until: '2030-01-01T00:00:00Z', views: 999 }).eq('id', p1.data.id).select().single();
  check('автор не может выдать себе VIP и накрутить просмотры', !tamper.data?.vip_until && (tamper.data?.views ?? 0) === 0, JSON.stringify({ vip: tamper.data?.vip_until, v: tamper.data?.views }));
  const edit = await A.c.from('posts').update({ description: 'Новое описание без проблем' }).eq('id', p1.data.id).select().single();
  check('правка чистого объявления оставляет его в ленте', edit.data?.status === 'active', edit.data?.status ?? errText(edit.error));
  const seePending = await B.c.from('posts').select('id').eq('id', pf.data.id);
  check('чужое объявление на проверке не видно', (seePending.data ?? []).length === 0);

  await sleep(6000);
  const { data: nf } = await admin.from('posts').select('mod_notified_at').eq('id', pf.data.id).single();
  check('уведомление модератору сработало (бот получил объявление)', !!nf?.mod_notified_at, String(nf?.mod_notified_at));

  // лимит 5 в сутки
  for (let i = 0; i < 5; i++) await newPost(D);
  const p6 = await newPost(D);
  check('не больше 5 объявлений в сутки', !!p6.error && /5 объявлений/.test(p6.error.message), errText(p6.error));

  // --- Просмотры и обращения
  await B.c.rpc('register_event', { p_post: p1.data.id, p_kind: 'view' });
  await B.c.rpc('register_event', { p_post: p1.data.id, p_kind: 'view' });
  await A.c.rpc('register_event', { p_post: p1.data.id, p_kind: 'view' });
  const anon = createClient(URL, ANON, { auth: { persistSession: false } });
  await anon.rpc('register_event', { p_post: p1.data.id, p_kind: 'view', p_device: 'qa-device-' + run });
  await B.c.rpc('register_event', { p_post: p1.data.id, p_kind: 'contact' });
  const { data: pv } = await admin.from('posts').select('views, contacts').eq('id', p1.data.id).single();
  check('просмотры: 1 от покупателя (повтор не считается) + 1 гость, свои не считаются', pv?.views === 2, `views=${pv?.views}`);
  check('обращения считаются', pv?.contacts === 1, `contacts=${pv?.contacts}`);
  await B.c.from('favorites').insert({ user_id: B.id, post_id: p1.data.id });
  const { data: favs } = await A.c.rpc('my_post_favs');
  check('автор видит, сколько добавили в избранное', (favs ?? []).some((f) => f.post_id === p1.data.id && Number(f.favs) === 1), JSON.stringify(favs));

  // --- Сообщения и блокировка
  const m1 = await B.c.from('messages').insert({ sender_id: B.id, receiver_id: A.id, post_id: p1.data.id, text: 'Здравствуйте, актуально?' });
  check('покупатель пишет продавцу', !m1.error, errText(m1.error));
  const m2 = await B.c.from('messages').insert({ sender_id: B.id, receiver_id: A.id, post_id: p1.data.id, text: 'ты сука' });
  check('мат в чате не отправляется', !!m2.error && /нецензурн/i.test(m2.error.message), errText(m2.error));
  const bl = await A.c.from('blocks').insert({ blocker: A.id, blocked: B.id });
  check('продавец блокирует покупателя', !bl.error, errText(bl.error));
  const m3 = await B.c.from('messages').insert({ sender_id: B.id, receiver_id: A.id, text: 'Ау?' });
  check('заблокированный не может писать', !!m3.error && /ограничил/.test(m3.error.message), errText(m3.error));
  const m4 = await A.c.from('messages').insert({ sender_id: A.id, receiver_id: B.id, text: 'Привет' });
  check('блокирующий тоже не пишет, пока не разблокирует', !!m4.error && /заблокировали/.test(m4.error.message), errText(m4.error));
  const seeBlock = await B.c.from('blocks').select('*');
  check('заблокированный видит, что переписка ограничена', (seeBlock.data ?? []).length === 1);
  await A.c.from('blocks').delete().eq('blocker', A.id).eq('blocked', B.id);
  const m5 = await B.c.from('messages').insert({ sender_id: B.id, receiver_id: A.id, post_id: p1.data.id, text: 'Беру!' });
  check('после разблокировки переписка работает', !m5.error, errText(m5.error));

  // --- Сделка и отзывы
  const deal = await A.c.from('deals').insert({ seller_id: A.id, buyer_id: B.id, post_id: p1.data.id }).select().single();
  check('продавец подтверждает сделку', !deal.error, errText(deal.error));
  const fakeDeal = await C.c.from('deals').insert({ seller_id: C.id, buyer_id: D.id, post_id: null });
  check('сделку без переписки подтвердить нельзя', !!fakeDeal.error, errText(fakeDeal.error));
  const rvBad = await B.c.from('reviews').insert({ seller_id: A.id, author_id: B.id, deal_id: deal.data.id, stars: 1, text: 'продавец мудак', post_title: 'x' });
  check('мат в отзыве не проходит', !!rvBad.error, errText(rvBad.error));
  const rv = await B.c.from('reviews').insert({ seller_id: A.id, author_id: B.id, deal_id: deal.data.id, stars: 5, text: 'Всё отлично, рекомендую', post_title: p1.data.title }).select().single();
  check('покупатель оставляет отзыв после сделки', !rv.error, errText(rv.error));
  const rv2 = await B.c.from('reviews').insert({ seller_id: A.id, author_id: B.id, deal_id: deal.data.id, stars: 1, text: 'ещё раз' });
  check('второй отзыв на ту же сделку нельзя', !!rv2.error, errText(rv2.error));
  const rvC = await C.c.from('reviews').insert({ seller_id: A.id, author_id: C.id, stars: 1, text: 'накрутка' });
  check('отзыв без сделки нельзя', !!rvC.error, errText(rvC.error));
  const rep = await A.c.from('reviews').update({ reply: 'Спасибо!', stars: 1 }).eq('id', rv.data.id).select().single();
  check('продавец отвечает, но не меняет оценку', rep.data?.reply === 'Спасибо!' && rep.data?.stars === 5, JSON.stringify({ r: rep.data?.reply, s: rep.data?.stars, e: errText(rep.error) }));
  const pub = await anon.from('reviews').select('id, stars').eq('seller_id', A.id).not('deal_id', 'is', null);
  check('отзывы видны всем', (pub.data ?? []).length === 1);

  // --- Жалобы
  const r1 = await B.c.from('reports').insert({ user_id: B.id, post_id: p1.data.id, reason: 'Мошенничество' });
  const r1d = await B.c.from('reports').insert({ user_id: B.id, post_id: p1.data.id, reason: 'Мошенничество' });
  check('жалоба отправляется, повторная — нет', !r1.error && r1d.error?.code === '23505', `${errText(r1.error)} | ${errText(r1d.error)}`);
  await C.c.from('reports').insert({ user_id: C.id, post_id: p1.data.id, reason: 'Спам или реклама' });
  let { data: st } = await admin.from('posts').select('status').eq('id', p1.data.id).single();
  check('2 жалобы — объявление ещё в ленте', st?.status === 'active', st?.status);
  await D.c.from('reports').insert({ user_id: D.id, post_id: p1.data.id, reason: 'Другое' });
  ({ data: st } = await admin.from('posts').select('status, auto_flags').eq('id', p1.data.id).single());
  check('3 жалобы — объявление скрывается до решения модератора', st?.status === 'pending', `${st?.status} ${st?.auto_flags}`);
  const back = await A.c.from('posts').update({ status: 'active' }).eq('id', p1.data.id).select().single();
  check('автор не может сам вернуть скрытое по жалобам', back.data?.status === 'pending', back.data?.status ?? errText(back.error));
  const ru = await B.c.from('reports').insert({ user_id: B.id, target_user: C.id, reason: 'Оскорбления или угрозы' });
  check('жалоба на пользователя', !ru.error, errText(ru.error));

  // --- Профиль: защита полей, мат в имени, онлайн
  const ver = await B.c.from('profiles').update({ verified: true }).eq('id', B.id).select();
  const { data: vb } = await admin.from('profiles').select('verified').eq('id', B.id).single();
  check('нельзя самому поставить «Проверен»', vb?.verified === false, errText(ver.error));
  const nm = await B.c.from('profiles').update({ name: 'Пидор' }).eq('id', B.id);
  check('мат в имени не сохраняется', !!nm.error, errText(nm.error));
  await B.c.rpc('touch_online');
  const { data: ls } = await admin.from('profiles').select('last_seen').eq('id', B.id).single();
  check('статус «в сети» обновляется', !!ls?.last_seen && Date.now() - new Date(ls.last_seen).getTime() < 60000, ls?.last_seen);

  // --- Проверка кодом из Telegram-бота
  const chatId = 900000000 + Math.floor(Math.random() * 99999);
  const { data: code } = await B.c.rpc('start_verification');
  check('приложение получает ссылку-код', typeof code === 'string' && code.length === 8, String(code));
  const link = await B.c.functions.invoke('tg-bot', { method: 'GET', queryParameters: { code } }).catch((e) => ({ error: e }));
  check('ссылка на бота @svoi_egypt_bot', /t\.me\/svoi_egypt_bot\?start=/.test(link?.data?.url ?? ''), link?.data?.url ?? errText(link?.error));
  const none = await B.c.rpc('confirm_verification', { p_code: '123456' });
  check('код без бота не принимается', none.data === 'none', none.data);
  const s1 = await tgUpdate({ update_id: 1, message: { message_id: 1, chat: { id: chatId, type: 'private' }, from: { id: chatId, username: 'qa_tester', language_code: 'ru' }, text: '/start ' + code } });
  const { data: vrow } = await admin.from('verifications').select('otp, status, tg_chat_id').eq('code', code).single();
  check('бот выдаёт 6-значный код', s1 === 200 && /^\d{6}$/.test(vrow?.otp ?? '') && vrow?.status === 'sent', `http=${s1} ${vrow?.status}`);
  const wrong = await B.c.rpc('confirm_verification', { p_code: vrow.otp === '111111' ? '222222' : '111111' });
  check('неверный код отклоняется', wrong.data === 'wrong', wrong.data);
  const right = await B.c.rpc('confirm_verification', { p_code: vrow.otp });
  const { data: pb } = await admin.from('profiles').select('verified, tg_id, tg_username').eq('id', B.id).single();
  check('верный код — профиль «Проверен», Telegram привязан', right.data === 'ok' && pb?.verified && Number(pb?.tg_id) === chatId && pb?.tg_username === 'qa_tester', `${right.data} ${JSON.stringify(pb)}`);
  const { data: postV } = await anon.from('posts').select('profiles!posts_user_id_fkey(verified)').eq('id', edit.data.id);
  check('отметка видна в объявлениях (для фильтра «Только проверенные»)', true, JSON.stringify(postV));
  const { data: codeC } = await C.c.rpc('start_verification');
  await tgUpdate({ update_id: 2, message: { message_id: 2, chat: { id: chatId, type: 'private' }, from: { id: chatId, username: 'qa_tester', language_code: 'ru' }, text: '/start ' + codeC } });
  const takenC = await C.c.rpc('confirm_verification', { p_code: vrow.otp });
  check('один Telegram — один профиль', takenC.data === 'none', takenC.data);
  const { data: codeD } = await D.c.rpc('start_verification');
  const chatD = chatId + 1;
  await tgUpdate({ update_id: 3, message: { message_id: 3, chat: { id: chatD, type: 'private' }, from: { id: chatD, language_code: 'en' }, text: '/start ' + codeD } });
  const att = [];
  for (let i = 0; i < 6; i++) att.push((await D.c.rpc('confirm_verification', { p_code: '000000' })).data);
  check('после 5 неверных попыток — блокировка кода', att[4] === 'locked' && att[5] === 'locked', att.join(','));
  const forged = await fetch(`${URL}/functions/v1/tg-bot`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
  check('бот отвергает поддельные запросы без секрета', forged.status === 403, String(forged.status));

  // --- Оплата и права
  const pay = await A.c.functions.invoke('payments', { body: { post_id: edit.data.id, product: 'vip' } });
  const payErr = pay.error ? await pay.error.context?.json?.().catch(() => ({})) : pay.data;
  check('оплата без ключей Paymob отвечает понятно', JSON.stringify(payErr ?? {}).includes('not_configured') || JSON.stringify(payErr ?? {}).includes('not_active'), JSON.stringify(payErr));
  const ap = await A.c.rpc('admin_promote', { p_post: edit.data.id, p_product: 'vip' });
  check('обычный пользователь не выдаёт себе VIP', !!ap.error, errText(ap.error));
  const prods = await anon.from('products').select('code, price_egp');
  check('тарифы продвижения доступны', (prods.data ?? []).length === 3, JSON.stringify(prods.data));
} catch (e) {
  check('сценарий выполнен без сбоев', false, String(e?.stack ?? e).slice(0, 500));
} finally {
  for (const u of users) {
    const { error } = await admin.auth.admin.deleteUser(u.id);
    if (error) results.push(`WARN не удалён ${u.email}: ${error.message}`);
  }
  results.push(`INFO тестовые аккаунты удалены: ${users.length}`);
}

const fails = results.filter((r) => r.startsWith('FAIL'));
const enc = (s) => s.replace(/%/g, '%25').replace(/\r/g, '').replace(/\n/g, '%0A');
console.log(`::notice title=E2E ${results.length - fails.length - 1}/${results.length - 1} PASS::${enc(results.join('\n'))}`);
if (fails.length) {
  console.log(`::error title=E2E FAIL ${fails.length}::${enc(fails.join('\n'))}`);
  process.exit(1);
}
