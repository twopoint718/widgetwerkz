-- Deploy widgetwerkz:user_management to pg

BEGIN;

--------------------------------------------------------------------------------
-- SCHEMA/EXTENSIONS

create schema if not exists auth;
create extension if not exists pgcrypto schema auth; -- password hashing
create extension if not exists pgjwt schema auth;    -- generate JWT tokens


--------------------------------------------------------------------------------
-- CONFIG

create table auth.settings (
  key text primary key,
  value text not null
);

create or replace function auth.get(text) returns text as $$
  select value from auth.settings where key = $1
$$ security definer stable language sql;

create or replace function auth.set(text, text) returns void as $$
  insert into auth.settings (key, value)
  values ($1, $2) on conflict (key) do update
  set value = $2;
$$ security definer language sql;

-- read JWT secret from config file and store it in the settings table
\set tmp_secret `cat ./secret.txt`
\set jwt_secret '\'' :tmp_secret '\''
select auth.set('jwt_secret', :jwt_secret);


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
    password text not null check (length(password) < 512),
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
auth.encrypt_password() returns trigger as $$
begin
    if tg_op = 'INSERT' or new._password <> old._password then
        new._password = auth.crypt(new._password, auth.gen_salt('bf'));
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
    and users.password = auth.crypt(user_role.pass, users.password)
  );
end;
$$;


--------------------------------------------------------------------------------
-- USER SIGNUP

-- Users can sign themselves up via the signup procedure. They set their email
-- and password and then they get a challenge token to verify their email. If
-- they call the verify procedure with a matching challenge token then they're
-- added to the users table
create table auth.signups (
  _email     text        primary key check ( _email ~* '^.+@.+\..+$' ),
  _password  text        not null    check (length(_password) < 512),
  role       name        not null    check (length(role) < 512),
  challenge  varchar(12) not null,
  expires_at timestamptz not null    default (now() + '1 day'::interval)
);

create or replace function
public.signup(email text, password text) returns json as $$
declare
  challenge_str text;
  notify_payload text;
  encrypted_password text;
begin
  if ((email is not null) and (password is not null)) then
    select array_to_string(array_agg(chr(65+round(random()*25)::integer)), '')
      into challenge_str from generate_series(1,12);
    insert into auth.signups (_email, _password, role, challenge)
      values (email, password, 'worker', challenge_str)
      on conflict (_email) do update
      set (challenge, expires_at) = (challenge_str, now() + '1 day'::interval);
    notify_payload = json_build_object('email', email, 'challenge', challenge_str);
    perform pg_notify('signups', notify_payload);
  end if;
  return (select json_build_object('msg', 'ok'));
end;
$$ security definer language plpgsql;

-- Ensure password is encrypted prior to being stored
create trigger encrypt_signup_pass
    before insert or update on auth.signups
    for each row
    execute procedure auth.encrypt_password();


--------------------------------------------------------------------------------
-- USER VERIFY

-- A user is sent an email out-of-band. If they produce the correct challenge
-- token to the verify prodecdure, then their record is moved into the
-- auth.users table.
create or replace function
public.verify(input_challenge text) returns json as $$
begin
  delete from auth.signups where auth.signups.expires_at < now();
  insert into auth.users (email, password, role)
    (select s._email, s._password, s.role from auth.signups s
      where s.challenge = input_challenge);
  delete from auth.signups where auth.signups.challenge = input_challenge;
  return (select json_build_object('msg', 'ok'));
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

  select auth.sign(row_to_json(r), auth.get('jwt_secret')) as token
  from (
    select
      _role as role,
      login.email as email,
      extract(epoch from now() + '4 hours'::interval)::integer as exp
  ) r
  into result;
  return result;
end;
$$ security definer language plpgsql;

COMMIT;
