create or replace function public.normalize_phone(value text)
returns text
language sql
immutable
parallel safe
set search_path = public
as $$
  with digits as (
    select regexp_replace(coalesce(value, ''), '\D', '', 'g') as phone
  )
  select case
    when phone = '' then null
    when length(phone) = 11 and left(phone, 1) = '8' then '7' || substring(phone from 2)
    when length(phone) = 10 then '7' || phone
    else phone
  end
  from digits;
$$;

create index if not exists client_ratings_courier_id_idx
on public.client_ratings(courier_id)
where courier_id is not null;

create index if not exists client_ratings_actor_profile_id_idx
on public.client_ratings(actor_profile_id)
where actor_profile_id is not null;

drop policy if exists client_ratings_staff_select on public.client_ratings;
drop policy if exists client_ratings_courier_select_own on public.client_ratings;

create policy client_ratings_select_internal
on public.client_ratings
for select
to authenticated
using (
  app_private.current_user_role() in ('dispatcher', 'admin')
  or courier_id = app_private.current_courier_id()
);
