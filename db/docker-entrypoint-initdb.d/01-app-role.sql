-- The application connects as a role that is NOT a superuser, and that is the
-- whole point of this file.
--
-- POSTGRES_USER in the postgres image is created as a superuser, and
-- superusers bypass row-level security unconditionally — FORCE ROW LEVEL
-- SECURITY does not apply to them. Connecting as one makes every tenant
-- isolation policy in this schema decoration: the tests pass because of the
-- application default scope alone, and the backstop that is supposed to catch
-- a forgotten scope silently is not there.
--
-- CREATEDB is granted so the role can still own the databases it creates,
-- which is what makes it the table owner and therefore subject to FORCE.

CREATE ROLE things WITH LOGIN PASSWORD 'things' CREATEDB;
