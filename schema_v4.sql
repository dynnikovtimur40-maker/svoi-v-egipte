-- «Свои в Египте» — v4: проверка пользователей (Telegram), продвижение и оплата (Paymob),
-- автопроверка объявлений, язык профиля для писем.
-- Выполнить один раз в Supabase → SQL Editor (после v2 и v3).

-- ===== Язык пользователя (для писем и бота) =====
alter table public.profiles add column if not exists lang text not null default 'ru';

-- ===== Продвижение объявлений =====
alter table public.posts add column if not exists bumped_at timestamptz;
update public.posts set bumped_at = created_at where bumped_at is null;
alter table public.posts alter column bumped_at set default now();
alter table public.posts add column if not exists vip_until timestamptz;
alter table public.posts add column if not exists highlight_until timestamptz;
alter table public.posts add column if not exists auto_flags text;
create index if not exists posts_bumped_idx on public.posts (status, bumped_at desc);

create table if not exists public.products (
  code text primary key,
  title text not null,
  price_egp int not null check (price_egp > 0),
  days int not null default 0,
  active boolean not null default true
);
insert into public.products (code, title, price_egp, days) values
  ('bump', 'Поднять наверх', 50, 0),
  ('highlight', 'Выделение цветом на 7 дней', 100, 7),
  ('vip', 'VIP на 7 дней', 250, 7)
on conflict (code) do nothing;
alter table public.products enable row level security;
drop policy if exists "products: все читают" on public.products;
create policy "products: все читают" on public.products for select using (true);
drop policy if exists "products: админ меняет" on public.products;
create policy "products: админ меняет" on public.products for update using (public.is_admin()) with check (public.is_admin());

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid references public.posts(id) on delete set null,
  product text not null references public.products(code),
  amount_egp int not null,
  status text not null default 'new' check (status in ('new','paid','failed','free')),
  provider_ref text,
  created_at timestamptz not null default now(),
  paid_at timestamptz
);
alter table public.payments enable row level security;
drop policy if exists "payments: свои и админ" on public.payments;
create policy "payments: свои и админ" on public.payments for select using (auth.uid() = user_id or public.is_admin());
-- Записи о платежах создаёт только сервер (функция payments), клиент не может.

-- Применить услугу к объявлению. Вызывается сервером после оплаты или админом.
create or replace function public.apply_promotion(p_post uuid, p_product text) returns void
language plpgsql security definer set search_path = public as $$
declare d int;
begin
  select days into d from public.products where code = p_product;
  if d is null then raise exception 'Нет такой услуги'; end if;
  perform set_config('app.promo', 'on', true);
  if p_product = 'bump' then
    update public.posts set bumped_at = now() where id = p_post;
  elsif p_product = 'highlight' then
    update public.posts set bumped_at = now(),
      highlight_until = greatest(coalesce(highlight_until, now()), now()) + make_interval(days => d) where id = p_post;
  elsif p_product = 'vip' then
    update public.posts set bumped_at = now(),
      vip_until = greatest(coalesce(vip_until, now()), now()) + make_interval(days => d) where id = p_post;
  end if;
  perform set_config('app.promo', 'off', true);
end; $$;
revoke execute on function public.apply_promotion(uuid, text) from public, anon, authenticated;
grant execute on function public.apply_promotion(uuid, text) to service_role;

-- Администратор может выдать услугу бесплатно (тест, бонус, компенсация).
create or replace function public.admin_promote(p_post uuid, p_product text) returns void
language plpgsql security definer set search_path = public as $$
declare u uuid; price int;
begin
  if not public.is_admin() then raise exception 'Только для администратора' using errcode = 'P0001'; end if;
  select user_id into u from public.posts where id = p_post;
  select price_egp into price from public.products where code = p_product;
  insert into public.payments (user_id, post_id, product, amount_egp, status, paid_at)
    values (u, p_post, p_product, coalesce(price, 0), 'free', now());
  perform public.apply_promotion(p_post, p_product);
end; $$;

-- ===== Проверка пользователей через Telegram-бота =====
create table if not exists public.verifications (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  code text not null unique,
  status text not null default 'new' check (status in ('new','sent','approved','rejected')),
  tg_chat_id bigint,
  tg_username text,
  photos int not null default 0,
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.verifications enable row level security;
drop policy if exists "verifications: свои и админ" on public.verifications;
create policy "verifications: свои и админ" on public.verifications for select
  using (auth.uid() = user_id or public.is_admin());

-- Выдаёт код для бота (одна открытая заявка на человека).
create or replace function public.start_verification() returns text
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); c text;
begin
  if uid is null then raise exception 'Нужно войти' using errcode = 'P0001'; end if;
  if exists (select 1 from public.profiles where id = uid and verified) then
    raise exception 'Ваш профиль уже проверен' using errcode = 'P0001';
  end if;
  select code into c from public.verifications
    where user_id = uid and status in ('new','sent') order by id desc limit 1;
  if c is null then
    c := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8));
    insert into public.verifications (user_id, code) values (uid, c);
  end if;
  return c;
end; $$;

-- Решение администратора из приложения (в Telegram — кнопками в боте).
create or replace function public.admin_verify(p_user uuid, p_ok boolean, p_reason text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Только для администратора' using errcode = 'P0001'; end if;
  update public.profiles set verified = p_ok where id = p_user;
  update public.verifications
    set status = case when p_ok then 'approved' else 'rejected' end, reason = p_reason, updated_at = now()
    where user_id = p_user and status in ('new','sent');
end; $$;

-- ===== Автопроверка объявлений =====
-- Надёжный автор: проверен, есть одобренные объявления, нет блокировок за 30 дней.
create or replace function public.is_trusted(uid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select verified from public.profiles where id = uid), false)
    and exists (select 1 from public.posts where user_id = uid and status in ('active','closed'))
    and not exists (select 1 from public.posts where user_id = uid and status = 'blocked'
                    and created_at > now() - interval '30 days');
$$;

create or replace function public.posts_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  body text := lower(coalesce(new.title, '') || ' ' || coalesce(new.description, ''));
  cnt int;
  admin boolean := public.is_admin();
  promo boolean := coalesce(current_setting('app.promo', true), '') = 'on';
  flags text[] := '{}';
  content_changed boolean;
begin
  if promo then return new; end if;

  -- Поля продвижения меняет только сервер после оплаты или администратор
  if not admin then
    if tg_op = 'INSERT' then
      new.bumped_at := now(); new.vip_until := null; new.highlight_until := null;
    else
      new.bumped_at := old.bumped_at; new.vip_until := old.vip_until; new.highlight_until := old.highlight_until;
    end if;
  end if;

  -- Запрещённые темы (русский, украинский, английский, арабский)
  if body ~ '(казино|casino|1xbet|букмекер|ставки на спорт|betting|порно|porn|xxx|эскорт|escort|интим|секс|sex |наркот|закладк|мефедрон|гашиш|cocaine|кокаин|onlyfans|быстрый заработок|заработок без вложений|пирамид[аы] заработ|форекс сигнал|كازينو|قمار|مراهنات|إباحي|اباحي|مخدرات|حشيش)' then
    raise exception 'Объявление нарушает правила сервиса (запрещённая тема)' using errcode = 'P0001';
  end if;
  if body ~ '(https?://|www\.|\.com\b|\.ru\b|bit\.ly)' then
    raise exception 'Ссылки в тексте объявления запрещены — укажите контакт в поле «Контакты»' using errcode = 'P0001';
  end if;
  if not (new.contact ~ '\+?\d{10,15}' or new.contact ~ '@[A-Za-z][A-Za-z0-9_]{4,31}') then
    raise exception 'Укажите настоящий номер телефона или Telegram (@username)' using errcode = 'P0001';
  end if;

  -- Подозрительные признаки — объявление пойдёт к модератору с пометкой
  if body ~ '(предоплат|передоплат|prepay|western union|usdt|bitcoin|биткоин|крипт|crypto|инвестиц|investment|гарантированн|100% доход)' then
    flags := flags || 'предоплата/крипта/инвестиции';
  end if;
  if coalesce(new.title, '') ~ '[A-ZА-ЯЁ]{10,}' or body ~ '(.)\1{6,}' then
    flags := flags || 'капс/повторы';
  end if;
  if new.price_egp is not null and new.price_egp > 50000000 then
    flags := flags || 'странная цена';
  end if;

  if tg_op = 'INSERT' then
    if not admin then
      select count(*) into cnt from public.posts
        where user_id = new.user_id and created_at > now() - interval '24 hours';
      if cnt >= 5 then
        raise exception 'Не больше 5 объявлений в сутки. Попробуйте завтра.' using errcode = 'P0001';
      end if;
      if exists (select 1 from public.posts where user_id = new.user_id and status <> 'blocked'
                 and lower(title) = lower(new.title) and created_at > now() - interval '7 days') then
        raise exception 'Такое объявление у вас уже есть. Поднимите или измените старое.' using errcode = 'P0001';
      end if;
      new.reject_reason := null;
      if cardinality(flags) = 0 and public.is_trusted(new.user_id) then
        new.status := 'active';
        new.auto_flags := null;
      else
        new.status := 'pending';
        new.auto_flags := nullif(array_to_string(flags, ', '), '');
      end if;
    end if;
  elsif not admin then
    content_changed := new.title is distinct from old.title or new.description is distinct from old.description
        or new.photos is distinct from old.photos or new.contact is distinct from old.contact
        or new.price_egp is distinct from old.price_egp;
    -- автор правит содержимое или возвращает объявление — снова проверка (надёжным — автоматически)
    if new.status = 'active' and (old.status <> 'active' or content_changed) then
      if cardinality(flags) = 0 and public.is_trusted(new.user_id) then
        new.status := 'active';
      else
        new.status := 'pending';
      end if;
      new.auto_flags := nullif(array_to_string(flags, ', '), '');
    end if;
    if old.status = 'blocked' then
      new.status := 'blocked';
    end if;
    new.reject_reason := case when new.status = 'pending' then null else old.reject_reason end;
  end if;
  return new;
end; $$;
drop trigger if exists posts_guard on public.posts;
create trigger posts_guard before insert or update on public.posts for each row execute function public.posts_guard();

select 'v4 ok' as result;
