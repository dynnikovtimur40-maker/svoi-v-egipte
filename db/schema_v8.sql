-- v8: автоматические новости (Google Новости), обновление каждые 3 часа.
alter table public.news add column if not exists source text;
alter table public.news add column if not exists url text;
alter table public.news add column if not exists lang text;
alter table public.news add column if not exists auto boolean not null default false;
create unique index if not exists news_url_unique on public.news (url) where url is not null;
alter table public.news drop constraint if exists news_title_check;
alter table public.news add constraint news_title_check check (char_length(title) between 3 and 300);

create extension if not exists pg_cron;
select cron.unschedule(jobid) from cron.job where jobname = 'news-sync';
select cron.schedule('news-sync', '7 */3 * * *', $cron$
  select net.http_post(
    url := 'https://pjjeypdxwnbtyqabhroi.supabase.co/functions/v1/news-sync',
    body := '{}'::jsonb,
    headers := '{"Content-Type": "application/json"}'::jsonb);
$cron$);

select 'v8 ok' as result, (select count(*) from cron.job where jobname = 'news-sync') as jobs;
