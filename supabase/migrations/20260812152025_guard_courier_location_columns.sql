alter function public.report_courier_location(numeric, numeric, numeric)
  security invoker;

create or replace function app_private.guard_courier_location_columns()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if app_private.current_user_role() = 'courier'
    and (
      to_jsonb(new) - array[
        'last_lat',
        'last_lng',
        'last_location_accuracy_m',
        'last_location_at',
        'updated_at'
      ]
    ) is distinct from (
      to_jsonb(old) - array[
        'last_lat',
        'last_lng',
        'last_location_accuracy_m',
        'last_location_at',
        'updated_at'
      ]
    ) then
    raise exception 'courier_location_columns_only' using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists couriers_guard_location_columns on public.couriers;
create trigger couriers_guard_location_columns
before update on public.couriers
for each row execute function app_private.guard_courier_location_columns();

drop policy if exists couriers_staff_update on public.couriers;
drop policy if exists couriers_self_location_update on public.couriers;
drop policy if exists couriers_staff_or_self_update on public.couriers;
create policy couriers_staff_or_self_update on public.couriers
for update to authenticated
using (
  (select app_private.current_user_role()) in ('dispatcher', 'admin')
  or (
    profile_id = (select auth.uid())
    and (select app_private.current_user_role()) = 'courier'
  )
)
with check (
  (select app_private.current_user_role()) in ('dispatcher', 'admin')
  or (
    profile_id = (select auth.uid())
    and (select app_private.current_user_role()) = 'courier'
  )
);
