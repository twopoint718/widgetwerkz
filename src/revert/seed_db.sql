-- Revert widgetwerkz:seed_db from pg

BEGIN;

delete from public.shipment;
delete from public.supplier;
delete from public.part;

COMMIT;
