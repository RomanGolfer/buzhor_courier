-- Drop the duplicate courier_select policy on orders that overlaps with
-- orders_select_assigned_or_staff. The latter is the canonical policy.
drop policy if exists courier_select on public.orders;
