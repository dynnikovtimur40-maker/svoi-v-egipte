select to_char(created_at,'HH24:MI:SS') created, to_char(confirmation_sent_at,'HH24:MI:SS') code_sent,
       to_char(email_confirmed_at,'HH24:MI:SS') confirmed, to_char(now(),'HH24:MI:SS') now_utc
from auth.users where created_at > now() - interval '40 minutes' order by created_at desc limit 5;
