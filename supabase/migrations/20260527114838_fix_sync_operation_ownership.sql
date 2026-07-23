-- Security fix: prevent a courier from completing/failing orders not assigned to them.
-- The trigger runs as security definer, so we check ownership explicitly.
-- Dispatchers and admins are exempt from the ownership check.

create or replace function app_private.process_sync_operation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_client_rating jsonb;
  v_rating integer;
  v_client_phone text;
  v_client_phone_normalized text;
  v_courier_id uuid;
begin
  if NEW.status != 'pending' then
    return NEW;
  end if;

  if NEW.operation_type = 'complete' and NEW.order_id is not null then

    -- Ownership check: couriers may only complete their own assigned orders.
    if app_private.current_user_role() not in ('dispatcher', 'admin') then
      if not exists (
        select 1 from public.orders
        where id = NEW.order_id
          and assigned_courier_id = app_private.current_courier_id()
      ) then
        return NEW;
      end if;
    end if;

    select
      o.client_phone,
      public.normalize_phone(o.client_phone),
      coalesce(NEW.courier_id, o.assigned_courier_id, app_private.current_courier_id())
    into v_client_phone, v_client_phone_normalized, v_courier_id
    from public.orders o
    where o.id = NEW.order_id;

    v_client_rating := NEW.payload->'clientRating';

    update public.orders
    set
      state = 'delivered',
      delivered_bottles = (NEW.payload->>'bottles')::integer,
      returned_bottles  = (NEW.payload->>'returnedBottles')::integer,
      confirmed_payment = (NEW.payload->>'paymentType')::public.payment_method,
      delivery_comment  = nullif(NEW.payload->>'comment', ''),
      scanned_items     = coalesce(NEW.payload->'scannedItems', '{}'::jsonb),
      marking_codes     = coalesce(NEW.payload->'markingCodes', '{}'::jsonb),
      fiscal_receipt    = coalesce(
        NEW.payload->'fiscalReceipt',
        '{"status":"not_required"}'::jsonb
      ),
      client_rating     = v_client_rating,
      updated_by        = NEW.actor_profile_id,
      version           = version + 1
    where id = NEW.order_id;

    if jsonb_typeof(v_client_rating) = 'object'
       and coalesce(v_client_rating->>'rating', '') ~ '^\d+$' then
      v_rating := least(5, greatest(1, (v_client_rating->>'rating')::integer));

      insert into public.client_ratings (
        order_id,
        courier_id,
        actor_profile_id,
        client_phone,
        client_phone_normalized,
        rating
      )
      values (
        NEW.order_id,
        v_courier_id,
        NEW.actor_profile_id,
        v_client_phone,
        v_client_phone_normalized,
        v_rating
      )
      on conflict (order_id) do nothing;
    end if;

    insert into public.order_events (order_id, actor_profile_id, event_type, payload)
    values (NEW.order_id, NEW.actor_profile_id, 'delivered', NEW.payload);

    NEW.status   := 'acked';
    NEW.acked_at := now();

  elsif NEW.operation_type = 'fail' and NEW.order_id is not null then

    -- Ownership check: couriers may only fail their own assigned orders.
    if app_private.current_user_role() not in ('dispatcher', 'admin') then
      if not exists (
        select 1 from public.orders
        where id = NEW.order_id
          and assigned_courier_id = app_private.current_courier_id()
      ) then
        return NEW;
      end if;
    end if;

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

revoke all on function app_private.process_sync_operation() from public;
