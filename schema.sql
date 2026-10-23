-- Shared dependencies; load once before tenant.sql.
BEGIN;
SET LOCAL ROLE "constructive-minimal";
CREATE SCHEMA bench_types;
CREATE DOMAIN bench_types.score AS integer CHECK (VALUE >= 0 AND VALUE <= 100);
CREATE TYPE bench_types.score_range AS RANGE (subtype = float8);
CREATE TYPE bench_types.mood AS ENUM ('calm', 'busy');
CREATE TABLE bench_types.priority (value text PRIMARY KEY, description text);
COMMENT ON TABLE bench_types.priority IS E'@enum\nSynthetic task priority';
INSERT INTO bench_types.priority VALUES ('normal','Normal priority'),('urgent','Urgent priority');
CREATE TABLE bench_types.record_base (id integer NOT NULL, owner_id integer NOT NULL, tenant_key text NOT NULL);
ALTER TABLE bench_types.record_base ENABLE ROW LEVEL SECURITY;
ALTER TABLE bench_types.record_base FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_owner ON bench_types.record_base TO "constructive-minimal-graphql" USING
  (tenant_key = current_setting('jwt.claims.tenant', true) AND owner_id::text = current_setting('jwt.claims.user_id', true));
GRANT USAGE ON SCHEMA bench_types TO "constructive-minimal-graphql";
GRANT SELECT ON ALL TABLES IN SCHEMA bench_types TO "constructive-minimal-graphql";

CREATE SCHEMA hidden;
REVOKE ALL ON SCHEMA hidden FROM PUBLIC;
GRANT USAGE ON SCHEMA hidden TO "constructive-minimal-graphql";
CREATE FUNCTION hidden.format_label(value text) RETURNS text
  LANGUAGE sql IMMUTABLE
  AS $$SELECT 'Utility: ' || value$$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA hidden FROM PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA hidden TO "constructive-minimal-graphql";

CREATE SCHEMA private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, "constructive-minimal-graphql";
CREATE TABLE private.private_records (id integer PRIMARY KEY, label text NOT NULL);
INSERT INTO private.private_records VALUES (1, 'Returned through a security definer');
-- Unreferenced private metadata should not be needed by the runtime registry.
CREATE TABLE private.unused_records (id integer PRIMARY KEY, secret text NOT NULL);
REVOKE ALL ON ALL TABLES IN SCHEMA private FROM PUBLIC, "constructive-minimal-graphql";
COMMIT;
