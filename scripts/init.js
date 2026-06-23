// Seed the local D1 + R2 for a first run.
//
//   node scripts/init.js            seed D1 (SCENARIO=guitars) then R2
//   node scripts/init.js --reset    wipe .wrangler/state first, then seed
//
// Override the D1 scenario with SCENARIO=<name> (scenarios/<name>.d1.sql).

import { rmSync } from "node:fs";
import { DB, LOCAL, STATE, wrangler } from "./lib.js";
import { r2Seed } from "./r2-seed.js";

const reset = process.argv.includes("--reset");
const scenario = process.env.SCENARIO || "guitars";

if (reset) {
  console.log(`reset: removing ${STATE}`);
  rmSync(STATE, { recursive: true, force: true });
}

wrangler(["d1", "execute", DB, ...LOCAL, `--file=scenarios/${scenario}.d1.sql`]);
r2Seed();
