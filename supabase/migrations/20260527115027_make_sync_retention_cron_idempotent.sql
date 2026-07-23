-- Make sync operation retention scheduling idempotent across repeated deploys.
-- Requires pg_cron to be enabled before this migration runs.

do $do$
declare
  v_jobid bigint;
begin
  select jobid
  into v_jobid
  from cron.job
  where jobname = 'purge-acked-sync-operations'
  limit 1;

  if v_jobid is not null then
    perform cron.unschedule(v_jobid);
  end if;

  perform cron.schedule(
    'purge-acked-sync-operations',
    '0 3 * * *',
    $sql$select app_private.purge_old_sync_operations(90)$sql$
  );
end;
$do$;
