-- The RPC performs its own role, identity, activity and coordinate checks.
-- Run only its narrowly scoped update with the function owner's privileges so
-- courier clients never need a broad direct UPDATE policy on couriers.
alter function public.report_courier_location(numeric, numeric, numeric)
  security definer;
