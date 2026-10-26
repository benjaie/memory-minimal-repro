#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"

# Argument: number of unrelated tenants (default 0), plus tenant_000.
psql -X -v ON_ERROR_STOP=1 -d postgres -c 'create role "constructive-minimal";' || true
psql -X -v ON_ERROR_STOP=1 -d postgres -c 'create role "constructive-minimal-graphql";' || true
psql -X -v ON_ERROR_STOP=1 -d postgres <<'HERE'
grant "constructive-minimal-graphql" to "constructive-minimal";
alter role "constructive-minimal" with login password 'password';
alter role "constructive-minimal-graphql" with login password 'password';
HERE
dropdb --if-exists constructive-minimal
createdb --owner=constructive-minimal constructive-minimal
psql -X -v ON_ERROR_STOP=1 -d constructive-minimal -f schema.sql
for i in $(seq 0 "${1:-150}"); do
  printf -v schema 'tenant_%03d' "$i"
  psql -X -v ON_ERROR_STOP=1 -v SCHEMA="$schema" -d constructive-minimal -f tenant.sql
done
