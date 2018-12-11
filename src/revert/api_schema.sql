-- Revert widgetwerkz:api_schema from pg

BEGIN;

drop policy worker_london_parts_access on api.part;
drop table api.shipment;
drop table api.supplier;
drop table api.part;
drop type api.color;
revoke all privileges on all tables in schema api FROM web_anon;
revoke all privileges on all tables in schema api FROM manager;
revoke all privileges on all tables in schema api FROM worker;
revoke web_anon from postgres;
revoke manager from postgres;
revoke worker from postgres;
revoke usage on schema api from web_anon;
revoke usage on schema api from manager;
revoke usage on schema api from worker;
drop role web_anon;
drop role manager;
drop role worker;
drop schema api;

COMMIT;
