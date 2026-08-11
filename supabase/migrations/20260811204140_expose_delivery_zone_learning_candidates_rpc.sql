create or replace function public.list_delivery_zone_learning_candidates()
returns table (
  id uuid,
  zone_id uuid,
  address_text text,
  lat numeric,
  lng numeric,
  delivery_count integer,
  distance_m numeric,
  status text,
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  applied_at timestamptz,
  ignored_at timestamptz,
  reverted_at timestamptz,
  last_error text
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    candidate.id,
    candidate.zone_id,
    candidate.address_text,
    candidate.lat,
    candidate.lng,
    candidate.delivery_count,
    candidate.distance_m,
    candidate.status,
    candidate.first_seen_at,
    candidate.last_seen_at,
    candidate.applied_at,
    candidate.ignored_at,
    candidate.reverted_at,
    candidate.last_error
  from public.delivery_zone_learning_candidates as candidate
  order by candidate.last_seen_at desc nulls last, candidate.created_at desc, candidate.id;
$$;

revoke all on function public.list_delivery_zone_learning_candidates() from public;
grant execute on function public.list_delivery_zone_learning_candidates() to authenticated;
grant execute on function public.list_delivery_zone_learning_candidates() to service_role;

select pg_notify('pgrst', 'reload schema');
