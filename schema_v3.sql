-- «Свои в Египте» — v3: модерация, защита от спама и ботов, администратор

-- Роль пользователя: user / admin
alter table public.profiles add column if not exists role text not null default 'user';
alter table public.posts add column if not exists reject_reason text;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- Пользователь не может сам выдать себе роль или «Проверен»
drop policy if exists "profiles: свой меняю" on public.profiles;
create policy "profiles: свой меняю" on public.profiles for update using (auth.uid() = id)
  with check (
    auth.uid() = id
    and verified = (select p.verified from public.profiles p where p.id = auth.uid())
    and role = (select p.role from public.profiles p where p.id = auth.uid())
  );
drop policy if exists "profiles: админ меняет" on public.profiles;
create policy "profiles: админ меняет" on public.profiles for update using (public.is_admin()) with check (public.is_admin());

-- Объявления: видны активные, свои — и все для администратора
drop policy if exists "posts: все читают активные" on public.posts;
create policy "posts: все читают активные" on public.posts for select
  using (status = 'active' or user_id = auth.uid() or public.is_admin());
drop policy if exists "posts: админ модерирует" on public.posts;
create policy "posts: админ модерирует" on public.posts for update using (public.is_admin()) with check (public.is_admin());
drop policy if exists "reports: админ читает" on public.reports;
create policy "reports: админ читает" on public.reports for select using (public.is_admin());
drop policy if exists "reports: админ удаляет" on public.reports;
create policy "reports: админ удаляет" on public.reports for delete using (public.is_admin());

-- Проверка объявления: запрещённое содержимое, ссылки, контакты, лимит в сутки, модерация
create or replace function public.posts_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  body text := lower(coalesce(new.title, '') || ' ' || coalesce(new.description, ''));
  cnt int;
  admin boolean := public.is_admin();
begin
  if body ~ '(казино|casino|1xbet|букмекер|ставки на спорт|порно|porn|xxx|эскорт|escort|интим|секс|sex |наркот|закладк|мефедрон|гашиш|onlyfans|быстрый заработок|заработок без вложений|пирамид[аы] заработ|форекс сигнал)' then
    raise exception 'Объявление нарушает правила сервиса (запрещённая тема)' using errcode = 'P0001';
  end if;
  if body ~ '(https?://|www\.|\.com\b|\.ru\b|bit\.ly)' then
    raise exception 'Ссылки в тексте объявления запрещены — укажите контакт в поле «Контакты»' using errcode = 'P0001';
  end if;
  if not (new.contact ~ '\+?\d{10,15}' or new.contact ~ '@[A-Za-z][A-Za-z0-9_]{4,31}') then
    raise exception 'Укажите настоящий номер телефона или Telegram (@username)' using errcode = 'P0001';
  end if;

  if tg_op = 'INSERT' then
    if not admin then
      select count(*) into cnt from public.posts
        where user_id = new.user_id and created_at > now() - interval '24 hours';
      if cnt >= 5 then
        raise exception 'Не больше 5 объявлений в сутки. Попробуйте завтра.' using errcode = 'P0001';
      end if;
      new.status := 'pending';
      new.reject_reason := null;
    end if;
  elsif not admin then
    -- автор правит содержимое или возвращает объявление — снова на проверку
    if new.status = 'active' and (old.status <> 'active'
        or new.title is distinct from old.title or new.description is distinct from old.description
        or new.photos is distinct from old.photos or new.contact is distinct from old.contact
        or new.price_egp is distinct from old.price_egp) then
      new.status := 'pending';
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

-- Защита чата от рассылок: не больше 30 сообщений в минуту
create or replace function public.messages_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare cnt int;
begin
  select count(*) into cnt from public.messages where sender_id = new.sender_id and created_at > now() - interval '1 minute';
  if cnt >= 30 then
    raise exception 'Слишком много сообщений. Подождите минуту.' using errcode = 'P0001';
  end if;
  return new;
end; $$;
drop trigger if exists messages_guard on public.messages;
create trigger messages_guard before insert on public.messages for each row execute function public.messages_guard();

-- Владелец приложения — администратор
update public.profiles set role = 'admin'
  where id = (select id from auth.users where email = 'dynnikovtimur40@gmail.com');

select 'v3 ok' as result;
