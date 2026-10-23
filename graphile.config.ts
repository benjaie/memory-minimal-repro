import { makePgService } from "postgraphile/adaptors/pg";
import { PostGraphileAmberPreset } from "postgraphile/presets/amber";
const preset: GraphileConfig.Preset = {
  extends: [PostGraphileAmberPreset],
  pgServices: [
    makePgService({
      connectionString: "postgres:///constructive-minimal",
    }),
  ],
};
export default preset;
