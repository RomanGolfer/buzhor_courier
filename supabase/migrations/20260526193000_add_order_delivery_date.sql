alter table public.orders
add column if not exists delivery_date date;

update public.orders
set delivery_date = (created_at at time zone 'Europe/Moscow')::date
where delivery_date is null;

alter table public.orders
alter column delivery_date set default ((now() at time zone 'Europe/Moscow')::date);

alter table public.orders
alter column delivery_date set not null;

create index if not exists orders_delivery_date_idx
on public.orders(delivery_date);
