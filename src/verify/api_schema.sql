-- Verify widgetwerkz:api_schema on pg

BEGIN;

select pg_catalog.has_schema_privilege('api', 'usage');
select pg_catalog.has_table_privilege('api.supplier', 'select');
select pg_catalog.has_table_privilege('api.part', 'select');
select pg_catalog.has_table_privilege('api.shipment', 'select');
select 1/count(rolname) from pg_catalog.pg_roles where rolname = 'web_anon';
select 1/count(rolname) from pg_catalog.pg_roles where rolname = 'manager';
select 1/count(rolname) from pg_catalog.pg_roles where rolname = 'worker';

ROLLBACK;
