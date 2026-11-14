select id, status_code, left(coalesce(content::text, error_msg, ''), 2500) c from net._http_response where id = 88;
