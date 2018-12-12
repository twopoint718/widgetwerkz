-- Deploy widgetwerkz:user_management to pg

BEGIN;

--------------------------------------------------------------------------------
-- SCHEMA/EXTENSIONS

create schema if not exists auth;
create extension if not exists pgcrypto; -- password hashing
create extension if not exists pgjwt;    -- generate JWT tokens


--------------------------------------------------------------------------------
-- TYPES

create type auth.jwt_token as (
  token text
);


--------------------------------------------------------------------------------
-- USER ROLES

-- We put things inside the auth schema to hide
-- them from public view. Certain public procs/views will
-- refer to helpers and tables inside.
create table if not exists
auth.users (
    email    text primary key check ( email ~* '^.+@.+\..+$' ),
    pass     text not null check (length(pass) < 512),
    role     name not null check (length(role) < 512)
);

-- Ideally this would be a FK against the 'pg_roles' table. Instead, we'll use
-- a trigger to check that a users' role exists as an actual DB role.
create or replace function
auth.check_role_exists() returns trigger as $$
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
    after insert or update on auth.users
    for each row
    execute procedure auth.check_role_exists();


--------------------------------------------------------------------------------
-- USER PASSWORDS

-- Salt and blowfish hash a new or changed user password
create or replace function
auth.encrypt_pass() returns trigger as $$
begin
    if tg_op = 'INSERT' or new.pass <> old.pass then
        new.pass = crypt(new.pass, gen_salt('bf'));
    end if;
    return new;
end
$$ language plpgsql;

-- Check encrypted password, returns role if password OK
create or replace function
auth.user_role(email text, pass text) returns name
  language plpgsql
  as $$
begin
  return (
    select role from auth.users
    where users.email = user_role.email
    and users.pass = crypt(user_role.pass, users.pass)
  );
end;
$$;


--------------------------------------------------------------------------------
-- USER SIGNUP

-- Users can sign themselves up via the signup procedure. They set their email
-- and password and then they get a challenge token to verify their email. If
-- they call the verify procedure with a matching challenge token then they're
-- added to the users table
create table auth.signup (
  email       text        not null  check ( email ~* '^.+@.+\..+$' ),
  pass        text        not null  check (length(pass) < 512),
  role        name        not null  check (length(role) < 512),
  challenge   varchar(12) not null,
  expires_at  timestamptz not null  default (now() + '1 day'::interval),
  primary key (email, challenge)
);

create or replace function
public.signup(email text, password text) returns void as $$
declare
  challenge_str text;
  notify_payload text;
  encrypted_password text;
begin
  if ((email is not null) and (password is not null)) then
    select array_to_string(array_agg(chr(65+round(random()*25)::integer)), '')
      into challenge_str from generate_series(1,12);
    insert into auth.signup (email, pass, role, challenge)
      values (email, password, 'worker', challenge_str);
    notify_payload = json_build_object('email', email, 'challenge', challenge_str);
    perform pg_notify('signups', notify_payload);
  end if;
end;
$$ security definer language plpgsql;

-- Ensure password is encrypted prior to being stored
create trigger encrypt_signup_pass
    before insert or update on auth.signup
    for each row
    execute procedure auth.encrypt_pass();


--------------------------------------------------------------------------------
-- USER VERIFY

-- A user is sent an email out-of-band. If they produce the correct challenge
-- token to the verify prodecdure, then their record is moved into the
-- auth.users table.
create or replace function
public.verify(email text, challenge text) returns void as $$
declare
  pending_signup record;
begin
  insert into auth.users (email, pass, role)
    (select s.email, s.pass, s.role from auth.signup s
      where s.email = email and s.challenge = challenge
  );
  delete from auth.signup
    where auth.signup.email = email and auth.signup.challenge = challenge;
end
$$ security definer language plpgsql;



--------------------------------------------------------------------------------
-- USER LOGIN

-- login should be on exposed schema (public). This procedure returns a JWT
-- after the user successfully authenticates using email + password. Subsequent
-- API requests use the returned JWT.
create or replace function
public.login(email text, pass text) returns auth.jwt_token as $$
declare
  _role name;
  result auth.jwt_token;
begin
  -- check email and password
  select auth.user_role(email, pass) into _role;
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
