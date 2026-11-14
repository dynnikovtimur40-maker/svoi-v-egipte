select (select pg_get_userbyid(proowner) from pg_proc where proname='notify_moderator') as owner,
  (select string_agg(pg_get_function_identity_arguments(p.oid), ' | ') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='net' and p.proname='http_post') as sig,
  has_schema_privilege('authenticated','net','USAGE') as auth_usage;
