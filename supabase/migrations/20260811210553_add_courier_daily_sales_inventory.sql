create table public.courier_daily_inventory (
  id uuid primary key default gen_random_uuid(),
  courier_id uuid not null references public.couriers(id) on delete restrict,
  work_date date not null,
  loaded_full_bottles integer not null default 0
    check (loaded_full_bottles between 0 and 100000),
  opening_empty_bottles integer not null default 0
    check (opening_empty_bottles between 0 and 100000),
  unloaded_full_bottles integer not null default 0
    check (unloaded_full_bottles between 0 and 100000),
  unloaded_empty_bottles integer not null default 0
    check (unloaded_empty_bottles between 0 and 100000),
  notes text,
  created_by uuid references public.profiles(id) on delete set null default auth.uid(),
  updated_by uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint courier_daily_inventory_courier_date_key unique (courier_id, work_date),
  constraint courier_daily_inventory_work_date_check check (work_date >= date '2020-01-01')
);

create index courier_daily_inventory_work_date_idx
on public.courier_daily_inventory (work_date, courier_id);

create index orders_daily_courier_sales_idx
on public.orders (delivery_date, assigned_courier_id, state)
where assigned_courier_id is not null;

create trigger courier_daily_inventory_touch_updated_at
before update on public.courier_daily_inventory
for each row execute function app_private.touch_updated_at();

alter table public.courier_daily_inventory enable row level security;

revoke all privileges on table public.courier_daily_inventory from anon, authenticated;
grant select on table public.courier_daily_inventory to authenticated;
grant insert (
  courier_id,
  work_date,
  loaded_full_bottles,
  opening_empty_bottles,
  unloaded_full_bottles,
  unloaded_empty_bottles,
  notes,
  created_by,
  updated_by
) on table public.courier_daily_inventory to authenticated;
grant update (
  loaded_full_bottles,
  opening_empty_bottles,
  unloaded_full_bottles,
  unloaded_empty_bottles,
  notes,
  updated_by
) on table public.courier_daily_inventory to authenticated;
grant all privileges on table public.courier_daily_inventory to service_role;

create policy courier_daily_inventory_staff_select
on public.courier_daily_inventory
for select
to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'));

create policy courier_daily_inventory_staff_insert
on public.courier_daily_inventory
for insert
to authenticated
with check (
  (select app_private.current_user_role()) in ('dispatcher', 'admin')
  and created_by = (select auth.uid())
  and updated_by = (select auth.uid())
  and exists (
    select 1
    from public.couriers courier
    where courier.id = courier_daily_inventory.courier_id
  )
);

create policy courier_daily_inventory_staff_update
on public.courier_daily_inventory
for update
to authenticated
using ((select app_private.current_user_role()) in ('dispatcher', 'admin'))
with check (
  (select app_private.current_user_role()) in ('dispatcher', 'admin')
  and updated_by = (select auth.uid())
);

create or replace function public.list_courier_daily_sales(p_work_date date)
returns table (
  courier_id uuid,
  courier_name text,
  courier_phone text,
  courier_region text,
  courier_active boolean,
  vehicle_plate text,
  work_date date,
  delivered_orders bigint,
  active_orders bigint,
  failed_orders bigint,
  cash_orders bigint,
  cash_amount numeric,
  card_orders bigint,
  card_amount numeric,
  qr_orders bigint,
  qr_amount numeric,
  online_orders bigint,
  online_amount numeric,
  contract_orders bigint,
  contract_amount numeric,
  total_amount numeric,
  sold_full_bottles bigint,
  collected_empty_bottles bigint,
  inventory_configured boolean,
  loaded_full_bottles integer,
  opening_empty_bottles integer,
  unloaded_full_bottles integer,
  unloaded_empty_bottles integer,
  remaining_full_bottles bigint,
  remaining_empty_bottles bigint,
  inventory_notes text,
  inventory_updated_at timestamptz
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if app_private.current_user_role() not in ('dispatcher', 'admin') then
    raise exception 'staff_role_required'
      using errcode = '42501';
  end if;

  if p_work_date is null or p_work_date < date '2020-01-01' then
    raise exception 'invalid_work_date'
      using errcode = '22007';
  end if;

  return query
  with courier_scope as (
    select
      courier.id,
      courier.display_name,
      courier.phone,
      courier.region,
      courier.is_active
    from public.couriers courier
    where courier.is_active = true

    union

    select
      courier.id,
      courier.display_name,
      courier.phone,
      courier.region,
      courier.is_active
    from public.couriers courier
    join public.orders customer_order on customer_order.assigned_courier_id = courier.id
    where customer_order.delivery_date = p_work_date

    union

    select
      courier.id,
      courier.display_name,
      courier.phone,
      courier.region,
      courier.is_active
    from public.couriers courier
    join public.courier_daily_inventory inventory on inventory.courier_id = courier.id
    where inventory.work_date = p_work_date
  ),
  daily_sales as (
    select
      customer_order.assigned_courier_id as courier_id,
      count(*) filter (where customer_order.state = 'delivered') as delivered_orders,
      count(*) filter (where customer_order.state in ('assigned', 'accepted', 'in_progress')) as active_orders,
      count(*) filter (where customer_order.state = 'failed') as failed_orders,
      count(*) filter (
        where customer_order.state = 'delivered'
          and coalesce(customer_order.confirmed_payment, customer_order.payment_method) = 'cash'
      ) as cash_orders,
      coalesce(sum(customer_order.price) filter (
        where customer_order.state = 'delivered'
          and coalesce(customer_order.confirmed_payment, customer_order.payment_method) = 'cash'
      ), 0) as cash_amount,
      count(*) filter (
        where customer_order.state = 'delivered'
          and coalesce(customer_order.confirmed_payment, customer_order.payment_method) = 'card'
      ) as card_orders,
      coalesce(sum(customer_order.price) filter (
        where customer_order.state = 'delivered'
          and coalesce(customer_order.confirmed_payment, customer_order.payment_method) = 'card'
      ), 0) as card_amount,
      count(*) filter (
        where customer_order.state = 'delivered'
          and coalesce(customer_order.confirmed_payment, customer_order.payment_method) = 'qr'
      ) as qr_orders,
      coalesce(sum(customer_order.price) filter (
        where customer_order.state = 'delivered'
          and coalesce(customer_order.confirmed_payment, customer_order.payment_method) = 'qr'
      ), 0) as qr_amount,
      count(*) filter (
        where customer_order.state = 'delivered'
          and coalesce(customer_order.confirmed_payment, customer_order.payment_method) = 'online'
      ) as online_orders,
      coalesce(sum(customer_order.price) filter (
        where customer_order.state = 'delivered'
          and coalesce(customer_order.confirmed_payment, customer_order.payment_method) = 'online'
      ), 0) as online_amount,
      count(*) filter (
        where customer_order.state = 'delivered'
          and coalesce(customer_order.confirmed_payment, customer_order.payment_method) = 'contract'
      ) as contract_orders,
      coalesce(sum(customer_order.price) filter (
        where customer_order.state = 'delivered'
          and coalesce(customer_order.confirmed_payment, customer_order.payment_method) = 'contract'
      ), 0) as contract_amount,
      coalesce(sum(customer_order.price) filter (where customer_order.state = 'delivered'), 0) as total_amount,
      coalesce(sum(coalesce(customer_order.delivered_bottles, customer_order.bottles, 0)) filter (
        where customer_order.state = 'delivered'
      ), 0) as sold_full_bottles,
      coalesce(sum(coalesce(customer_order.returned_bottles, 0)) filter (
        where customer_order.state = 'delivered'
      ), 0) as collected_empty_bottles
    from public.orders customer_order
    where customer_order.delivery_date = p_work_date
      and customer_order.assigned_courier_id is not null
    group by customer_order.assigned_courier_id
  )
  select
    courier.id,
    courier.display_name,
    courier.phone,
    courier.region,
    courier.is_active,
    assigned_vehicle.license_plate,
    p_work_date,
    coalesce(sales.delivered_orders, 0),
    coalesce(sales.active_orders, 0),
    coalesce(sales.failed_orders, 0),
    coalesce(sales.cash_orders, 0),
    coalesce(sales.cash_amount, 0),
    coalesce(sales.card_orders, 0),
    coalesce(sales.card_amount, 0),
    coalesce(sales.qr_orders, 0),
    coalesce(sales.qr_amount, 0),
    coalesce(sales.online_orders, 0),
    coalesce(sales.online_amount, 0),
    coalesce(sales.contract_orders, 0),
    coalesce(sales.contract_amount, 0),
    coalesce(sales.total_amount, 0),
    coalesce(sales.sold_full_bottles, 0),
    coalesce(sales.collected_empty_bottles, 0),
    inventory.id is not null,
    coalesce(inventory.loaded_full_bottles, 0),
    coalesce(inventory.opening_empty_bottles, 0),
    coalesce(inventory.unloaded_full_bottles, 0),
    coalesce(inventory.unloaded_empty_bottles, 0),
    case
      when inventory.id is null then null
      else inventory.loaded_full_bottles
        - coalesce(sales.sold_full_bottles, 0)
        - inventory.unloaded_full_bottles
    end,
    case
      when inventory.id is null then null
      else inventory.opening_empty_bottles
        + coalesce(sales.collected_empty_bottles, 0)
        - inventory.unloaded_empty_bottles
    end,
    inventory.notes,
    inventory.updated_at
  from courier_scope courier
  left join daily_sales sales on sales.courier_id = courier.id
  left join public.courier_daily_inventory inventory
    on inventory.courier_id = courier.id
    and inventory.work_date = p_work_date
  left join lateral (
    select vehicle.license_plate
    from public.vehicle_assignments assignment
    join public.vehicles vehicle on vehicle.id = assignment.vehicle_id
    where assignment.courier_id = courier.id
      and assignment.assigned_at < ((p_work_date + 1)::timestamp at time zone 'Europe/Moscow')
      and (
        assignment.released_at is null
        or assignment.released_at >= (p_work_date::timestamp at time zone 'Europe/Moscow')
      )
    order by assignment.assigned_at desc
    limit 1
  ) assigned_vehicle on true
  order by courier.is_active desc, courier.display_name;
end;
$$;

create or replace function public.save_courier_daily_inventory(
  p_courier_id uuid,
  p_work_date date,
  p_loaded_full_bottles integer,
  p_opening_empty_bottles integer,
  p_unloaded_full_bottles integer,
  p_unloaded_empty_bottles integer,
  p_notes text default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  saved_inventory_id uuid;
begin
  if app_private.current_user_role() not in ('dispatcher', 'admin') then
    raise exception 'staff_role_required'
      using errcode = '42501';
  end if;

  if p_work_date is null or p_work_date < date '2020-01-01' then
    raise exception 'invalid_work_date'
      using errcode = '22007';
  end if;

  if p_loaded_full_bottles is null or p_loaded_full_bottles not between 0 and 100000
    or p_opening_empty_bottles is null or p_opening_empty_bottles not between 0 and 100000
    or p_unloaded_full_bottles is null or p_unloaded_full_bottles not between 0 and 100000
    or p_unloaded_empty_bottles is null or p_unloaded_empty_bottles not between 0 and 100000 then
    raise exception 'invalid_inventory_quantity'
      using errcode = '22003';
  end if;

  if not exists (select 1 from public.couriers courier where courier.id = p_courier_id) then
    raise exception 'courier_not_found'
      using errcode = 'P0002';
  end if;

  insert into public.courier_daily_inventory (
    courier_id,
    work_date,
    loaded_full_bottles,
    opening_empty_bottles,
    unloaded_full_bottles,
    unloaded_empty_bottles,
    notes,
    created_by,
    updated_by
  )
  values (
    p_courier_id,
    p_work_date,
    p_loaded_full_bottles,
    p_opening_empty_bottles,
    p_unloaded_full_bottles,
    p_unloaded_empty_bottles,
    nullif(trim(p_notes), ''),
    auth.uid(),
    auth.uid()
  )
  on conflict (courier_id, work_date) do update
  set loaded_full_bottles = excluded.loaded_full_bottles,
      opening_empty_bottles = excluded.opening_empty_bottles,
      unloaded_full_bottles = excluded.unloaded_full_bottles,
      unloaded_empty_bottles = excluded.unloaded_empty_bottles,
      notes = excluded.notes,
      updated_by = auth.uid()
  returning courier_daily_inventory.id into saved_inventory_id;

  return saved_inventory_id;
end;
$$;

revoke all on function public.list_courier_daily_sales(date) from public, anon, authenticated;
revoke all on function public.save_courier_daily_inventory(uuid, date, integer, integer, integer, integer, text) from public, anon, authenticated;

grant execute on function public.list_courier_daily_sales(date) to authenticated, service_role;
grant execute on function public.save_courier_daily_inventory(uuid, date, integer, integer, integer, integer, text) to authenticated, service_role;

comment on table public.courier_daily_inventory is
  'Dispatcher-entered daily vehicle load and warehouse unload values used to calculate full and empty bottle balances.';

comment on function public.list_courier_daily_sales(date) is
  'Returns per-courier daily sales by confirmed payment method plus delivered bottles, collected tare and vehicle balances.';

select pg_notify('pgrst', 'reload schema');
