select (select json_agg(r) from (select id, status_code, left(coalesce(content::text, error_msg, ''), 300) c, timed_out from net._http_response where id >= 87 order by id limit 3) r) as resp,
  (select json_agg(b) from (select kind, detail, to_char(created_at,'HH24:MI') t from public.bot_log order by id desc limit 5) b) as log,
  (select json_agg(x) from (select lang, tag, left(title, 90) as title, source from public.news where auto order by created_at desc limit 14) x) as items;
