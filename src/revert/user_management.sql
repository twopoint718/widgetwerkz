-- Revert widgetwerkz:user_management from pg

BEGIN;

-- Public functions
drop function if exists public.signup(text, text);
drop function if exists public.verify(text);
drop function if exists public.login(text, text);

drop schema if exists auth cascade;

COMMIT;
