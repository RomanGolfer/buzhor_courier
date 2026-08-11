create or replace function public.assign_vehicle(
  p_vehicle_id uuid,
  p_courier_id uuid,
  p_note text default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  existing_assignment_id uuid;
  saved_assignment_id uuid;
begin
  if app_private.current_user_role() not in ('dispatcher', 'admin') then
    raise exception 'staff_role_required'
      using errcode = '42501';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('vehicle:' || p_vehicle_id::text, 0)
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('courier:' || p_courier_id::text, 0)
  );

  perform 1
  from public.vehicles vehicle
  where vehicle.id = p_vehicle_id
    and vehicle.service_status = 'ready';

  if not found then
    raise exception 'vehicle_not_ready_or_missing'
      using errcode = 'P0002';
  end if;

  perform 1
  from public.couriers courier
  join public.profiles profile on profile.id = courier.profile_id
  where courier.id = p_courier_id
    and courier.is_active = true
    and profile.is_active = true
    and profile.role = 'courier';

  if not found then
    raise exception 'active_courier_not_found'
      using errcode = 'P0002';
  end if;

  select assignment.id
  into existing_assignment_id
  from public.vehicle_assignments assignment
  where assignment.vehicle_id = p_vehicle_id
    and assignment.courier_id = p_courier_id
    and assignment.released_at is null;

  if existing_assignment_id is not null then
    return existing_assignment_id;
  end if;

  update public.vehicle_assignments assignment
  set released_at = now(),
      released_by = auth.uid(),
      release_note = 'Автоматически освобождён при переназначении'
  where assignment.released_at is null
    and (
      assignment.vehicle_id = p_vehicle_id
      or assignment.courier_id = p_courier_id
    );

  insert into public.vehicle_assignments (
    vehicle_id,
    courier_id,
    assigned_by,
    assignment_note
  )
  values (
    p_vehicle_id,
    p_courier_id,
    auth.uid(),
    nullif(trim(p_note), '')
  )
  returning vehicle_assignments.id into saved_assignment_id;

  return saved_assignment_id;
end;
$$;

create or replace function public.release_vehicle(
  p_vehicle_id uuid,
  p_note text default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  released_assignment_id uuid;
begin
  if app_private.current_user_role() not in ('dispatcher', 'admin') then
    raise exception 'staff_role_required'
      using errcode = '42501';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('vehicle:' || p_vehicle_id::text, 0)
  );

  perform 1
  from public.vehicles vehicle
  where vehicle.id = p_vehicle_id;

  if not found then
    raise exception 'vehicle_not_found'
      using errcode = 'P0002';
  end if;

  update public.vehicle_assignments assignment
  set released_at = now(),
      released_by = auth.uid(),
      release_note = coalesce(nullif(trim(p_note), ''), 'Автомобиль освобождён диспетчером')
  where assignment.vehicle_id = p_vehicle_id
    and assignment.released_at is null
  returning assignment.id into released_assignment_id;

  if released_assignment_id is null then
    raise exception 'active_vehicle_assignment_not_found'
      using errcode = 'P0002';
  end if;

  return released_assignment_id;
end;
$$;

comment on function public.assign_vehicle(uuid, uuid, text) is
  'Uses transaction-scoped advisory locks so dispatchers can assign safely without vehicle UPDATE permission.';

select pg_notify('pgrst', 'reload schema');
