-- Load with: psql -v SCHEMA=tenant_000 -d constructive-minimal -f tenant.sql
BEGIN;
SET LOCAL ROLE "constructive-minimal";

CREATE SCHEMA :"SCHEMA";
CREATE TYPE :"SCHEMA".task_state AS ENUM ('open', 'done');
CREATE DOMAIN :"SCHEMA".short_text AS text CHECK (length(VALUE) < 200);
CREATE TABLE :"SCHEMA".accounts (
  id integer PRIMARY KEY,
  owner_id integer NOT NULL,
  tenant_key text NOT NULL DEFAULT :'SCHEMA',
  name :"SCHEMA".short_text NOT NULL
);
CREATE TABLE :"SCHEMA".projects (
  id integer PRIMARY KEY,
  owner_id integer NOT NULL,
  tenant_key text NOT NULL DEFAULT :'SCHEMA',
  account_id integer NOT NULL REFERENCES :"SCHEMA".accounts,
  name text NOT NULL
);
CREATE TABLE :"SCHEMA".tasks (
  id integer PRIMARY KEY,
  owner_id integer NOT NULL,
  tenant_key text NOT NULL DEFAULT :'SCHEMA',
  project_id integer NOT NULL REFERENCES :"SCHEMA".projects,
  title text NOT NULL,
  state :"SCHEMA".task_state NOT NULL DEFAULT 'open',
  priority text NOT NULL REFERENCES bench_types.priority,
  score bench_types.score NOT NULL,
  score_window bench_types.score_range,
  labels text[] NOT NULL,
  scores bench_types.score[]
);
CREATE TABLE :"SCHEMA".notes (
  id integer PRIMARY KEY,
  owner_id integer NOT NULL,
  tenant_key text NOT NULL DEFAULT :'SCHEMA',
  task_id integer NOT NULL REFERENCES :"SCHEMA".tasks,
  body text NOT NULL
);
CREATE TABLE :"SCHEMA".tags (
  id integer PRIMARY KEY,
  owner_id integer NOT NULL,
  tenant_key text NOT NULL DEFAULT :'SCHEMA',
  name text NOT NULL
);
CREATE TABLE :"SCHEMA".task_tags (
  id integer PRIMARY KEY,
  owner_id integer NOT NULL,
  tenant_key text NOT NULL DEFAULT :'SCHEMA',
  task_id integer NOT NULL REFERENCES :"SCHEMA".tasks,
  tag_id integer NOT NULL REFERENCES :"SCHEMA".tags
);
CREATE TABLE :"SCHEMA".events (
  id integer PRIMARY KEY,
  owner_id integer NOT NULL,
  tenant_key text NOT NULL DEFAULT :'SCHEMA',
  task_id integer NOT NULL REFERENCES :"SCHEMA".tasks,
  kind text NOT NULL
);
CREATE TABLE :"SCHEMA".attachments (
  id integer PRIMARY KEY,
  owner_id integer NOT NULL,
  tenant_key text NOT NULL DEFAULT :'SCHEMA',
  task_id integer NOT NULL REFERENCES :"SCHEMA".tasks,
  filename text NOT NULL
);
CREATE TABLE :"SCHEMA".settings (
  id integer PRIMARY KEY,
  owner_id integer NOT NULL,
  tenant_key text NOT NULL DEFAULT :'SCHEMA',
  value jsonb NOT NULL
);
CREATE TABLE :"SCHEMA".inherited_records (
  PRIMARY KEY (id),
  label text NOT NULL
) INHERITS (bench_types.record_base);
CREATE INDEX ON :"SCHEMA".projects (account_id);
CREATE INDEX ON :"SCHEMA".tasks (project_id);
CREATE INDEX ON :"SCHEMA".notes (task_id);
CREATE INDEX ON :"SCHEMA".task_tags (task_id);
CREATE INDEX ON :"SCHEMA".task_tags (tag_id);
CREATE INDEX ON :"SCHEMA".events (task_id);
CREATE INDEX ON :"SCHEMA".attachments (task_id);
ALTER TABLE :"SCHEMA".inherited_records ALTER tenant_key SET DEFAULT :'SCHEMA';
CREATE FUNCTION :"SCHEMA".echo_score(value bench_types.score) RETURNS bench_types.score LANGUAGE sql IMMUTABLE AS 'SELECT value';
CREATE FUNCTION :"SCHEMA".echo_window(value bench_types.score_range) RETURNS bench_types.score_range LANGUAGE sql IMMUTABLE AS 'SELECT value';
CREATE FUNCTION :"SCHEMA".echo_mood(value bench_types.mood) RETURNS bench_types.mood LANGUAGE sql IMMUTABLE AS 'SELECT value';
CREATE FUNCTION :"SCHEMA".request_identity() RETURNS text LANGUAGE sql STABLE AS
  $$SELECT current_user || ':' || current_setting('jwt.claims.tenant', true) || ':' || current_setting('jwt.claims.user_id', true)$$;
SELECT format(
  'CREATE FUNCTION %I.slow_identity(seconds double precision) RETURNS text LANGUAGE plpgsql VOLATILE AS %L',
  :'SCHEMA',
  format('BEGIN PERFORM pg_sleep(LEAST(seconds, 2)); RETURN %I.request_identity(); END', :'SCHEMA')
) \gexec

CREATE FUNCTION :"SCHEMA".utility_example(value text) RETURNS text
  LANGUAGE sql IMMUTABLE
  AS $$SELECT hidden.format_label(value)$$;

CREATE FUNCTION :"SCHEMA".private_record() RETURNS private.private_records
  LANGUAGE sql STABLE SECURITY DEFINER
  SET search_path = pg_catalog
  AS $$SELECT id, label FROM private.private_records WHERE id = 1$$;

ALTER TABLE :"SCHEMA".accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE :"SCHEMA".accounts FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_owner ON :"SCHEMA".accounts TO "constructive-minimal-graphql" USING
  (tenant_key = current_setting('jwt.claims.tenant', true) AND owner_id::text = current_setting('jwt.claims.user_id', true));
ALTER TABLE :"SCHEMA".projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE :"SCHEMA".projects FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_owner ON :"SCHEMA".projects TO "constructive-minimal-graphql" USING
  (tenant_key = current_setting('jwt.claims.tenant', true) AND owner_id::text = current_setting('jwt.claims.user_id', true));
ALTER TABLE :"SCHEMA".tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE :"SCHEMA".tasks FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_owner ON :"SCHEMA".tasks TO "constructive-minimal-graphql" USING
  (tenant_key = current_setting('jwt.claims.tenant', true) AND owner_id::text = current_setting('jwt.claims.user_id', true));
ALTER TABLE :"SCHEMA".notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE :"SCHEMA".notes FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_owner ON :"SCHEMA".notes TO "constructive-minimal-graphql" USING
  (tenant_key = current_setting('jwt.claims.tenant', true) AND owner_id::text = current_setting('jwt.claims.user_id', true));
ALTER TABLE :"SCHEMA".tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE :"SCHEMA".tags FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_owner ON :"SCHEMA".tags TO "constructive-minimal-graphql" USING
  (tenant_key = current_setting('jwt.claims.tenant', true) AND owner_id::text = current_setting('jwt.claims.user_id', true));
ALTER TABLE :"SCHEMA".task_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE :"SCHEMA".task_tags FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_owner ON :"SCHEMA".task_tags TO "constructive-minimal-graphql" USING
  (tenant_key = current_setting('jwt.claims.tenant', true) AND owner_id::text = current_setting('jwt.claims.user_id', true));
ALTER TABLE :"SCHEMA".events ENABLE ROW LEVEL SECURITY;
ALTER TABLE :"SCHEMA".events FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_owner ON :"SCHEMA".events TO "constructive-minimal-graphql" USING
  (tenant_key = current_setting('jwt.claims.tenant', true) AND owner_id::text = current_setting('jwt.claims.user_id', true));
ALTER TABLE :"SCHEMA".attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE :"SCHEMA".attachments FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_owner ON :"SCHEMA".attachments TO "constructive-minimal-graphql" USING
  (tenant_key = current_setting('jwt.claims.tenant', true) AND owner_id::text = current_setting('jwt.claims.user_id', true));
ALTER TABLE :"SCHEMA".settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE :"SCHEMA".settings FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_owner ON :"SCHEMA".settings TO "constructive-minimal-graphql" USING
  (tenant_key = current_setting('jwt.claims.tenant', true) AND owner_id::text = current_setting('jwt.claims.user_id', true));
ALTER TABLE :"SCHEMA".inherited_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE :"SCHEMA".inherited_records FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_owner ON :"SCHEMA".inherited_records TO "constructive-minimal-graphql" USING
  (tenant_key = current_setting('jwt.claims.tenant', true) AND owner_id::text = current_setting('jwt.claims.user_id', true));

-- Seed as the administrative connection, bypassing forced RLS.
RESET ROLE;
INSERT INTO :"SCHEMA".accounts SELECT i,i,:'SCHEMA','Synthetic account '||i FROM generate_series(1,2) i;
INSERT INTO :"SCHEMA".projects SELECT i,i,:'SCHEMA',i,'Synthetic project '||i FROM generate_series(1,2) i;
INSERT INTO :"SCHEMA".tasks SELECT i,i,:'SCHEMA',i,'Synthetic task '||i,'open','normal',42,'[1,9)',ARRAY['synthetic','example'],ARRAY[1,2]::bench_types.score[] FROM generate_series(1,2) i;
INSERT INTO :"SCHEMA".notes SELECT i,i,:'SCHEMA',i,'Synthetic note '||i FROM generate_series(1,2) i;
INSERT INTO :"SCHEMA".tags SELECT i,i,:'SCHEMA','Synthetic tag '||i FROM generate_series(1,2) i;
INSERT INTO :"SCHEMA".task_tags SELECT i,i,:'SCHEMA',i,i FROM generate_series(1,2) i;
INSERT INTO :"SCHEMA".events SELECT i,i,:'SCHEMA',i,'created' FROM generate_series(1,2) i;
INSERT INTO :"SCHEMA".attachments SELECT i,i,:'SCHEMA',i,'example.txt' FROM generate_series(1,2) i;
INSERT INTO :"SCHEMA".settings SELECT i,i,:'SCHEMA','{"synthetic":true}'::jsonb FROM generate_series(1,2) i;
INSERT INTO :"SCHEMA".inherited_records SELECT i,i,:'SCHEMA','Inherited example '||i FROM generate_series(1,2) i;
SET LOCAL ROLE "constructive-minimal";
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA :"SCHEMA" FROM PUBLIC;
GRANT USAGE ON SCHEMA :"SCHEMA" TO "constructive-minimal-graphql";
GRANT SELECT ON ALL TABLES IN SCHEMA :"SCHEMA" TO "constructive-minimal-graphql";
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA :"SCHEMA" TO "constructive-minimal-graphql";

COMMIT;
