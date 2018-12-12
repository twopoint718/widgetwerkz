-- Revert widgetwerkz:user_management from pg

BEGIN;

drop function   login;
drop trigger    ensure_user_role_exists on auth.users;
drop trigger    encrypt_signup_pass on auth.signup;
drop function   auth.check_role_exists;
drop function   auth.user_role;
drop function   auth.encrypt_pass;
drop type       auth.jwt_token;
drop table      auth.users;
drop table      auth.signup;
drop schema     auth;
drop extension  pgjwt;
drop extension  pgcrypto;

COMMIT;
