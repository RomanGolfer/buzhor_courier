alter function public.check_delivery_coverage(double precision, double precision)
security invoker;

revoke all on function public.check_delivery_coverage(double precision, double precision) from public;
revoke all on function public.check_delivery_coverage(double precision, double precision) from anon;
revoke all on function public.check_delivery_coverage(double precision, double precision) from authenticated;
grant execute on function public.check_delivery_coverage(double precision, double precision) to service_role;

comment on function public.check_delivery_coverage(double precision, double precision) is
  'Server-only coverage check used by the rate-limited delivery coverage endpoint.';

select pg_notify('pgrst', 'reload schema');
