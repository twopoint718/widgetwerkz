-- Revert widgetwerkz:user_management from pg

BEGIN;

drop schema if exists auth cascade;
drop function if exists signup;
drop function if exists verify(text);
drop extension if exists pgjwt;
drop extension if exists pgcrypto;

COMMIT;
