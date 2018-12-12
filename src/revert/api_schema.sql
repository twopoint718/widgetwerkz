-- Revert widgetwerkz:api_schema from pg

BEGIN;

drop policy worker_london_parts_access on public.part;
drop table public.shipment;
drop table public.supplier;
drop table public.part;
drop type public.color;
revoke all privileges on all tables in schema public FROM web_anon;
revoke all privileges on all tables in schema public FROM manager;
revoke all privileges on all tables in schema public FROM worker;
revoke web_anon from postgres;
revoke manager from postgres;
revoke worker from postgres;
revoke usage on schema public from web_anon;
revoke usage on schema public from manager;
revoke usage on schema public from worker;
drop role web_anon;
drop role manager;
drop role worker;

COMMIT;
