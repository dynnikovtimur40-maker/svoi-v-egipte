-- «Свои в Египте» — v5: проверка кодом из Telegram-бота, мгновенная публикация чистых объявлений,
-- уведомления модератору в бот, фильтр мата, блокировки и жалобы на людей, просмотры, онлайн.

create extension if not exists pg_net;

-- ===== Профиль: Telegram и онлайн =====
alter table public.profiles add column if not exists tg_id bigint;
alter table public.profiles add column if not exists tg_username text;
alter table public.profiles add column if not exists last_seen timestamptz;
create unique index if not exists profiles_tg_unique on public.profiles (tg_id) where tg_id is not null;

-- Свои поля меняю сам, но не роль, отметку «Проверен» и привязанный Telegram
drop policy if exists "profiles: свой меняю" on public.profiles;
create policy "profiles: свой меняю" on public.profiles for update using (auth.uid() = id)
  with check (
    auth.uid() = id
    and verified = (select p.verified from public.profiles p where p.id = auth.uid())
    and role = (select p.role from public.profiles p where p.id = auth.uid())
    and tg_id is not distinct from (select p.tg_id from public.profiles p where p.id = auth.uid())
    and tg_username is not distinct from (select p.tg_username from public.profiles p where p.id = auth.uid())
  );

create or replace function public.touch_online() returns void
language sql security definer set search_path = public as $$
  update public.profiles set last_seen = now() where id = auth.uid();
$$;

-- ===== Нецензурные слова (русский, украинский, английский, арабский) =====
create or replace function public.has_profanity(t text) returns boolean
language plpgsql immutable as $$
declare s text; c text;
begin
  if t is null or t = '' then return false; end if;
  s := lower(t);
  -- латинские буквы, похожие на русские, — в кириллицу (х0й, xуй, eбать)
  c := translate(s, 'aeopcxyk0', 'аеорсхук0');
  c := replace(c, '0', 'о');
  c := replace(c, 'ё', 'е');
  if c ~ '(^|[^а-яa-z])(на|по|ни|о|за|от)?ху[йяюеи]' then return true; end if;
  if c ~ 'п[иеі]зд' then return true; end if;
  if c ~ '(^|[^а-яa-z])(за|на|вы|у|до|от|отъ|про|по|подъ|съ|въ|раз|разъ|об|объ|при)?еб(а|у|л|н|ну|и|ет|ут)' then return true; end if;
  if c ~ 'долбо[её]б|уеб[аои]' then return true; end if;
  if c ~ '(^|[^а-яa-z])бля(д|т|[^а-яa-z]|$)' then return true; end if;
  if c ~ '(^|[^а-яa-z])сук(а|и|е|у|ой|ам)([^а-яa-z]|$)' then return true; end if;
  if c ~ '(^|[^а-яa-z])(муда[кч]|пид[оа]р|г[ао]ндон)|шлюх|залуп|дроч|мраз[ьи]' then return true; end if;
  if c ~ '(^|[^а-яa-z])манд(а|у|ой|е)([^а-яa-z]|$)' then return true; end if;
  if s ~ '(^|[^a-z])(fuck|shit|bitch|cunt|whore|motherfuck|asshole|dickhead)' then return true; end if;
  if s ~ '(شرموط|متناك|منيوك|كس ام|كسمك|عرص)' then return true; end if;
  return false;
end; $$;

-- ===== Проверка кодом из бота =====
alter table public.verifications add column if not exists otp text;
alter table public.verifications add column if not exists otp_expires timestamptz;
alter table public.verifications add column if not exists attempts int not null default 0;

-- Ввод кода из бота. Возвращает: ok, wrong, expired, locked, none, taken.
create or replace function public.confirm_verification(p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); v record;
begin
  if uid is null then return 'none'; end if;
  select * into v from public.verifications
    where user_id = uid and status = 'sent' order by id desc limit 1;
  if v.id is null or v.otp is null then return 'none'; end if;
  if v.attempts >= 5 then return 'locked'; end if;
  if v.otp_expires < now() then return 'expired'; end if;
  if trim(coalesce(p_code, '')) <> v.otp then
    update public.verifications set attempts = attempts + 1, updated_at = now() where id = v.id;
    return case when v.attempts + 1 >= 5 then 'locked' else 'wrong' end;
  end if;
  if exists (select 1 from public.profiles where tg_id = v.tg_chat_id and id <> uid) then
    return 'taken';
  end if;
  update public.profiles set verified = true, tg_id = v.tg_chat_id, tg_username = v.tg_username where id = uid;
  update public.verifications set status = 'approved', otp = null, updated_at = now() where id = v.id;
  return 'ok';
end; $$;

-- Админ: снять или поставить отметку вручную (при снятии отвязываем Telegram)
create or replace function public.admin_verify(p_user uuid, p_ok boolean, p_reason text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Только для администратора' using errcode = 'P0001'; end if;
  update public.profiles set verified = p_ok,
    tg_id = case when p_ok then tg_id else null end,
    tg_username = case when p_ok then tg_username else null end
    where id = p_user;
  update public.verifications
    set status = case when p_ok then 'approved' else 'rejected' end, reason = p_reason, updated_at = now()
    where id = (select max(id) from public.verifications where user_id = p_user);
end; $$;

-- ===== Блокировка пользователей =====
create table if not exists public.blocks (
  blocker uuid not null references public.profiles(id) on delete cascade,
  blocked uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);
alter table public.blocks enable row level security;
drop policy if exists "blocks: вижу свои" on public.blocks;
create policy "blocks: вижу свои" on public.blocks for select using (auth.uid() in (blocker, blocked));
drop policy if exists "blocks: блокирую" on public.blocks;
create policy "blocks: блокирую" on public.blocks for insert with check (auth.uid() = blocker);
drop policy if exists "blocks: разблокирую" on public.blocks;
create policy "blocks: разблокирую" on public.blocks for delete using (auth.uid() = blocker);

-- Сообщения: без мата, без рассылок, с учётом блокировок
create or replace function public.messages_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare cnt int;
begin
  if exists (select 1 from public.blocks where blocker = new.sender_id and blocked = new.receiver_id) then
    raise exception 'Вы заблокировали этого пользователя. Разблокируйте, чтобы написать.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.blocks where blocker = new.receiver_id and blocked = new.sender_id) then
    raise exception 'Пользователь ограничил вам отправку сообщений.' using errcode = 'P0001';
  end if;
  if public.has_profanity(new.text) then
    raise exception 'Сообщение содержит нецензурные слова.' using errcode = 'P0001';
  end if;
  select count(*) into cnt from public.messages where sender_id = new.sender_id and created_at > now() - interval '1 minute';
  if cnt >= 30 then
    raise exception 'Слишком много сообщений. Подождите минуту.' using errcode = 'P0001';
  end if;
  return new;
end; $$;

-- Отзывы и имена — тоже без мата
create or replace function public.reviews_text_guard() returns trigger
language plpgsql as $$
begin
  if public.has_profanity(new.text) or public.has_profanity(new.reply) then
    raise exception 'Уберите нецензурные слова.' using errcode = 'P0001';
  end if;
  return new;
end; $$;
drop trigger if exists reviews_text_guard on public.reviews;
create trigger reviews_text_guard before insert or update on public.reviews for each row execute function public.reviews_text_guard();

create or replace function public.profiles_text_guard() returns trigger
language plpgsql as $$
begin
  if public.has_profanity(new.name) then
    if tg_op = 'INSERT' then
      new.name := 'Пользователь';
    else
      raise exception 'Имя содержит недопустимые слова.' using errcode = 'P0001';
    end if;
  end if;
  return new;
end; $$;
drop trigger if exists profiles_text_guard on public.profiles;
create trigger profiles_text_guard before insert or update of name on public.profiles for each row execute function public.profiles_text_guard();

-- ===== Жалобы: на объявление или на пользователя, без повторов =====
alter table public.reports alter column post_id drop not null;
alter table public.reports add column if not exists target_user uuid references public.profiles(id) on delete cascade;
alter table public.reports drop constraint if exists reports_target_check;
alter table public.reports add constraint reports_target_check check (post_id is not null or target_user is not null);
delete from public.reports a using public.reports b
  where a.id > b.id and a.user_id = b.user_id and a.post_id is not distinct from b.post_id
    and a.target_user is not distinct from b.target_user;
create unique index if not exists reports_post_once on public.reports (user_id, post_id) where post_id is not null;
create unique index if not exists reports_user_once on public.reports (user_id, target_user) where post_id is null and target_user is not null;

-- ===== Просмотры и обращения =====
alter table public.posts add column if not exists views int not null default 0;
alter table public.posts add column if not exists contacts int not null default 0;
alter table public.posts add column if not exists mod_notified_at timestamptz;

create table if not exists public.post_events (
  post_id uuid not null references public.posts(id) on delete cascade,
  viewer text not null,
  kind text not null check (kind in ('view','contact')),
  day date not null default current_date,
  primary key (post_id, viewer, kind, day)
);
alter table public.post_events enable row level security;

-- Один просмотр (обращение) от человека в сутки; свои не считаются.
create or replace function public.register_event(p_post uuid, p_kind text, p_device text default '') returns void
language plpgsql security definer set search_path = public as $$
declare who text := coalesce(auth.uid()::text, 'anon:' || left(coalesce(p_device, ''), 64)); n int;
begin
  if p_kind not in ('view', 'contact') then return; end if;
  if who = 'anon:' then return; end if;
  if exists (select 1 from public.posts where id = p_post and user_id = auth.uid()) then return; end if;
  insert into public.post_events (post_id, viewer, kind) values (p_post, who, p_kind) on conflict do nothing;
  get diagnostics n = row_count;
  if n > 0 then
    perform set_config('app.promo', 'on', true);
    if p_kind = 'view' then
      update public.posts set views = views + 1 where id = p_post;
    else
      update public.posts set contacts = contacts + 1 where id = p_post;
    end if;
    perform set_config('app.promo', 'off', true);
  end if;
end; $$;

-- Статистика своих объявлений: сколько добавили в избранное
create or replace function public.my_post_favs() returns table (post_id uuid, favs bigint)
language sql stable security definer set search_path = public as $$
  select f.post_id, count(*) from public.favorites f
    join public.posts p on p.id = f.post_id
    where p.user_id = auth.uid() group by f.post_id;
$$;

-- ===== Объявления: чистые публикуются сразу, подозрительные — модератору =====
create or replace function public.posts_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  body text := lower(coalesce(new.title, '') || ' ' || coalesce(new.description, ''));
  cnt int;
  admin boolean := public.is_admin();
  flags text[] := '{}';
  content_changed boolean;
begin
  -- системные изменения (счётчики, оплата, сервер) и администратор
  if coalesce(current_setting('app.promo', true), '') = 'on' or coalesce(auth.role(), '') = 'service_role' then
    return new;
  end if;

  if not admin then
    if tg_op = 'INSERT' then
      new.bumped_at := now(); new.vip_until := null; new.highlight_until := null;
      new.views := 0; new.contacts := 0; new.mod_notified_at := null;
    else
      new.bumped_at := old.bumped_at; new.vip_until := old.vip_until; new.highlight_until := old.highlight_until;
      new.views := old.views; new.contacts := old.contacts; new.mod_notified_at := old.mod_notified_at;
    end if;
  end if;

  if tg_op = 'UPDATE' then
    content_changed := new.title is distinct from old.title or new.description is distinct from old.description
        or new.photos is distinct from old.photos or new.contact is distinct from old.contact
        or new.price_egp is distinct from old.price_egp;
  else
    content_changed := true;
  end if;

  if content_changed then
    if public.has_profanity(new.title) or public.has_profanity(new.description) then
      raise exception 'Уберите нецензурные слова из объявления.' using errcode = 'P0001';
    end if;
    if body ~ '(казино|casino|1xbet|букмекер|ставки на спорт|betting|порно|porn|xxx|эскорт|escort|интим|секс|sex |наркот|закладк|мефедрон|гашиш|cocaine|кокаин|onlyfans|быстрый заработок|заработок без вложений|пирамид[аы] заработ|форекс сигнал|كازينو|قمار|مراهنات|إباحي|اباحي|مخدرات|حشيش)' then
      raise exception 'Объявление нарушает правила сервиса (запрещённая тема)' using errcode = 'P0001';
    end if;
    if body ~ '(https?://|www\.|\.com\b|\.ru\b|bit\.ly|t\.me/)' then
      raise exception 'Ссылки в тексте объявления запрещены — укажите контакт в поле «Контакты»' using errcode = 'P0001';
    end if;
    if not (new.contact ~ '\+?\d{10,15}' or new.contact ~ '@[A-Za-z][A-Za-z0-9_]{4,31}') then
      raise exception 'Укажите настоящий номер телефона или Telegram (@username)' using errcode = 'P0001';
    end if;
  end if;

  -- признаки для модератора
  if body ~ '(предоплат|передоплат|prepay|western union|usdt|bitcoin|биткоин|крипт|crypto|инвестиц|investment|гарантированн|100% доход)' then
    flags := array_append(flags, 'предоплата/крипта/инвестиции');
  end if;
  if coalesce(new.title, '') ~ '[A-ZА-ЯЁ]{10,}' or body ~ '(.)\1{6,}' then
    flags := array_append(flags, 'капс/повторы');
  end if;
  if new.price_egp is not null and new.price_egp > 50000000 then
    flags := array_append(flags, 'странная цена');
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
      new.status := case when cardinality(flags) = 0 then 'active' else 'pending' end;
      new.auto_flags := nullif(array_to_string(flags, ', '), '');
    end if;
  elsif not admin then
    if new.status = 'active' and (old.status <> 'active' or content_changed) then
      new.status := case when cardinality(flags) = 0 then 'active' else 'pending' end;
      new.auto_flags := nullif(array_to_string(flags, ', '), '');
    end if;
    if old.status = 'blocked' then new.status := 'blocked'; end if;
    -- снятое модератором (pending после жалоб) автор сам не возвращает
    if old.status = 'pending' and new.status = 'active' and coalesce(old.auto_flags, '') like 'жалобы%' then
      new.status := 'pending';
    end if;
    new.reject_reason := case when new.status = 'pending' then null else old.reject_reason end;
  end if;
  return new;
end; $$;
drop trigger if exists posts_guard on public.posts;
create trigger posts_guard before insert or update on public.posts for each row execute function public.posts_guard();

-- Уведомление модератору в Telegram (через функцию tg-bot)
create or replace function public.notify_moderator() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'pending' and new.mod_notified_at is null and (tg_op = 'INSERT' or old.status is distinct from 'pending') then
    perform net.http_post(
      url := 'https://pjjeypdxwnbtyqabhroi.supabase.co/functions/v1/tg-bot?notify=post',
      body := jsonb_build_object('post_id', new.id),
      headers := '{"Content-Type": "application/json"}'::jsonb);
  end if;
  return new;
end; $$;
drop trigger if exists notify_moderator on public.posts;
create trigger notify_moderator after insert or update of status on public.posts for each row execute function public.notify_moderator();

-- Три жалобы от разных людей — объявление скрывается до решения модератора
create or replace function public.reports_after() returns trigger
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if new.post_id is not null then
    select count(distinct user_id) into n from public.reports where post_id = new.post_id;
    if n >= 3 then
      perform set_config('app.promo', 'on', true);
      update public.posts set status = 'pending', auto_flags = 'жалобы пользователей (' || n || ')'
        where id = new.post_id and status = 'active';
      perform set_config('app.promo', 'off', true);
    end if;
  end if;
  perform net.http_post(
    url := 'https://pjjeypdxwnbtyqabhroi.supabase.co/functions/v1/tg-bot?notify=report',
    body := jsonb_build_object('report_id', new.id),
    headers := '{"Content-Type": "application/json"}'::jsonb);
  return new;
end; $$;
drop trigger if exists reports_after on public.reports;
create trigger reports_after after insert on public.reports for each row execute function public.reports_after();

-- Объявление с матом, опубликованное до фильтра, — скрыть
do $$ begin
  perform set_config('app.promo', 'on', true);
  update public.posts set status = 'blocked', reject_reason = 'Нецензурная лексика'
    where status = 'active' and (public.has_profanity(title) or public.has_profanity(description));
  perform set_config('app.promo', 'off', true);
end $$;

select 'v5 ok' as result,
  (select count(*) from public.posts where status = 'blocked' and reject_reason = 'Нецензурная лексика') as hidden_profane;
