select to_char(created_at,'HH24:MI:SS') created, to_char(confirmation_sent_at,'HH24:MI:SS') code_sent,
       to_char(email_confirmed_at,'HH24:MI:SS') confirmed, to_char(last_sign_in_at,'HH24:MI:SS') signin, to_char(now(),'HH24:MI:SS') now_utc
from auth.users where confirmation_sent_at > now() - interval '3 hours' or created_at > now() - interval '3 hours' order by confirmation_sent_at desc nulls last limit 5;
# 1794672748
