alter table public.orders
add column if not exists time_slot text;

create index if not exists orders_time_slot_idx on public.orders(time_slot);
