// Shared config + wrangler runner for the project scripts.
//
// One place for the binding names and the local-state flags so every verb
// stays consistent. --local + a fixed --persist-to keeps `wrangler dev` and
// the CLI pointed at the SAME local store; R2 in particular needs this
// (workers-sdk #13034), or CLI-seeded objects aren't visible to the Worker.

import { spawnSync } from "node:child_process";

export const DB = "ctg_cf_worker"; // must match database_name in wrangler.jsonc
export const BUCKET = "ctg-cf-worker"; // must match bucket_name (R2: hyphens, no underscores)
export const STATE = ".wrangler/state"; // local binding data (D1/R2/...); shared by dev + CLI
export const LOCAL = ["--local", "--persist-to", STATE];

// Run a wrangler subcommand, inheriting stdio. Each element of `args` is a
// single argv token (no shell splitting), so values never get mangled.
export function wrangler(args) {
  const r = spawnSync("npx", ["wrangler", ...args], { stdio: "inherit" });
  if (r.error) {
    console.error(r.error.message);
    process.exit(1);
  }
  if (r.status !== 0) process.exit(r.status ?? 1);
}
