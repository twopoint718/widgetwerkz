-- Deploy widgetwerkz:api_schema to pg
-- requires: user_management

BEGIN;

create type public.color as enum ('Red', 'Green', 'Blue');

create table public.supplier (
  sid     int   primary key,
  sname   text  not null,
  status  int   not null,
  city    text  not null
);

create table public.part (
  pid     int       primary key,
  pname   text      not null,
  color   public.color not null,
  weight  real      not null,
  city    text      not null
);
alter table public.part enable row level security;

create table public.shipment (
  sid int   not null references public.supplier(sid),
  pid int   not null references public.part(pid),
  qty int   not null,
  primary key (sid, pid)
);

--------------------------------------------------------------------------------
-- USERS:
--   * web-anon - anonymous user before PostgREST has authenticated them. This
--       user has read-only access to all tables
--   * manager - has read/write access to all tables
--   * worker - has read/write to the London-based parts warehouse only.
--       Everything else is read-only.

-- web-anon
create role web_anon nologin;
grant web_anon to postgres;
grant usage on schema public to web_anon;
grant select on all tables in schema public to web_anon;

-- manager
create role manager nologin;
grant manager to postgres;
grant usage on schema public to manager;
grant all on all tables in schema public to manager;
grant usage, select on all sequences in schema public to manager;

-- worker
create role worker nologin;
grant worker to postgres;
grant usage on schema public to worker;
grant select on all tables in schema public to worker;
grant select on all sequences in schema public to worker;

-- allow 'all' access to public.part, but update/delete only when city = 'London'
create policy worker_london_parts_access on public.part
  for all to worker
  with check (city = 'London');

COMMIT;
