-- Verify widgetwerkz:api_schema on pg

BEGIN;

select pg_catalog.has_schema_privilege('public', 'usage');
select pg_catalog.has_table_privilege('public.supplier', 'select');
select pg_catalog.has_table_privilege('public.part', 'select');
select pg_catalog.has_table_privilege('public.shipment', 'select');
select 1/count(rolname) from pg_catalog.pg_roles where rolname = 'web_anon';
select 1/count(rolname) from pg_catalog.pg_roles where rolname = 'manager';
select 1/count(rolname) from pg_catalog.pg_roles where rolname = 'worker';

-- worker is allowed to insert London-based parts
delete from public.part where pid = 999;
insert into public.part (pid, pname, color, weight, city) values (999, 'Name', 'Red', 1.0, 'London');

-- Check the opposite, worker should NOT be allowed to insert non-London parts
create or replace function test_worker_access() returns integer as
$$
begin
  set role worker;
  insert into public.part (pid, pname, color, weight, city)
    values (999, 'Name', 'Red', 1.0, 'Not London');
  -- previous line causes an exception which is harmlessly caught
  select 1/0; -- Test fails
exception
  when insufficient_privilege then
    -- Test passes
    return 1;
end
$$ language plpgsql;

delete from public.part where pid = 999;
select test_worker_access();

ROLLBACK;
