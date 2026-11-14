select pg_sleep(30);
select (select detail from public.bot_log where kind = 'news-sync' order by id desc limit 1) as log,
  (select json_agg(x) from (select lang, tag, left(title, 80) as title, source, to_char(created_at, 'MM-DD HH24:MI') as d from public.news where auto order by created_at desc limit 16) x) as items;
