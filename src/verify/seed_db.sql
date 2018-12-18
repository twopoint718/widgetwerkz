-- Verify widgetwerkz:seed_db on pg

BEGIN;

select 1/count(*) from public.supplier;
select 1/count(*) from public.part;
select 1/count(*) from public.shipment;

ROLLBACK;
