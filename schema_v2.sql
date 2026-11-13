-- «Свои в Египте» — обновление базы v2: сделки, честные отзывы, фото в чате

-- ===== Сделки: продавец подтверждает в чате, что сделка состоялась =====
create table if not exists public.deals (
  id bigint generated always as identity primary key,
  post_id uuid references public.posts(id) on delete set null,
  seller_id uuid not null references public.profiles(id) on delete cascade,
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (seller_id <> buyer_id)
);
create unique index if not exists deals_unique_idx on public.deals (seller_id, buyer_id, coalesce(post_id, '00000000-0000-0000-0000-000000000000'::uuid));
alter table public.deals enable row level security;

drop policy if exists "deals: участники видят" on public.deals;
create policy "deals: участники видят" on public.deals for select
  using (auth.uid() in (seller_id, buyer_id));

-- Подтвердить сделку может только продавец (автор объявления),
-- и только с тем, кто писал ему в чат по этому объявлению.
drop policy if exists "deals: продавец подтверждает" on public.deals;
create policy "deals: продавец подтверждает" on public.deals for insert with check (
  auth.uid() = seller_id
  and (post_id is null or exists (select 1 from public.posts p where p.id = post_id and p.user_id = seller_id))
  and exists (
    select 1 from public.messages m
    where m.sender_id = buyer_id and m.receiver_id = seller_id
      and (deals.post_id is null or m.post_id = deals.post_id)
  )
);

-- ===== Отзывы: только по подтверждённой сделке, один отзыв на сделку =====
alter table public.reviews add column if not exists deal_id bigint references public.deals(id) on delete set null;
alter table public.reviews add column if not exists post_title text not null default '';
alter table public.reviews add column if not exists reply text;
alter table public.reviews add column if not exists reply_at timestamptz;
alter table public.reviews drop constraint if exists reviews_seller_id_author_id_key;
create unique index if not exists reviews_deal_idx on public.reviews (deal_id) where deal_id is not null;

drop policy if exists "reviews: пишу от себя" on public.reviews;
create policy "reviews: только после сделки" on public.reviews for insert with check (
  auth.uid() = author_id
  and deal_id is not null
  and exists (
    select 1 from public.deals d
    where d.id = deal_id and d.buyer_id = auth.uid() and d.seller_id = reviews.seller_id
  )
);

-- Продавец может ответить на отзыв о себе (только поле ответа).
drop policy if exists "reviews: продавец отвечает" on public.reviews;
create policy "reviews: продавец отвечает" on public.reviews for update
  using (auth.uid() = seller_id) with check (auth.uid() = seller_id);

create or replace function public.reviews_guard() returns trigger language plpgsql as $$
begin
  if auth.uid() = old.seller_id then
    new.stars := old.stars; new.text := old.text; new.author_id := old.author_id;
    new.seller_id := old.seller_id; new.deal_id := old.deal_id; new.post_title := old.post_title;
    new.created_at := old.created_at;
    new.reply_at := now();
  end if;
  return new;
end; $$;
drop trigger if exists reviews_guard on public.reviews;
create trigger reviews_guard before update on public.reviews for each row execute function public.reviews_guard();

-- Старые отзывы без сделки остаются в базе, но приложение их не показывает и не учитывает.

-- ===== Фото в личных сообщениях =====
alter table public.messages add column if not exists image_url text;
alter table public.messages drop constraint if exists messages_text_check;
alter table public.messages add constraint messages_text_check
  check (char_length(text) <= 2000 and (char_length(text) >= 1 or image_url is not null));
