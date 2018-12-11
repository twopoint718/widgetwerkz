-- Revert widgetwerkz:user_management from pg

BEGIN;

drop function   login;
drop trigger    ensure_user_role_exists on basic_auth.users;
drop trigger    encrypt_pass on basic_auth.users;
drop function   basic_auth.check_role_exists;
drop function   basic_auth.user_role;
drop function   basic_auth.encrypt_pass;
drop type       basic_auth.jwt_token;
drop table      basic_auth.users;
drop schema     basic_auth;
drop extension  pgjwt;
drop extension  pgcrypto;

COMMIT;
