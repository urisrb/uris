-- Not a superuser: superusers bypass row-level security unconditionally, and
-- POSTGRES_USER is created as one.
CREATE ROLE things WITH LOGIN PASSWORD 'things' CREATEDB;
