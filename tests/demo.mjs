// Временное демо-объявление для проверки интерфейса. MODE=create | delete.
import { createClient } from '@supabase/supabase-js';
const URL = 'https://pjjeypdxwnbtyqabhroi.supabase.co';
const admin = createClient(URL, process.env.SERVICE, { auth: { persistSession: false } });
const mode = (process.env.MODE || 'create').trim();
const out = [];
async function findUser(email) {
  const { data } = await admin.auth.admin.listUsers({ perPage: 200 });
  return data.users.find((u) => u.email === email);
}
async function ensure(email, name) {
  let u = await findUser(email);
  if (!u) ({ data: { user: u } } = await admin.auth.admin.createUser({ email, password: crypto.randomUUID() + 'Aa1!', email_confirm: true, user_metadata: { name } }));
  return u;
}
if (mode === 'delete') {
  const { data } = await admin.auth.admin.listUsers({ perPage: 500 });
  for (const u of data.users.filter((x) => x.email?.startsWith('qa-demo-') && x.email.endsWith('@svoi-test.dev'))) {
    await admin.auth.admin.deleteUser(u.id);
    out.push('deleted ' + u.email);
  }
} else {
  const s = await ensure('qa-demo-seller@svoi-test.dev', 'Демо Продавец');
  const b = await ensure('qa-demo-buyer@svoi-test.dev', 'Демо Покупатель');
  await admin.from('profiles').update({ verified: true, tg_username: 'svoi_demo', phone: '+201001234567', city: 'Хургада', last_seen: new Date().toISOString() }).eq('id', s.id);
  const { data: post, error } = await admin.from('posts').insert({
    user_id: s.id, section: 'ads', category: 'Электроника', title: 'Демо: проверка интерфейса (будет удалено)',
    description: 'Тестовое объявление для проверки экранов. Будет удалено через несколько минут.', city: 'Хургада',
    contact: '+201001234567 · @svoi_demo', price_egp: 12500, photos: [], status: 'active', views: 37, contacts: 4,
  }).select().single();
  if (error) out.push('post error ' + error.message);
  await admin.from('messages').insert({ sender_id: b.id, receiver_id: s.id, post_id: post.id, text: 'Здравствуйте!' });
  const { data: deal } = await admin.from('deals').insert({ seller_id: s.id, buyer_id: b.id, post_id: post.id }).select().single();
  await admin.from('reviews').insert({ seller_id: s.id, author_id: b.id, deal_id: deal.id, stars: 5, text: 'Всё отлично, быстро договорились, рекомендую!', post_title: post.title, reply: 'Спасибо, обращайтесь!' });
  out.push('post ' + post.id);
}
console.log('::notice title=demo::' + out.join(' | '));
