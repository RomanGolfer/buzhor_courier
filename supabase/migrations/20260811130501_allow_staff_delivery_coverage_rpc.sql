grant execute on function public.check_delivery_coverage(double precision, double precision) to authenticated;

comment on function public.check_delivery_coverage(double precision, double precision) is
  'Coverage check used by the authenticated, rate-limited dispatcher endpoint.';

select pg_notify('pgrst', 'reload schema');
