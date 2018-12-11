-- Deploy widgetwerkz:user_management to pg

BEGIN;

--------------------------------------------------------------------------------
-- SCHEMA/EXTENSIONS

create schema if not exists basic_auth;
create extension if not exists pgcrypto; -- password hashing
create extension if not exists pgjwt;    -- generate JWT tokens


--------------------------------------------------------------------------------
-- TYPES

create type basic_auth.jwt_token as (
  token text
);


--------------------------------------------------------------------------------
-- USER ROLES

-- We put things inside the basic_auth schema to hide
-- them from public view. Certain public procs/views will
-- refer to helpers and tables inside.
create table if not exists
basic_auth.users (
    email    text primary key check ( email ~* '^.+@.+\..+$' ),
    pass     text not null check (length(pass) < 512),
    role     name not null check (length(role) < 512)
);

-- Ideally this would be a FK against the 'pg_roles' table. Instead, we'll use
-- a trigger to check that a users' role exists as an actual DB role.
create or replace function
basic_auth.check_role_exists() returns trigger as $$
begin
  if not exists (select 1 from pg_roles as r where r.rolname = new.role) then
    raise foreign_key_violation using message =
      'unknown database role: ' || new.role;
    return null;
  end if;
  return new;
end
$$ language plpgsql;

create constraint trigger ensure_user_role_exists
    after insert or update on basic_auth.users
    for each row
    execute procedure basic_auth.check_role_exists();


--------------------------------------------------------------------------------
-- USER PASSWORDS

-- Salt and blowfish hash a new or changed user password
create or replace function
basic_auth.encrypt_pass() returns trigger as $$
begin
    if tg_op = 'INSERT' or new.pass <> old.pass then
        new.pass = crypt(new.pass, gen_salt('bf'));
    end if;
    return new;
end
$$ language plpgsql;

-- Ensure password is encrypted prior to being stored
create trigger encrypt_pass
    before insert or update on basic_auth.users
    for each row
    execute procedure basic_auth.encrypt_pass();

-- Check encrypted password, returns role if password OK
create or replace function
basic_auth.user_role(email text, pass text) returns name
  language plpgsql
  as $$
begin
  return (
    select role from basic_auth.users
    where users.email = user_role.email
    and users.pass = crypt(user_role.pass, users.pass)
  );
end;
$$;


--------------------------------------------------------------------------------
-- USER LOGIN

-- login should be on exposed schema (public). This procedure returns a JWT
-- after the user successfully authenticates using email + password. Subsequent
-- API requests use the returned JWT.
create or replace function
login(email text, pass text) returns basic_auth.jwt_token as $$
declare
  _role name;
  result basic_auth.jwt_token;
begin
  -- check email and password
  select basic_auth.user_role(email, pass) into _role;
  if _role is null then
    raise invalid_password using message = 'invalid user or password';
  end if;

  select sign(row_to_json(r), current_setting('app.jwt_secret')) as token
  from (
    select
      _role as role,
      login.email as email,
      extract(epoch from now())::integer + 60*60 as exp
  ) r
  into result;
  return result;
end;
$$ language plpgsql;

COMMIT;
