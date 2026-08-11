alter table public.delivery_zones
  add column auto_expand_enabled boolean not null default true,
  add column learning_min_deliveries integer not null default 3,
  add column learning_lookback_days integer not null default 90,
  add column learning_max_distance_m integer not null default 1000,
  add column learning_radius_m integer not null default 100,
  add column last_learning_at timestamptz,
  add constraint delivery_zones_learning_settings_chk check (
    learning_min_deliveries between 2 and 20
    and learning_lookback_days between 7 and 365
    and learning_max_distance_m between 100 and 5000
    and learning_radius_m between 30 and 300
  );

comment on column public.delivery_zones.auto_expand_enabled is
  'When enabled, repeated completed deliveries near the boundary may expand the zone automatically.';

create table public.delivery_zone_learning_candidates (
  id uuid primary key default gen_random_uuid(),
  zone_id uuid not null references public.delivery_zones(id) on delete cascade,
  address_key text not null,
  address_text text not null,
  lat numeric(10, 7) not null,
  lng numeric(10, 7) not null,
  delivery_count integer not null default 0,
  distance_m numeric(10, 2) not null default 0,
  status text not null default 'observing',
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  applied_at timestamptz,
  ignored_at timestamptz,
  reverted_at timestamptz,
  boundary_before extensions.geometry(Polygon, 4326),
  boundary_after extensions.geometry(Polygon, 4326),
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint delivery_zone_learning_candidates_zone_address_uidx unique (zone_id, address_key),
  constraint delivery_zone_learning_candidates_status_chk check (
    status in ('observing', 'applied', 'ignored', 'reverted', 'needs_review')
  ),
  constraint delivery_zone_learning_candidates_values_chk check (
    char_length(address_key) between 1 and 200
    and char_length(address_text) between 1 and 500
    and lat between -90 and 90
    and lng between -180 and 180
    and delivery_count >= 0
    and distance_m >= 0
    and (last_error is null or char_length(last_error) <= 1000)
  )
);

create table public.delivery_zone_learning_observations (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.delivery_zone_learning_candidates(id) on delete cascade,
  order_id uuid not null unique references public.orders(id) on delete cascade,
  observed_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index delivery_zone_learning_candidates_zone_status_idx
on public.delivery_zone_learning_candidates(zone_id, status, last_seen_at desc);

create index delivery_zone_learning_observations_candidate_date_idx
on public.delivery_zone_learning_observations(candidate_id, observed_at desc);

create trigger delivery_zone_learning_candidates_touch_updated_at
before update on public.delivery_zone_learning_candidates
for each row execute function app_private.touch_updated_at();

alter table public.delivery_zone_learning_candidates enable row level security;
alter table public.delivery_zone_learning_observations enable row level security;

revoke all on public.delivery_zone_learning_candidates from authenticated;
revoke all on public.delivery_zone_learning_observations from authenticated;
grant select, update on public.delivery_zone_learning_candidates to authenticated;
grant select on public.delivery_zone_learning_observations to authenticated;
grant all on public.delivery_zone_learning_candidates to service_role;
grant all on public.delivery_zone_learning_observations to service_role;

create policy delivery_zone_learning_candidates_staff_select
on public.delivery_zone_learning_candidates for select to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy delivery_zone_learning_candidates_admin_update
on public.delivery_zone_learning_candidates for update to authenticated
using ((select app_private.current_user_role()) = 'admin')
with check ((select app_private.current_user_role()) = 'admin');

create policy delivery_zone_learning_observations_staff_select
on public.delivery_zone_learning_observations for select to authenticated
using (
  (select app_private.current_user_role()) in ('dispatcher', 'admin')
  and exists (
    select 1
    from public.delivery_zone_learning_candidates as candidate
    where candidate.id = delivery_zone_learning_observations.candidate_id
  )
);

create or replace function app_private.expand_delivery_zone_for_candidate(p_candidate_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  candidate_record record;
  zone_record record;
  candidate_point extensions.geometry;
  nearest_point extensions.geometry;
  point_area extensions.geometry;
  corridor_area extensions.geometry;
  expanded_boundary extensions.geometry;
  current_distance double precision;
begin
  select candidate.*
  into candidate_record
  from public.delivery_zone_learning_candidates as candidate
  where candidate.id = p_candidate_id
  for update;

  if candidate_record.id is null or candidate_record.status <> 'observing' then
    return false;
  end if;

  select zone.*
  into zone_record
  from public.delivery_zones as zone
  where zone.id = candidate_record.zone_id
  for update;

  if zone_record.id is null
    or not zone_record.is_active
    or not zone_record.auto_expand_enabled
    or candidate_record.delivery_count < zone_record.learning_min_deliveries
  then
    return false;
  end if;

  candidate_point := extensions.st_setsrid(
    extensions.st_point(candidate_record.lng::double precision, candidate_record.lat::double precision),
    4326
  );

  current_distance := extensions.st_distance(
    zone_record.boundary::extensions.geography,
    candidate_point::extensions.geography
  );

  if current_distance > zone_record.learning_max_distance_m then
    update public.delivery_zone_learning_candidates
    set status = 'needs_review',
        distance_m = current_distance,
        last_error = 'Адрес оказался дальше допустимого расстояния от текущей границы.'
    where id = candidate_record.id;
    return false;
  end if;

  if extensions.st_covers(zone_record.boundary, candidate_point) then
    expanded_boundary := zone_record.boundary;
  else
    nearest_point := extensions.st_closestpoint(zone_record.boundary, candidate_point);
    point_area := extensions.st_buffer(
      candidate_point::extensions.geography,
      zone_record.learning_radius_m
    );
    corridor_area := extensions.st_buffer(
      extensions.st_makeline(nearest_point, candidate_point)::extensions.geography,
      greatest(20, zone_record.learning_radius_m / 2)
    );
    expanded_boundary := extensions.st_force2d(
      extensions.st_union(
        extensions.st_union(zone_record.boundary, corridor_area),
        point_area
      )
    );
  end if;

  if expanded_boundary is null
    or extensions.geometrytype(expanded_boundary) <> 'POLYGON'
    or not extensions.st_isvalid(expanded_boundary)
  then
    update public.delivery_zone_learning_candidates
    set status = 'needs_review',
        last_error = 'Автоматическое расширение создало сложную границу и требует ручной проверки.'
    where id = candidate_record.id;
    return false;
  end if;

  update public.delivery_zones
  set boundary = expanded_boundary,
      last_learning_at = now()
  where id = zone_record.id;

  update public.delivery_zone_learning_candidates
  set status = 'applied',
      distance_m = current_distance,
      boundary_before = zone_record.boundary,
      boundary_after = expanded_boundary,
      applied_at = now(),
      ignored_at = null,
      reverted_at = null,
      last_error = null
  where id = candidate_record.id;

  update public.orders as delivery_order
  set delivery_zone_id = zone_record.id
  where delivery_order.delivery_zone_id is null
    and delivery_order.lat is not null
    and delivery_order.lng is not null
    and extensions.st_covers(
      expanded_boundary,
      extensions.st_setsrid(
        extensions.st_point(delivery_order.lng::double precision, delivery_order.lat::double precision),
        4326
      )
    );

  update public.client_addresses as client_address
  set zone_name = zone_record.name
  where client_address.lat is not null
    and client_address.lng is not null
    and extensions.st_covers(
      expanded_boundary,
      extensions.st_setsrid(
        extensions.st_point(client_address.lng::double precision, client_address.lat::double precision),
        4326
      )
    );

  return true;
end;
$$;

revoke all on function app_private.expand_delivery_zone_for_candidate(uuid) from public;
revoke all on function app_private.expand_delivery_zone_for_candidate(uuid) from anon;
revoke all on function app_private.expand_delivery_zone_for_candidate(uuid) from authenticated;

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
  candidate_id uuid;
  candidate_status text;
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
  returning id, status into candidate_id, candidate_status;

  insert into public.delivery_zone_learning_observations (candidate_id, order_id, observed_at)
  values (
    candidate_id,
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
  where observation.candidate_id = candidate_id
    and observation.observed_at >= now() - make_interval(days => nearest_zone.learning_lookback_days);

  update public.delivery_zone_learning_candidates
  set delivery_count = window_delivery_count,
      first_seen_at = window_first_seen,
      last_seen_at = window_last_seen
  where id = candidate_id;

  if candidate_status = 'observing'
    and window_delivery_count >= nearest_zone.learning_min_deliveries
  then
    begin
      perform app_private.expand_delivery_zone_for_candidate(candidate_id);
    exception
      when others then
        update public.delivery_zone_learning_candidates
        set status = 'needs_review',
            last_error = left(sqlerrm, 1000)
        where id = candidate_id;
    end;
  end if;
end;
$$;

revoke all on function app_private.record_delivery_zone_observation(uuid) from public;
revoke all on function app_private.record_delivery_zone_observation(uuid) from anon;
revoke all on function app_private.record_delivery_zone_observation(uuid) from authenticated;

create or replace function app_private.observe_order_for_delivery_zone_learning()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.state <> 'delivered' then
    return new;
  end if;

  if tg_op = 'INSERT' then
    begin
      perform app_private.record_delivery_zone_observation(new.id);
    exception
      when others then
        raise warning 'delivery_zone_learning_failed order=% error=%', new.id, sqlerrm;
    end;
  elsif old.state is distinct from new.state
    or old.lat is distinct from new.lat
    or old.lng is distinct from new.lng
    or old.address is distinct from new.address
  then
    begin
      perform app_private.record_delivery_zone_observation(new.id);
    exception
      when others then
        raise warning 'delivery_zone_learning_failed order=% error=%', new.id, sqlerrm;
    end;
  end if;
  return new;
end;
$$;

revoke all on function app_private.observe_order_for_delivery_zone_learning() from public;
revoke all on function app_private.observe_order_for_delivery_zone_learning() from anon;
revoke all on function app_private.observe_order_for_delivery_zone_learning() from authenticated;

create trigger orders_observe_delivery_zone_learning
after insert or update of state, lat, lng, address on public.orders
for each row execute function app_private.observe_order_for_delivery_zone_learning();

create or replace function app_private.refresh_delivery_zone_learning()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  delivery_order record;
  learning_candidate record;
  processed_count integer := 0;
begin
  if app_private.current_user_role() <> 'admin' then
    raise exception 'admin_role_required'
      using errcode = '42501';
  end if;

  for delivery_order in
    select candidate_order.id
    from public.orders as candidate_order
    where candidate_order.state = 'delivered'
      and candidate_order.lat is not null
      and candidate_order.lng is not null
      and (
        candidate_order.delivery_zone_id is null
        or not exists (
          select 1
          from public.delivery_zones as assigned_zone
          where assigned_zone.id = candidate_order.delivery_zone_id
            and assigned_zone.is_active
            and extensions.st_covers(
              assigned_zone.boundary,
              extensions.st_setsrid(
                extensions.st_point(
                  candidate_order.lng::double precision,
                  candidate_order.lat::double precision
                ),
                4326
              )
            )
        )
      )
    order by candidate_order.delivery_date, candidate_order.created_at, candidate_order.id
  loop
    begin
      perform app_private.record_delivery_zone_observation(delivery_order.id);
      processed_count := processed_count + 1;
    exception
      when others then
        null;
    end;
  end loop;

  for learning_candidate in
    select candidate.id
    from public.delivery_zone_learning_candidates as candidate
    join public.delivery_zones as zone on zone.id = candidate.zone_id
    where candidate.status = 'observing'
      and candidate.delivery_count >= zone.learning_min_deliveries
      and zone.is_active
      and zone.auto_expand_enabled
    order by candidate.last_seen_at, candidate.id
  loop
    begin
      perform app_private.expand_delivery_zone_for_candidate(learning_candidate.id);
    exception
      when others then
        update public.delivery_zone_learning_candidates
        set status = 'needs_review',
            last_error = left(sqlerrm, 1000)
        where id = learning_candidate.id;
    end;
  end loop;

  return processed_count;
end;
$$;

revoke all on function app_private.refresh_delivery_zone_learning() from public;
revoke all on function app_private.refresh_delivery_zone_learning() from anon;
revoke all on function app_private.refresh_delivery_zone_learning() from authenticated;
grant execute on function app_private.refresh_delivery_zone_learning() to authenticated;

create or replace function public.run_delivery_zone_learning()
returns integer
language sql
volatile
security invoker
set search_path = ''
as $$
  select app_private.refresh_delivery_zone_learning();
$$;

revoke all on function public.run_delivery_zone_learning() from public;
grant execute on function public.run_delivery_zone_learning() to authenticated;
grant execute on function public.run_delivery_zone_learning() to service_role;

create or replace function public.manage_delivery_zone_learning_candidate(
  p_candidate_id uuid,
  p_action text
)
returns text
language plpgsql
security invoker
set search_path = ''
as $$
declare
  candidate_record record;
  zone_record record;
  latest_applied_id uuid;
begin
  if app_private.current_user_role() <> 'admin' then
    raise exception 'admin_role_required'
      using errcode = '42501';
  end if;

  select candidate.*
  into candidate_record
  from public.delivery_zone_learning_candidates as candidate
  where candidate.id = p_candidate_id
  for update;

  if candidate_record.id is null then
    raise exception 'learning_candidate_not_found'
      using errcode = 'P0002';
  end if;

  if p_action = 'ignore' then
    update public.delivery_zone_learning_candidates
    set status = 'ignored',
        ignored_at = now(),
        last_error = null
    where id = candidate_record.id
      and status in ('observing', 'needs_review');
  elsif p_action = 'observe' then
    update public.delivery_zone_learning_candidates
    set status = 'observing',
        ignored_at = null,
        reverted_at = null,
        last_error = null
    where id = candidate_record.id
      and status in ('ignored', 'reverted', 'needs_review');
  elsif p_action = 'revert' then
    if candidate_record.status <> 'applied' or candidate_record.boundary_before is null then
      raise exception 'learning_candidate_not_applied'
        using errcode = '23514';
    end if;

    select candidate.id
    into latest_applied_id
    from public.delivery_zone_learning_candidates as candidate
    where candidate.zone_id = candidate_record.zone_id
      and candidate.status = 'applied'
    order by candidate.applied_at desc, candidate.id desc
    limit 1;

    if latest_applied_id is distinct from candidate_record.id then
      raise exception 'only_latest_learning_change_can_be_reverted'
        using errcode = '23514';
    end if;

    select zone.*
    into zone_record
    from public.delivery_zones as zone
    where zone.id = candidate_record.zone_id
    for update;

    if candidate_record.boundary_after is not null
      and not extensions.st_equals(zone_record.boundary, candidate_record.boundary_after)
    then
      raise exception 'zone_boundary_changed_after_learning'
        using errcode = '23514';
    end if;

    update public.delivery_zones
    set boundary = candidate_record.boundary_before,
        last_learning_at = now()
    where id = candidate_record.zone_id;

    update public.delivery_zone_learning_candidates
    set status = 'reverted',
        reverted_at = now(),
        last_error = null
    where id = candidate_record.id;

    update public.orders as delivery_order
    set delivery_zone_id = null
    where delivery_order.delivery_zone_id = candidate_record.zone_id
      and delivery_order.lat is not null
      and delivery_order.lng is not null
      and not extensions.st_covers(
        candidate_record.boundary_before,
        extensions.st_setsrid(
          extensions.st_point(delivery_order.lng::double precision, delivery_order.lat::double precision),
          4326
        )
      );
  else
    raise exception 'unsupported_learning_candidate_action'
      using errcode = '22023';
  end if;

  return p_action;
end;
$$;

revoke all on function public.manage_delivery_zone_learning_candidate(uuid, text) from public;
grant execute on function public.manage_delivery_zone_learning_candidate(uuid, text) to authenticated;
grant execute on function public.manage_delivery_zone_learning_candidate(uuid, text) to service_role;

drop function public.list_delivery_zones();
create function public.list_delivery_zones()
returns table (
  id uuid,
  name text,
  color text,
  boundary jsonb,
  priority integer,
  is_active boolean,
  customer_order_enabled boolean,
  auto_expand_enabled boolean,
  learning_min_deliveries integer,
  learning_lookback_days integer,
  learning_max_distance_m integer,
  learning_radius_m integer,
  last_learning_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    zone.id,
    zone.name,
    zone.color,
    extensions.st_asgeojson(zone.boundary, 7)::jsonb as boundary,
    zone.priority,
    zone.is_active,
    zone.customer_order_enabled,
    zone.auto_expand_enabled,
    zone.learning_min_deliveries,
    zone.learning_lookback_days,
    zone.learning_max_distance_m,
    zone.learning_radius_m,
    zone.last_learning_at,
    zone.created_at,
    zone.updated_at
  from public.delivery_zones as zone
  order by zone.priority, zone.name, zone.id;
$$;

revoke all on function public.list_delivery_zones() from public;
grant execute on function public.list_delivery_zones() to authenticated;
grant execute on function public.list_delivery_zones() to service_role;

drop function public.save_delivery_zone(text, text, jsonb, integer, boolean, boolean, uuid);
create function public.save_delivery_zone(
  p_name text,
  p_color text,
  p_boundary jsonb,
  p_priority integer,
  p_is_active boolean,
  p_customer_order_enabled boolean,
  p_auto_expand_enabled boolean,
  p_learning_min_deliveries integer,
  p_learning_lookback_days integer,
  p_learning_max_distance_m integer,
  p_learning_radius_m integer,
  p_id uuid default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  parsed_boundary extensions.geometry;
  saved_id uuid;
begin
  if app_private.current_user_role() <> 'admin' then
    raise exception 'admin_role_required'
      using errcode = '42501';
  end if;

  if p_boundary is null or jsonb_typeof(p_boundary) <> 'object' then
    raise exception 'invalid_delivery_zone_boundary'
      using errcode = '23514';
  end if;

  begin
    parsed_boundary := extensions.st_geomfromgeojson(p_boundary::text);
  exception
    when others then
      raise exception 'invalid_delivery_zone_boundary'
        using errcode = '23514';
  end;

  if parsed_boundary is null or extensions.geometrytype(parsed_boundary) <> 'POLYGON' then
    raise exception 'invalid_delivery_zone_boundary'
      using errcode = '23514';
  end if;

  parsed_boundary := extensions.st_setsrid(extensions.st_force2d(parsed_boundary), 4326);

  if p_id is null then
    insert into public.delivery_zones (
      name,
      color,
      boundary,
      priority,
      is_active,
      customer_order_enabled,
      auto_expand_enabled,
      learning_min_deliveries,
      learning_lookback_days,
      learning_max_distance_m,
      learning_radius_m,
      created_by,
      updated_by
    ) values (
      trim(p_name),
      p_color,
      parsed_boundary,
      p_priority,
      p_is_active,
      p_customer_order_enabled,
      p_auto_expand_enabled,
      p_learning_min_deliveries,
      p_learning_lookback_days,
      p_learning_max_distance_m,
      p_learning_radius_m,
      auth.uid(),
      auth.uid()
    )
    returning delivery_zones.id into saved_id;
  else
    update public.delivery_zones
    set name = trim(p_name),
        color = p_color,
        boundary = parsed_boundary,
        priority = p_priority,
        is_active = p_is_active,
        customer_order_enabled = p_customer_order_enabled,
        auto_expand_enabled = p_auto_expand_enabled,
        learning_min_deliveries = p_learning_min_deliveries,
        learning_lookback_days = p_learning_lookback_days,
        learning_max_distance_m = p_learning_max_distance_m,
        learning_radius_m = p_learning_radius_m,
        updated_by = auth.uid()
    where delivery_zones.id = p_id
    returning delivery_zones.id into saved_id;

    if saved_id is null then
      raise exception 'delivery_zone_not_found'
        using errcode = 'P0002';
    end if;
  end if;

  return saved_id;
end;
$$;

revoke all on function public.save_delivery_zone(
  text, text, jsonb, integer, boolean, boolean, boolean, integer, integer, integer, integer, uuid
) from public;
grant execute on function public.save_delivery_zone(
  text, text, jsonb, integer, boolean, boolean, boolean, integer, integer, integer, integer, uuid
) to authenticated;
grant execute on function public.save_delivery_zone(
  text, text, jsonb, integer, boolean, boolean, boolean, integer, integer, integer, integer, uuid
) to service_role;

comment on function public.save_delivery_zone(
  text, text, jsonb, integer, boolean, boolean, boolean, integer, integer, integer, integer, uuid
) is 'Creates or updates a delivery zone and its statistical learning rules. Only active admins may write.';

-- Recalculate existing completed deliveries once so the learning model starts
-- with real history rather than waiting for future orders only.
do $$
declare
  delivery_order record;
begin
  for delivery_order in
    select id
    from public.orders
    where state = 'delivered'
      and lat is not null
      and lng is not null
    order by delivery_date, created_at, id
  loop
    begin
      perform app_private.record_delivery_zone_observation(delivery_order.id);
    exception
      when others then
        raise warning 'delivery_zone_learning_backfill_failed order=% error=%', delivery_order.id, sqlerrm;
    end;
  end loop;
end
$$;

select pg_notify('pgrst', 'reload schema');
