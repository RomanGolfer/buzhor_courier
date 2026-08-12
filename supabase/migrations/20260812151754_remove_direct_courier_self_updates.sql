-- Courier GPS updates use the report_courier_location RPC. Keeping a direct
-- self-update policy would also authorize other courier row changes because
-- PostgreSQL RLS policies cannot restrict individual updated columns.
drop policy if exists couriers_self_location_update on public.couriers;
