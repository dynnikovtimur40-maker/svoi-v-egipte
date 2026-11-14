select pg_sleep(12);
select left(coalesce(content::text, error_msg, ''), 2500) c from net._http_response order by id desc limit 1;
