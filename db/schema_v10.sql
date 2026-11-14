-- v10: раздел «Недвижимость» и параметры жилья
alter table public.posts add column if not exists details jsonb not null default '{}'::jsonb;

do $$
declare c text;
begin
  for c in select conname from pg_constraint
           where conrelid = 'public.posts'::regclass and contype = 'c' and pg_get_constraintdef(oid) ilike '%section%'
  loop
    execute format('alter table public.posts drop constraint %I', c);
  end loop;
end $$;
alter table public.posts add constraint posts_section_check
  check (section in ('ads','services','jobs','realty'));

-- объявления о жилье из раздела «Объявления» переезжают в «Недвижимость»
update public.posts set section = 'realty', category = case category
    when 'Аренда жилья' then 'Аренда на месяц'
    when 'Аренда посуточно' then 'Посуточно'
    when 'Продажа жилья' then 'Продажа' end
  where section = 'ads' and category in ('Аренда жилья', 'Аренда посуточно', 'Продажа жилья');
update public.saved_searches set section = 'realty', category = case category
    when 'Аренда жилья' then 'Аренда на месяц'
    when 'Аренда посуточно' then 'Посуточно'
    when 'Продажа жилья' then 'Продажа' end
  where section = 'ads' and category in ('Аренда жилья', 'Аренда посуточно', 'Продажа жилья');

create index if not exists posts_details on public.posts using gin (details);
select 'v10 ok' as result, (select count(*) from public.posts where section = 'realty') as realty_posts;
