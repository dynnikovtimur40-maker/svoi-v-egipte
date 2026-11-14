-- «Свои в Египте» — v6: уведомления в Telegram, подписки на поиск, блокировка нарушителей,
-- новости из админки, статистика, удаление аккаунта, мгновенный чат.

alter table public.profiles add column if not exists notify_tg boolean not null default true;
alter table public.profiles add column if not exists banned boolean not null default false;

-- Нельзя самому снять бан
drop policy if exists "profiles: свой меняю" on public.profiles;
create policy "profiles: свой меняю" on public.profiles for update using (auth.uid() = id)
  with check (
    auth.uid() = id
    and verified = (select p.verified from public.profiles p where p.id = auth.uid())
    and role = (select p.role from public.profiles p where p.id = auth.uid())
    and banned = (select p.banned from public.profiles p where p.id = auth.uid())
    and tg_id is not distinct from (select p.tg_id from public.profiles p where p.id = auth.uid())
    and tg_username is not distinct from (select p.tg_username from public.profiles p where p.id = auth.uid())
  );

create or replace function public.is_banned(uid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select banned from public.profiles where id = uid), false);
$$;

-- ===== Блокировка нарушителя администратором =====
create or replace function public.admin_ban(p_user uuid, p_ban boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Только для администратора' using errcode = 'P0001'; end if;
  if p_user = auth.uid() then raise exception 'Нельзя заблокировать себя' using errcode = 'P0001'; end if;
  update public.profiles set banned = p_ban where id = p_user;
  if p_ban then
    perform set_config('app.promo', 'on', true);
    update public.posts set status = 'blocked', reject_reason = 'Аккаунт заблокирован за нарушения'
      where user_id = p_user and status in ('active', 'pending');
    perform set_config('app.promo', 'off', true);
  end if;
end; $$;

-- Заблокированный не публикует и не пишет
create or replace function public.banned_guard_posts() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_setting('app.promo', true), '') = 'on' or coalesce(auth.role(), '') = 'service_role' then
    return new;
  end if;
  if public.is_banned(new.user_id) then
    raise exception 'Ваш аккаунт заблокирован за нарушение правил.' using errcode = 'P0001';
  end if;
  return new;
end; $$;
create or replace function public.banned_guard_messages() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if public.is_banned(new.sender_id) then
    raise exception 'Ваш аккаунт заблокирован за нарушение правил.' using errcode = 'P0001';
  end if;
  return new;
end; $$;
drop trigger if exists a_banned_guard on public.posts;
create trigger a_banned_guard before insert or update on public.posts for each row execute function public.banned_guard_posts();
drop trigger if exists a_banned_guard on public.messages;
create trigger a_banned_guard before insert on public.messages for each row execute function public.banned_guard_messages();

-- ===== Новости (пишет администратор) =====
create table if not exists public.news (
  id bigint generated always as identity primary key,
  tag text not null default 'Важно',
  title text not null check (char_length(title) between 3 and 200),
  body text not null default '',
  published boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.news enable row level security;
drop policy if exists "news: все читают" on public.news;
create policy "news: все читают" on public.news for select using (published or public.is_admin());
drop policy if exists "news: админ пишет" on public.news;
create policy "news: админ пишет" on public.news for all using (public.is_admin()) with check (public.is_admin());

insert into public.news (tag, title, body)
select * from (values
  ('Безопасность', 'Как не попасться мошенникам при аренде',
   'Не переводите предоплату до просмотра квартиры и встречи с хозяином. Попросите показать документы на квартиру и паспорт собственника. Договор составляйте письменно, с суммой депозита и сроками. Выбирайте людей с отметкой «Проверен» и смотрите отзывы — их оставляют только после настоящей сделки.'),
  ('Визы', 'Продление пребывания в Египте',
   'Туристическую визу продлевают в паспортно-визовых отделах (в Каире — комплекс Аббасия, в Хургаде и Шарме — местные отделы). Обычно нужны паспорт, копии страниц, фото и договор аренды или бронь отеля. Требования и сборы меняются — уточняйте перед визитом и спрашивайте у своих в разделе «Услуги → Визы и документы».'),
  ('Сервис', 'Как работает «Свои в Египте»',
   'Объявления проходят автоматическую проверку и сразу появляются в ленте; подозрительные смотрит модератор. Подтвердите Telegram в профиле — получите отметку «Проверен» и уведомления о новых сообщениях. Подпишитесь на поиск — бот пришлёт новые подходящие объявления.')
) v(tag, title, body)
where not exists (select 1 from public.news);

-- ===== Подписки на поиск =====
create table if not exists public.saved_searches (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  section text not null,
  category text,
  city text,
  query text not null default '',
  price_max int,
  created_at timestamptz not null default now()
);
alter table public.saved_searches enable row level security;
drop policy if exists "saved: свои" on public.saved_searches;
create policy "saved: свои" on public.saved_searches for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace function public.saved_limit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.saved_searches where user_id = new.user_id) >= 10 then
    raise exception 'Не больше 10 подписок. Удалите ненужные в профиле.' using errcode = 'P0001';
  end if;
  return new;
end; $$;
drop trigger if exists saved_limit on public.saved_searches;
create trigger saved_limit before insert on public.saved_searches for each row execute function public.saved_limit();

-- ===== Уведомления через бота: новые сообщения и новые объявления по подпискам =====
create or replace function public.notify_message() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- не чаще одного уведомления в минуту от одного собеседника
  if exists (select 1 from public.messages where sender_id = new.sender_id and receiver_id = new.receiver_id
             and id <> new.id and created_at > now() - interval '1 minute') then
    return new;
  end if;
  perform net.http_post(
    url := 'https://pjjeypdxwnbtyqabhroi.supabase.co/functions/v1/tg-bot?notify=message',
    body := jsonb_build_object('message_id', new.id),
    headers := '{"Content-Type": "application/json"}'::jsonb);
  return new;
end; $$;
drop trigger if exists notify_message on public.messages;
create trigger notify_message after insert on public.messages for each row execute function public.notify_message();

create or replace function public.notify_match() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'active' and (tg_op = 'INSERT' or old.status is distinct from 'active') then
    perform net.http_post(
      url := 'https://pjjeypdxwnbtyqabhroi.supabase.co/functions/v1/tg-bot?notify=match',
      body := jsonb_build_object('post_id', new.id),
      headers := '{"Content-Type": "application/json"}'::jsonb);
  end if;
  return new;
end; $$;
drop trigger if exists notify_match on public.posts;
create trigger notify_match after insert or update of status on public.posts for each row execute function public.notify_match();

-- ===== Статистика для администратора =====
create or replace function public.admin_stats() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Только для администратора' using errcode = 'P0001'; end if;
  return jsonb_build_object(
    'users', (select count(*) from public.profiles),
    'users_7d', (select count(*) from public.profiles where created_at > now() - interval '7 days'),
    'online', (select count(*) from public.profiles where last_seen > now() - interval '5 minutes'),
    'verified', (select count(*) from public.profiles where verified),
    'posts_active', (select count(*) from public.posts where status = 'active'),
    'posts_pending', (select count(*) from public.posts where status = 'pending'),
    'posts_7d', (select count(*) from public.posts where created_at > now() - interval '7 days'),
    'messages_24h', (select count(*) from public.messages where created_at > now() - interval '24 hours'),
    'views', (select coalesce(sum(views), 0) from public.posts),
    'deals', (select count(*) from public.deals),
    'reviews', (select count(*) from public.reviews where deal_id is not null),
    'banned', (select count(*) from public.profiles where banned)
  );
end; $$;

-- ===== Удаление своего аккаунта со всеми данными =====
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public, auth as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Нужно войти' using errcode = 'P0001'; end if;
  delete from auth.users where id = uid; -- профиль, объявления, сообщения, отзывы удаляются каскадом
end; $$;
revoke execute on function public.delete_my_account() from anon;

-- ===== Мгновенный чат: изменения сообщений в реальном времени =====
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'messages') then
    alter publication supabase_realtime add table public.messages;
  end if;
end $$;

-- Поиск по объявлениям на сервере
create index if not exists posts_search_idx on public.posts using gin (to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(description, '')));

select 'v6 ok' as result, (select count(*) from public.news) as news;
