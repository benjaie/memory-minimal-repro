# Multitenant SQL repro

Requires Node 24+, Yarn, and local PostgreSQL. Setup uses the local administrative
connection; the config connects over TCP as `constructive-minimal-graphql`.
Uses the published PostGraphile `snapshot-next` packages.
The existing `constructive-minimal` and `constructive-minimal-graphql` roles are
required. The former owns the database and fixture objects; the latter receives
explicit grants and is used for both schema introspection and GraphQL execution.

```sh
yarn install --immutable
./setup.sh             # Recreates constructive-minimal with just tenant_000
GRAPHILE_ENV=development yarn export
```

To measure memory before and after building the schema, then release PostGraphile
and the PostgreSQL service:

```sh
GRAPHILE_ENV=development node --expose-gc index.ts
```

Without `--expose-gc`, the script still runs and skips explicit garbage collection.
Memory usage is printed as before, after, and change in KiB or MiB.

For 150 unrelated tenants plus the exposed tenant, run `./setup.sh 150`.

- `schema.sql`: shared `bench_types`, granted `hidden`, and ungranted `private` schemas.
- `tenant.sql`: the original fixture plus utility and private-row functions, using
  a `SCHEMA` variable. Grants and RLS policies target `constructive-minimal-graphql`.
- `setup.sh`: recreates the database, loads shared SQL, then loops over tenants.
- `graphile.config.ts`: exposes `tenant_000`, prints introspection and registry
  counts, and exports executable code to `exported-schema.mjs`. Also works with
  `yarn start` to run PostGraphile.

To load an additional tenant directly:

```sh
psql -X -v ON_ERROR_STOP=1 -v SCHEMA=tenant_151 -d constructive-minimal -f tenant.sql
```

The SQL starts from `src/fixture/hidden.ts` and `src/fixture/tenant.ts` in the
original repro and adds the permission cases below. Each tenant is loaded in its own transaction. The `format(...) \gexec` in
`tenant.sql` substitutes the schema name inside `slow_identity`'s function body,
where psql does not expand variables directly. Loading rows requires a superuser
or BYPASSRLS role, as in the original fixture.

The config exports in `graphql-js` mode. Search for `makeRegistry` in the generated
module to inspect the runtime registry. Export bytes are file size, not retained
heap. The original HTTP routing and per-request identity settings are outside this SQL
reproduction. Tenant RLS still requires the `jwt.claims.tenant` and
`jwt.claims.user_id` settings to return seeded tenant rows.

Permission cases:

- `hidden.format_label(text)` is granted but its schema is not exposed. Each
  tenant's `utility_example(text)` calls it.
- `private` has no schema or table grants to the GraphQL role or PUBLIC.
  `private.unused_records` is unreferenced and should not enter the registry.
- Each tenant's `private_record()` is owned by `constructive-minimal`, uses
  `SECURITY DEFINER` with a fixed search path, and returns `private.private_records`.
  That row codec must be imported even though direct table access is denied.
  PUBLIC cannot execute the tenant functions; the GraphQL role is explicitly granted execution.

Verified through PostGraphile as `constructive-minimal-graphql`:

```graphql
{
  utilityExample(value: "hello")
  privateRecord { rowId label }
}
```

This returns `"Utility: hello"` and the seeded private record. Only `tenant_000`
is exposed; neither hidden utilities nor private tables have root query fields.
