-- v9: скидки партнёров для туристов
create table if not exists public.promos (
  id uuid primary key default gen_random_uuid(),
  partner text not null check (char_length(partner) between 2 and 80),
  city text not null default 'Все города',
  title text not null check (char_length(title) between 3 and 120),
  details text not null default '' check (char_length(details) <= 1000),
  code text not null default '' check (char_length(code) <= 40),
  contact text not null default '' check (char_length(contact) <= 120),
  until date,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.promos enable row level security;
drop policy if exists "promos: все читают" on public.promos;
create policy "promos: все читают" on public.promos for select
  using ((active and (until is null or until >= current_date)) or public.is_admin());
drop policy if exists "promos: админ пишет" on public.promos;
create policy "promos: админ пишет" on public.promos for all
  using (public.is_admin()) with check (public.is_admin());
grant select on public.promos to anon, authenticated;
grant insert, update, delete on public.promos to authenticated;
create index if not exists promos_city on public.promos (city, created_at desc);
select 'v9 ok' as result;
