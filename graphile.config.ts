import { stat } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { exportSchema } from "graphile-export";
import { postgraphile } from "postgraphile";
import { makePgService } from "postgraphile/adaptors/pg";
import { PostGraphileAmberPreset } from "postgraphile/presets/amber";

const preset: GraphileConfig.Preset = {
  extends: [PostGraphileAmberPreset],
  plugins: [
    {
      name: "RegistrySizePlugin",
      version: "0.0.0",
      gather: {
        namespace: "registrySize",
        hooks: {
          pgIntrospection_introspection(_info, { introspection }) {
            console.log("Introspection entries:", {
              namespaces: introspection.namespaces.length,
              classes: introspection.classes.length,
              attributes: introspection.attributes.length,
              types: introspection.types.length,
            });
          },
          pgRegistry_PgRegistry(_info, { registry }) {
            console.log("Registry entries:", {
              codecs: Object.keys(registry.pgCodecs).length,
              resources: Object.keys(registry.pgResources).length,
              relations: Object.values(registry.pgRelations).reduce(
                (total, relations) => total + Object.keys(relations).length,
                0,
              ),
            });
          },
        },
      },
    },
  ],
  pgServices: [
    makePgService({
      connectionString: "postgres:///constructive-minimal?host=/var/run/postgresql",
      schemas: ["tenant_000"],
    }),
  ],
};
export default preset;

// Also acts as a standalone exporter: node graphile.config.ts
if (import.meta.main) {
  const pgl = postgraphile(preset);
  try {
    const schema = await pgl.getSchema();
    const path = fileURLToPath(new URL("./exported-schema.mjs", import.meta.url));
    await exportSchema(schema, path, { mode: "graphql-js" });
    console.log(`Executable schema: ${path} (${(await stat(path)).size} bytes)`);
  } finally {
    await pgl.release();
  }
}
