# Multitenant SQL repro

Requires Node 24+, Yarn, and local PostgreSQL with peer authentication through
`/var/run/postgresql`. Uses the published PostGraphile `snapshot-next` packages.

```sh
yarn install --immutable
./setup.sh             # Recreates constructive-minimal; tenant_000 through tenant_150
GRAPHILE_ENV=development yarn export
```

To measure memory before and after building the schema, then release PostGraphile
and the PostgreSQL service:

```sh
GRAPHILE_ENV=development node --expose-gc index.ts
```

Without `--expose-gc`, the script still runs and skips explicit garbage collection.
Memory usage is printed as before, after, and change in KiB or MiB.

For just the exposed tenant, run `./setup.sh 0` instead.

- `schema.sql`: shared `bench_types` schema and `bench_reader` role.
- `tenant.sql`: the original fixture's ten tables, types, indexes, five functions,
  inheritance, RLS policies, grants, and two rows per table, using a `SCHEMA` variable.
- `setup.sh`: recreates the database, loads shared SQL, then loops over tenants.
- `graphile.config.ts`: exposes `tenant_000`, prints introspection and registry
  counts, and exports executable code to `exported-schema.mjs`. Also works with
  `yarn start` to run PostGraphile.

To load an additional tenant directly:

```sh
psql -X -v ON_ERROR_STOP=1 -v SCHEMA=tenant_151 -d constructive-minimal -f tenant.sql
```

The SQL mirrors `src/fixture/hidden.ts` and `src/fixture/tenant.ts` in the original
repro. Each tenant is loaded in its own transaction. The `format(...) \gexec` in
`tenant.sql` substitutes the schema name inside `slow_identity`'s function body,
where psql does not expand variables directly. Loading rows requires a superuser
or BYPASSRLS role, as in the original fixture.

The config exports in `graphql-js` mode. Search for `makeRegistry` in the generated
module to inspect the runtime registry. Export bytes are file size, not retained
heap. The config connects as the local database user; the original HTTP routing
and per-request role/identity settings are outside this SQL reproduction.
