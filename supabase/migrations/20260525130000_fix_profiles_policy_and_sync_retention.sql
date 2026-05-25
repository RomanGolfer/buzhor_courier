-- Fix 1: profiles_select_own_or_staff was relying on `auth.uid() is not null`
-- as its outer guard, making the intent opaque and fragile. Replace with an
-- explicit condition: own row OR staff role.
drop policy if exists profiles_select_own_or_staff on public.profiles;
create policy profiles_select_own_or_staff
on public.profiles
for select
to authenticated
using (
  id = (select auth.uid())
  or app_private.current_user_role() in ('dispatcher', 'admin')
);

-- Fix 2: sync_operations accumulate forever once status = 'acked'.
-- Add a retention function and schedule it daily via pg_cron.
-- Rows older than 90 days with status 'acked' are safe to delete —
-- the order itself holds all business data; sync_operations are a delivery log.

create or replace function app_private.purge_old_sync_operations(
  retention_days integer default 90
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count integer;
begin
  delete from public.sync_operations
  where status = 'acked'
    and acked_at < now() - (retention_days || ' days')::interval;

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

revoke all on function app_private.purge_old_sync_operations(integer) from public;

-- Schedule daily cleanup at 03:00 UTC.
-- pg_cron must be enabled in Supabase dashboard: Database → Extensions → pg_cron.
select cron.schedule(
  'purge-acked-sync-operations',
  '0 3 * * *',
  $$select app_private.purge_old_sync_operations(90)$$
);
