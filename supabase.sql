-- Run in a NEW Supabase project. Create staff user in Authentication first.
create table public.pos_staff(uid uuid primary key references auth.users(id));
create table public.pos_config(id int primary key check(id=1),shop text not null default 'Lumina Cafe',items jsonb not null default '[]');
insert into public.pos_config(id) values(1);
create table public.pos_tables(name text primary key, token uuid not null default gen_random_uuid());
insert into public.pos_tables(name) select 'T'||i from generate_series(1,12) i;
create table public.pos_requests(id uuid primary key default gen_random_uuid(),table_name text not null references public.pos_tables(name),items jsonb not null,notes text not null default '',status text not null default 'Pending' check(status in ('Pending','Accepted','Rejected')),created_at timestamptz not null default now());
alter table public.pos_staff enable row level security;
alter table public.pos_config enable row level security;
alter table public.pos_tables enable row level security;
alter table public.pos_requests enable row level security;
create function public.is_pos_staff() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.pos_staff where uid=auth.uid()) $$;
create policy staff_config on public.pos_config for all to authenticated using(public.is_pos_staff()) with check(public.is_pos_staff());
create policy staff_tables on public.pos_tables for select to authenticated using(public.is_pos_staff());
create policy staff_requests on public.pos_requests for select to authenticated using(public.is_pos_staff());
create policy staff_update on public.pos_requests for update to authenticated using(public.is_pos_staff()) with check(public.is_pos_staff());
grant select,update on public.pos_config to authenticated;
grant select on public.pos_tables to authenticated;
grant select,update on public.pos_requests to authenticated;
create function public.table_menu(p_table text,p_token uuid) returns jsonb language plpgsql security definer set search_path=public as $$ begin
if not exists(select 1 from public.pos_tables where name=p_table and token=p_token) then raise exception 'Invalid table'; end if;
return (select jsonb_build_object('shop',shop,'items',items) from public.pos_config where id=1);
end $$;
create function public.submit_table_order(p_table text,p_token uuid,p_items jsonb,p_notes text) returns uuid language plpgsql security definer set search_path=public as $$
declare x jsonb; m jsonb; validated jsonb:='[]'; result uuid; n int;
begin
if not exists(select 1 from public.pos_tables where name=p_table and token=p_token) then raise exception 'Invalid table'; end if;
if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) not between 1 and 30 or length(coalesce(p_notes,''))>300 then raise exception 'Invalid order'; end if;
if (select count(distinct a->>'id') from jsonb_array_elements(p_items) a)<>jsonb_array_length(p_items) then raise exception 'Duplicate item'; end if;
for x in select * from jsonb_array_elements(p_items) loop
n:=(x->>'qty')::int;
if n is null or n not between 1 and 20 then raise exception 'Invalid quantity'; end if;
select a into m from public.pos_config c cross join lateral jsonb_array_elements(c.items) a where c.id=1 and a->>'id'=x->>'id';
if m is null or coalesce((m->>'stock')::numeric,0)<n then raise exception 'Unavailable item'; end if;
validated:=validated||jsonb_build_array(jsonb_build_object('id',m->>'id','name',m->>'name','price',(m->>'price')::numeric,'qty',n));
end loop;
insert into public.pos_requests(table_name,items,notes) values(p_table,validated,coalesce(p_notes,'')) returning id into result;
return result;
end $$;
revoke all on function public.table_menu(text,uuid) from public;
revoke all on function public.submit_table_order(text,uuid,jsonb,text) from public;
grant execute on function public.table_menu(text,uuid),public.submit_table_order(text,uuid,jsonb,text) to anon,authenticated;
-- After creating a staff user, replace UUID below and execute:
-- insert into public.pos_staff(uid) values ('STAFF-USER-UUID');
