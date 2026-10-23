#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"

# Argument: number of unrelated tenants (default 150), plus tenant_000.
dropdb --if-exists constructive-minimal
createdb constructive-minimal
psql -X -v ON_ERROR_STOP=1 -d constructive-minimal -f schema.sql
for i in $(seq 0 "${1:-150}"); do
  printf -v schema 'tenant_%03d' "$i"
  psql -X -v ON_ERROR_STOP=1 -v SCHEMA="$schema" -d constructive-minimal -f tenant.sql
done
