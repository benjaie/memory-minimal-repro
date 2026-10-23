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

-- Catalogue bulk, deliberately unrelated to the exposed tenant's types.
-- Each schema gets 50 groups of tables, views, functions, and custom types.
DO $bulk$
DECLARE
  schema_name text;
  i integer;
BEGIN
  FOREACH schema_name IN ARRAY ARRAY['hidden', 'private'] LOOP
    FOR i IN 1..50 LOOP
      EXECUTE format($ddl$
        CREATE TYPE %1$I.state_%2$s AS ENUM ('draft', 'active', 'archived');
        CREATE DOMAIN %1$I.label_%2$s AS text CHECK (length(VALUE) <= 200);
        CREATE TYPE %1$I.summary_%2$s AS (item_count bigint, total numeric);

        CREATE TABLE %1$I.category_%2$s (
          value text PRIMARY KEY,
          description text NOT NULL
        );
        COMMENT ON TABLE %1$I.category_%2$s IS E'@enum\nSynthetic category';
        INSERT INTO %1$I.category_%2$s VALUES
          ('standard', 'Standard category'), ('special', 'Special category');

        CREATE TABLE %1$I.project_%2$s (
          id integer PRIMARY KEY,
          label %1$I.label_%2$s NOT NULL,
          state %1$I.state_%2$s NOT NULL DEFAULT 'draft',
          category text NOT NULL REFERENCES %1$I.category_%2$s,
          metadata jsonb NOT NULL DEFAULT '{}'
        );
        CREATE TABLE %1$I.item_%2$s (
          id integer PRIMARY KEY,
          project_id integer NOT NULL REFERENCES %1$I.project_%2$s,
          label %1$I.label_%2$s NOT NULL,
          amount numeric NOT NULL CHECK (amount >= 0),
          tags text[] NOT NULL DEFAULT '{}',
          created_at timestamptz NOT NULL DEFAULT now()
        );
        CREATE INDEX ON %1$I.item_%2$s (project_id);
        CREATE INDEX ON %1$I.item_%2$s USING gin (tags);
        INSERT INTO %1$I.project_%2$s VALUES
          (1, 'Example project', 'active', 'standard', '{}');
        INSERT INTO %1$I.item_%2$s (id, project_id, label, amount) VALUES
          (1, 1, 'First item', 10), (2, 1, 'Second item', 20);

        CREATE VIEW %1$I.active_projects_%2$s AS
          SELECT * FROM %1$I.project_%2$s WHERE state = 'active';
        CREATE VIEW %1$I.project_totals_%2$s AS
          SELECT p.id, p.label, count(i.id) AS item_count, sum(i.amount) AS total
          FROM %1$I.project_%2$s p
          LEFT JOIN %1$I.item_%2$s i ON i.project_id = p.id
          GROUP BY p.id;

        CREATE FUNCTION %1$I.find_project_%2$s(project_id integer)
          RETURNS %1$I.project_%2$s LANGUAGE sql STABLE
          AS $fn$SELECT * FROM %1$I.project_%2$s WHERE id = project_id$fn$;
        CREATE FUNCTION %1$I.project_summary_%2$s(project_id integer)
          RETURNS %1$I.summary_%2$s LANGUAGE sql STABLE
          AS $fn$SELECT count(*), coalesce(sum(amount), 0)
            FROM %1$I.item_%2$s WHERE item_%2$s.project_id = $1$fn$;
        CREATE FUNCTION %1$I.normalize_label_%2$s(value text)
          RETURNS %1$I.label_%2$s LANGUAGE sql IMMUTABLE
          AS $fn$SELECT trim(value)::%1$I.label_%2$s$fn$;
      $ddl$, schema_name, i);
    END LOOP;
  END LOOP;
END;
$bulk$;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA hidden, private FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA hidden TO "constructive-minimal-graphql";
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA hidden TO "constructive-minimal-graphql";
REVOKE ALL ON ALL TABLES IN SCHEMA private FROM PUBLIC, "constructive-minimal-graphql";
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA private FROM "constructive-minimal-graphql";
COMMIT;
