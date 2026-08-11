create extension if not exists postgis with schema extensions;

create table public.delivery_zones (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  color text not null default '#16a34a',
  boundary extensions.geometry(Polygon, 4326) not null,
  priority integer not null default 100,
  is_active boolean not null default true,
  customer_order_enabled boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint delivery_zones_name_length check (char_length(trim(name)) between 1 and 80),
  constraint delivery_zones_color_format check (color ~ '^#[0-9a-fA-F]{6}$'),
  constraint delivery_zones_priority_range check (priority between 0 and 999)
);

comment on table public.delivery_zones is
  'Dispatcher-managed service areas used to assign orders to routes and validate customer delivery coverage.';
comment on column public.delivery_zones.boundary is
  'WGS84 polygon. GeoJSON coordinates must be provided in longitude, latitude order.';
comment on column public.delivery_zones.customer_order_enabled is
  'When false, staff can still use the zone operationally but customers cannot place orders inside it.';

create index delivery_zones_boundary_gix
on public.delivery_zones
using gist (boundary);

create index delivery_zones_active_priority_idx
on public.delivery_zones (is_active, priority, created_at);

create or replace trigger delivery_zones_touch_updated_at
before update on public.delivery_zones
for each row execute function app_private.touch_updated_at();

alter table public.orders
add column delivery_zone_id uuid references public.delivery_zones(id) on delete set null;

create index orders_delivery_zone_date_idx
on public.orders (delivery_zone_id, delivery_date)
where delivery_zone_id is not null;

create or replace function app_private.validate_delivery_zone_boundary()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.boundary is null
    or extensions.st_isempty(new.boundary)
    or extensions.geometrytype(new.boundary) <> 'POLYGON'
    or extensions.st_srid(new.boundary) <> 4326
    or not extensions.st_isvalid(new.boundary)
    or extensions.st_npoints(new.boundary) < 4
  then
    raise exception 'invalid_delivery_zone_boundary'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger delivery_zones_validate_boundary
before insert or update of boundary on public.delivery_zones
for each row execute function app_private.validate_delivery_zone_boundary();

create or replace function app_private.assign_order_delivery_zone()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.delivery_zone_id := null;

  if new.lat is null or new.lng is null then
    return new;
  end if;

  select zone.id
  into new.delivery_zone_id
  from public.delivery_zones as zone
  where zone.is_active
    and extensions.st_covers(
      zone.boundary,
      extensions.st_setsrid(
        extensions.st_point(new.lng::double precision, new.lat::double precision),
        4326
      )
    )
  order by zone.priority, zone.created_at, zone.id
  limit 1;

  return new;
end;
$$;

revoke all on function app_private.assign_order_delivery_zone() from public;
revoke all on function app_private.assign_order_delivery_zone() from anon;
revoke all on function app_private.assign_order_delivery_zone() from authenticated;

create trigger orders_assign_delivery_zone
before insert or update of lat, lng on public.orders
for each row execute function app_private.assign_order_delivery_zone();

alter table public.delivery_zones enable row level security;

grant select, insert, update, delete on table public.delivery_zones to authenticated;
grant all on table public.delivery_zones to service_role;

create policy delivery_zones_staff_select
on public.delivery_zones
for select
to authenticated
using (app_private.current_user_role() in ('dispatcher', 'admin'));

create policy delivery_zones_staff_insert
on public.delivery_zones
for insert
to authenticated
with check (app_private.current_user_role() in ('dispatcher', 'admin'));

create policy delivery_zones_staff_update
on public.delivery_zones
for update
to authenticated
using (app_private.current_user_role() in ('dispatcher', 'admin'))
with check (app_private.current_user_role() in ('dispatcher', 'admin'));

create policy delivery_zones_staff_delete
on public.delivery_zones
for delete
to authenticated
using (app_private.current_user_role() in ('dispatcher', 'admin'));

create or replace function public.list_delivery_zones()
returns table (
  id uuid,
  name text,
  color text,
  boundary jsonb,
  priority integer,
  is_active boolean,
  customer_order_enabled boolean,
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
    zone.created_at,
    zone.updated_at
  from public.delivery_zones as zone
  order by zone.priority, zone.name, zone.id;
$$;

revoke all on function public.list_delivery_zones() from public;
grant execute on function public.list_delivery_zones() to authenticated;
grant execute on function public.list_delivery_zones() to service_role;

create or replace function public.save_delivery_zone(
  p_name text,
  p_color text,
  p_boundary jsonb,
  p_priority integer,
  p_is_active boolean,
  p_customer_order_enabled boolean,
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
  if app_private.current_user_role() not in ('dispatcher', 'admin') then
    raise exception 'staff_role_required'
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
      created_by,
      updated_by
    )
    values (
      trim(p_name),
      p_color,
      parsed_boundary,
      p_priority,
      p_is_active,
      p_customer_order_enabled,
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

revoke all on function public.save_delivery_zone(text, text, jsonb, integer, boolean, boolean, uuid) from public;
grant execute on function public.save_delivery_zone(text, text, jsonb, integer, boolean, boolean, uuid) to authenticated;
grant execute on function public.save_delivery_zone(text, text, jsonb, integer, boolean, boolean, uuid) to service_role;

create or replace function public.check_delivery_coverage(
  p_lat double precision,
  p_lng double precision
)
returns table (
  configured boolean,
  available boolean,
  zone_id uuid,
  zone_name text,
  zone_color text
)
language sql
stable
security definer
set search_path = ''
as $$
  with settings as (
    select exists (
      select 1
      from public.delivery_zones as configured_zone
      where configured_zone.is_active
    ) as configured
  ), matching_zone as (
    select zone.id, zone.name, zone.color
    from public.delivery_zones as zone
    where zone.is_active
      and zone.customer_order_enabled
      and p_lat between -90 and 90
      and p_lng between -180 and 180
      and extensions.st_covers(
        zone.boundary,
        extensions.st_setsrid(extensions.st_point(p_lng, p_lat), 4326)
      )
    order by zone.priority, zone.created_at, zone.id
    limit 1
  )
  select
    settings.configured,
    matching_zone.id is not null as available,
    matching_zone.id as zone_id,
    matching_zone.name as zone_name,
    matching_zone.color as zone_color
  from settings
  left join matching_zone on true;
$$;

comment on function public.check_delivery_coverage(double precision, double precision) is
  'Public, bounded coverage check for customer order forms. It never exposes zone boundaries.';

revoke all on function public.check_delivery_coverage(double precision, double precision) from public;
grant execute on function public.check_delivery_coverage(double precision, double precision) to anon;
grant execute on function public.check_delivery_coverage(double precision, double precision) to authenticated;
grant execute on function public.check_delivery_coverage(double precision, double precision) to service_role;

select pg_notify('pgrst', 'reload schema');
