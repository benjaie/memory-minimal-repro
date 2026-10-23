import { postgraphile } from "postgraphile";
import preset, { release } from "./graphile.config.ts";

function formatMemory(bytes: number): string {
  const unit = Math.abs(bytes) >= 1024 * 1024 ? "MiB" : "KiB";
  const divisor = unit === "MiB" ? 1024 * 1024 : 1024;
  return `${(bytes / divisor).toFixed(2)} ${unit}`;
}

globalThis.gc?.();
const before = process.memoryUsage();

try {
  const pgl = postgraphile(preset);
  try {
    await pgl.getSchema();
    globalThis.gc?.();
    const after = process.memoryUsage();
    const rows = [
      ["Metric", "Before", "After", "Change"],
      ...(Object.keys(before) as (keyof typeof before)[]).map((key) => {
        const change = after[key] - before[key];
        return [
          key,
          formatMemory(before[key]),
          formatMemory(after[key]),
          `${change > 0 ? "+" : ""}${formatMemory(change)}`,
        ];
      }),
    ];
    const widths = rows[0].map((_, column) =>
      Math.max(...rows.map((row) => row[column].length)),
    );
    console.log(rows.map((row) =>
      row.map((value, column) => column === 0
        ? value.padEnd(widths[column])
        : value.padStart(widths[column]),
      ).join("  "),
    ).join("\n"));
  } finally {
    await pgl.release();
  }
} finally {
  await release();
}
