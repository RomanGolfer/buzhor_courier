drop policy if exists delivery_zones_staff_insert on public.delivery_zones;
create policy delivery_zones_staff_insert
on public.delivery_zones
for insert
to authenticated
with check (app_private.current_user_role() = 'admin');

drop policy if exists delivery_zones_staff_update on public.delivery_zones;
create policy delivery_zones_staff_update
on public.delivery_zones
for update
to authenticated
using (app_private.current_user_role() = 'admin')
with check (app_private.current_user_role() = 'admin');

drop policy if exists delivery_zones_staff_delete on public.delivery_zones;
create policy delivery_zones_staff_delete
on public.delivery_zones
for delete
to authenticated
using (app_private.current_user_role() = 'admin');

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

comment on function public.save_delivery_zone(text, text, jsonb, integer, boolean, boolean, uuid) is
  'Creates or updates a delivery zone. Only active admin profiles may execute a successful write.';

select pg_notify('pgrst', 'reload schema');
