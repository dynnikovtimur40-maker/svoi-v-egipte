select id, status_code, left(coalesce(content::text, error_msg, ''), 3000) c from net._http_response where id = 89;
