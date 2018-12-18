-- Deploy widgetwerkz:seed_db to pg
-- requires: api_schema

BEGIN;

insert into public.supplier (sid, sname, status, city) values
  (1, 'Smith', 20, 'London'),
  (2, 'Jones', 30, 'Paris'),
  (3, 'Blake', 30, 'Paris'),
  (4, 'Clark', 20, 'London'),
  (5, 'Adams', 30, 'Athens');

insert into public.part (pid, pname, color, weight, city) values
  (1, 'Nut', 'Red', 12.0, 'London'),
  (2, 'Bolt', 'Green', 17.0, 'Paris'),
  (3, 'Screw', 'Blue', 17.0, 'Paris'),
  (4, 'Screw', 'Red', 14.0, 'London'),
  (5, 'Cam', 'Blue', 12.0, 'Paris'),
  (6, 'Cog', 'Red', 19.0, 'London');

insert into public.shipment (sid, pid, qty) values
  (1, 1, 300),
  (1, 2, 200),
  (1, 3, 400),
  (1, 4, 200),
  (1, 5, 100),
  (1, 6, 100),
  (2, 1, 300),
  (2, 2, 400),
  (3, 2, 200),
  (4, 2, 200),
  (4, 4, 300),
  (4, 5, 400);

COMMIT;
