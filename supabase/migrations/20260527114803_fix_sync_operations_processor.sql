-- Fix 1: operation_id was uuid but Flutter sends complete-orderId-timestamp strings
alter table public.sync_operations alter column operation_id type text;

-- Fix 2: trigger that processes pending sync_operations and updates orders
create or replace function app_private.process_sync_operation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if NEW.status != 'pending' then
    return NEW;
  end if;

  if NEW.operation_type = 'complete' and NEW.order_id is not null then
    update public.orders
    set
      state = 'delivered',
      delivered_bottles = (NEW.payload->>'bottles')::integer,
      returned_bottles  = (NEW.payload->>'returnedBottles')::integer,
      confirmed_payment = (NEW.payload->>'paymentType')::public.payment_method,
      delivery_comment  = nullif(NEW.payload->>'comment', ''),
      scanned_items     = coalesce(NEW.payload->'scannedItems', '{}'::jsonb),
      updated_by        = NEW.actor_profile_id,
      version           = version + 1
    where id = NEW.order_id;

    insert into public.order_events (order_id, actor_profile_id, event_type, payload)
    values (NEW.order_id, NEW.actor_profile_id, 'delivered', NEW.payload);

    NEW.status   := 'acked';
    NEW.acked_at := now();

  elsif NEW.operation_type = 'fail' and NEW.order_id is not null then
    update public.orders
    set
      state          = 'failed',
      failure_reason = NEW.payload->>'reason',
      updated_by     = NEW.actor_profile_id,
      version        = version + 1
    where id = NEW.order_id;

    insert into public.order_events (order_id, actor_profile_id, event_type, payload)
    values (NEW.order_id, NEW.actor_profile_id, 'failed', NEW.payload);

    NEW.status   := 'acked';
    NEW.acked_at := now();
  end if;

  return NEW;
end;
$$;

create or replace trigger sync_operations_process
before insert on public.sync_operations
for each row execute function app_private.process_sync_operation();

revoke all on function app_private.process_sync_operation() from public;
