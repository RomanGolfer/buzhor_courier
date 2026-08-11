create or replace function app_private.record_delivery_zone_observation(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  delivery_record record;
  delivery_point extensions.geometry;
  covering_zone_id uuid;
  nearest_zone record;
  normalized_address text;
  calculated_address_key text;
  learning_candidate_id uuid;
  learning_candidate_status text;
  observation_id uuid;
  window_delivery_count integer;
  window_first_seen timestamptz;
  window_last_seen timestamptz;
begin
  select delivery_order.id,
         delivery_order.state,
         delivery_order.address,
         delivery_order.lat,
         delivery_order.lng,
         delivery_order.delivery_date,
         delivery_order.updated_at
  into delivery_record
  from public.orders as delivery_order
  where delivery_order.id = p_order_id;

  if delivery_record.id is null
    or delivery_record.state <> 'delivered'
    or delivery_record.lat is null
    or delivery_record.lng is null
  then
    return;
  end if;

  delivery_point := extensions.st_setsrid(
    extensions.st_point(delivery_record.lng::double precision, delivery_record.lat::double precision),
    4326
  );

  select zone.id
  into covering_zone_id
  from public.delivery_zones as zone
  where zone.is_active
    and extensions.st_covers(zone.boundary, delivery_point)
  order by zone.priority, zone.created_at, zone.id
  limit 1;

  if covering_zone_id is not null then
    update public.orders
    set delivery_zone_id = covering_zone_id
    where id = delivery_record.id
      and delivery_zone_id is distinct from covering_zone_id;
    return;
  end if;

  select zone.id,
         zone.learning_min_deliveries,
         zone.learning_lookback_days,
         zone.learning_max_distance_m,
         distance_calculation.distance_m
  into nearest_zone
  from public.delivery_zones as zone
  cross join lateral (
    select extensions.st_distance(
      zone.boundary::extensions.geography,
      delivery_point::extensions.geography
    ) as distance_m
  ) as distance_calculation
  where zone.is_active
    and zone.auto_expand_enabled
    and distance_calculation.distance_m <= zone.learning_max_distance_m
  order by distance_calculation.distance_m, zone.priority, zone.created_at, zone.id
  limit 1;

  if nearest_zone.id is null then
    return;
  end if;

  normalized_address := regexp_replace(lower(trim(delivery_record.address)), '\s+', ' ', 'g');
  calculated_address_key := 'address:' || md5(normalized_address);

  insert into public.delivery_zone_learning_candidates (
    zone_id,
    address_key,
    address_text,
    lat,
    lng,
    distance_m,
    first_seen_at,
    last_seen_at
  ) values (
    nearest_zone.id,
    calculated_address_key,
    delivery_record.address,
    delivery_record.lat,
    delivery_record.lng,
    nearest_zone.distance_m,
    coalesce(delivery_record.delivery_date::timestamptz, delivery_record.updated_at),
    coalesce(delivery_record.delivery_date::timestamptz, delivery_record.updated_at)
  )
  on conflict (zone_id, address_key) do update
  set address_text = excluded.address_text,
      lat = excluded.lat,
      lng = excluded.lng,
      distance_m = excluded.distance_m,
      last_seen_at = greatest(
        delivery_zone_learning_candidates.last_seen_at,
        excluded.last_seen_at
      )
  returning id, status into learning_candidate_id, learning_candidate_status;

  insert into public.delivery_zone_learning_observations (candidate_id, order_id, observed_at)
  values (
    learning_candidate_id,
    delivery_record.id,
    coalesce(delivery_record.delivery_date::timestamptz, delivery_record.updated_at)
  )
  on conflict (order_id) do nothing
  returning id into observation_id;

  if observation_id is null then
    return;
  end if;

  select count(*)::integer,
         min(observation.observed_at),
         max(observation.observed_at)
  into window_delivery_count, window_first_seen, window_last_seen
  from public.delivery_zone_learning_observations as observation
  where observation.candidate_id = learning_candidate_id
    and observation.observed_at >= now() - make_interval(days => nearest_zone.learning_lookback_days);

  update public.delivery_zone_learning_candidates
  set delivery_count = window_delivery_count,
      first_seen_at = window_first_seen,
      last_seen_at = window_last_seen
  where id = learning_candidate_id;

  if learning_candidate_status = 'observing'
    and window_delivery_count >= nearest_zone.learning_min_deliveries
  then
    begin
      perform app_private.expand_delivery_zone_for_candidate(learning_candidate_id);
    exception
      when others then
        update public.delivery_zone_learning_candidates
        set status = 'needs_review',
            last_error = left(sqlerrm, 1000)
        where id = learning_candidate_id;
    end;
  end if;
end;
$$;

revoke all on function app_private.record_delivery_zone_observation(uuid) from public;
revoke all on function app_private.record_delivery_zone_observation(uuid) from anon;
revoke all on function app_private.record_delivery_zone_observation(uuid) from authenticated;

select pg_notify('pgrst', 'reload schema');
