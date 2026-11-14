delete from auth.users where email like 'delivered+svoitest%@resend.dev';
select 'cleanup ok' as result;
