-- Follow-up hardening for the live Supabase project:
-- 1. Persist client/device metadata for mobile sync operations.
-- 2. Narrow authenticated grants to the DML surface the apps actually use.
-- 3. Remove public execute on the generic trigger helper.

alter table public.sync_operations
  add column if not exists device_id text,
  add column if not exists session_id text,
  add column if not exists client_platform text,
  add column if not exists client_app_version text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'sync_operations_client_metadata_length_chk'
  ) then
    alter table public.sync_operations
      add constraint sync_operations_client_metadata_length_chk
      check (
        (device_id is null or char_length(device_id) <= 128)
        and (session_id is null or char_length(session_id) <= 128)
        and (client_platform is null or char_length(client_platform) <= 64)
        and (client_app_version is null or char_length(client_app_version) <= 64)
      )
      not valid;
  end if;
end $$;

alter table public.sync_operations
  validate constraint sync_operations_client_metadata_length_chk;

revoke all on table
  public.app_config,
  public.client_ratings,
  public.couriers,
  public.order_events,
  public.orders,
  public.payments,
  public.profiles,
  public.sync_operations
from authenticated;

grant select on table
  public.app_config,
  public.client_ratings,
  public.couriers,
  public.order_events,
  public.orders,
  public.payments,
  public.profiles,
  public.sync_operations
to authenticated;

grant insert, update, delete on table public.app_config to authenticated;
grant insert, update on table public.couriers to authenticated;
grant insert on table public.order_events to authenticated;
grant insert, update on table public.orders to authenticated;
grant insert, update, delete on table public.payments to authenticated;
grant update on table public.profiles to authenticated;
grant insert on table public.sync_operations to authenticated;

revoke all on function app_private.touch_updated_at() from public;

select pg_notify('pgrst', 'reload schema');
