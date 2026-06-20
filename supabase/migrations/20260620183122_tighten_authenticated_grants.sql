-- Tighten authenticated table privileges to the operations used by the apps.
-- RLS still enforces row-level authorization; these grants remove unnecessary
-- table-level capabilities such as TRUNCATE/TRIGGER/REFERENCES and broad DELETE.

revoke all privileges on table public.app_config from authenticated;
grant select, insert, update on table public.app_config to authenticated;

revoke all privileges on table public.call_events from authenticated;
grant select, insert, update on table public.call_events to authenticated;

revoke all privileges on table public.device_push_tokens from authenticated;
grant select, insert, update, delete on table public.device_push_tokens to authenticated;

revoke all privileges on table public.payments from authenticated;
grant select, insert, update on table public.payments to authenticated;

select pg_notify('pgrst', 'reload schema');
