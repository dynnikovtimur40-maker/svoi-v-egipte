-- «Свои в Египте» — структура базы v1

-- Профили пользователей (создаются автоматически при регистрации)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  city text not null default 'Каир',
  phone text,
  avatar_url text,
  verified boolean not null default false,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)));
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Объявления / услуги / вакансии
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  section text not null check (section in ('ads','services','jobs')),
  category text not null,
  title text not null check (char_length(title) between 3 and 120),
  description text not null default '',
  price_egp integer check (price_egp >= 0),
  city text not null,
  contact text not null,
  photos text[] not null default '{}',
  status text not null default 'active' check (status in ('pending','active','closed','blocked')),
  boosted_until timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists posts_feed_idx on public.posts (section, city, status, created_at desc);

-- Избранное
create table if not exists public.favorites (
  user_id uuid references public.profiles(id) on delete cascade,
  post_id uuid references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

-- Сообщения (чат по объявлению)
create table if not exists public.messages (
  id bigint generated always as identity primary key,
  post_id uuid references public.posts(id) on delete set null,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  text text not null check (char_length(text) between 1 and 2000),
  read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists messages_pair_idx on public.messages (sender_id, receiver_id, created_at);

-- Отзывы о продавцах
create table if not exists public.reviews (
  id bigint generated always as identity primary key,
  seller_id uuid not null references public.profiles(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  stars smallint not null check (stars between 1 and 5),
  text text not null default '',
  created_at timestamptz not null default now(),
  unique (seller_id, author_id),
  check (seller_id <> author_id)
);

-- Жалобы
create table if not exists public.reports (
  id bigint generated always as identity primary key,
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null default '',
  created_at timestamptz not null default now()
);

-- ===== Права доступа (Row Level Security) =====
alter table public.profiles  enable row level security;
alter table public.posts     enable row level security;
alter table public.favorites enable row level security;
alter table public.messages  enable row level security;
alter table public.reviews   enable row level security;
alter table public.reports   enable row level security;

create policy "profiles: все читают" on public.profiles for select using (true);
create policy "profiles: свой меняю" on public.profiles for update using (auth.uid() = id)
  with check (auth.uid() = id and verified = (select p.verified from public.profiles p where p.id = auth.uid()));

create policy "posts: все читают активные" on public.posts for select using (status = 'active' or user_id = auth.uid());
create policy "posts: создаю свои" on public.posts for insert with check (auth.uid() = user_id and status in ('active','pending'));
create policy "posts: меняю свои" on public.posts for update using (auth.uid() = user_id)
  with check (auth.uid() = user_id and status <> 'blocked');
create policy "posts: удаляю свои" on public.posts for delete using (auth.uid() = user_id);

create policy "favorites: свои" on public.favorites for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "messages: читаю свои" on public.messages for select using (auth.uid() in (sender_id, receiver_id));
create policy "messages: отправляю от себя" on public.messages for insert with check (auth.uid() = sender_id);
create policy "messages: отмечаю прочитанным" on public.messages for update using (auth.uid() = receiver_id);

create policy "reviews: все читают" on public.reviews for select using (true);
create policy "reviews: пишу от себя" on public.reviews for insert with check (auth.uid() = author_id);

create policy "reports: отправляю от себя" on public.reports for insert with check (auth.uid() = user_id);

-- ===== Фото объявлений =====
insert into storage.buckets (id, name, public) values ('post-photos', 'post-photos', true)
  on conflict (id) do nothing;
create policy "photos: все смотрят" on storage.objects for select using (bucket_id = 'post-photos');
create policy "photos: загружаю в свою папку" on storage.objects for insert to authenticated
  with check (bucket_id = 'post-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "photos: удаляю свои" on storage.objects for delete to authenticated
  using (bucket_id = 'post-photos' and (storage.foldername(name))[1] = auth.uid()::text);
