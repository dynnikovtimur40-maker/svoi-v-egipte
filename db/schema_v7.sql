-- v7: перенос Telegram на другой профиль при проверке, журнал бота для диагностики.

create table if not exists public.bot_log (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  kind text not null,
  detail text
);
alter table public.bot_log enable row level security; -- доступ только серверу

create or replace function public.confirm_verification(p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); v record;
begin
  if uid is null then return 'none'; end if;
  select * into v from public.verifications
    where user_id = uid and status = 'sent' order by id desc limit 1;
  if v.id is null or v.otp is null then return 'none'; end if;
  if v.attempts >= 5 then return 'locked'; end if;
  if v.otp_expires < now() then return 'expired'; end if;
  if trim(coalesce(p_code, '')) <> v.otp then
    update public.verifications set attempts = attempts + 1, updated_at = now() where id = v.id;
    return case when v.attempts + 1 >= 5 then 'locked' else 'wrong' end;
  end if;
  -- один Telegram — один профиль: отметка переносится, со старого профиля снимается
  update public.profiles set verified = false, tg_id = null, tg_username = null
    where tg_id = v.tg_chat_id and id <> uid;
  update public.profiles set verified = true, tg_id = v.tg_chat_id, tg_username = v.tg_username where id = uid;
  update public.verifications set status = 'approved', otp = null, updated_at = now() where id = v.id;
  return 'ok';
end; $$;

delete from public.bot_log where created_at < now() - interval '30 days';
select 'v7 ok' as result;
