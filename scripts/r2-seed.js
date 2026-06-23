// Seed the local R2 bucket from fixtures/r2/.
//
// Each file becomes an object whose key is its path beneath fixtures/r2/
// (e.g. fixtures/r2/specs/foo.txt -> object "specs/foo.txt").

import { readdirSync, statSync } from "node:fs";
import { join, relative, sep } from "node:path";
import { pathToFileURL } from "node:url";
import { BUCKET, LOCAL, wrangler } from "./lib.js";

const ROOT = "fixtures/r2";

export function r2Seed() {
  let stat;
  try {
    stat = statSync(ROOT);
  } catch {
    console.log("r2-seed: no fixtures/r2/ directory — skipping");
    return;
  }
  if (!stat.isDirectory()) {
    console.log("r2-seed: no fixtures/r2/ directory — skipping");
    return;
  }

  for (const file of walk(ROOT)) {
    const key = relative(ROOT, file).split(sep).join("/"); // POSIX-style object key
    console.log(`r2 put ${key}`);
    wrangler(["r2", "object", "put", `${BUCKET}/${key}`, ...LOCAL, `--file=${file}`]);
  }
}

function* walk(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, entry.name);
    if (entry.isDirectory()) yield* walk(p);
    else yield p;
  }
}

// Allow `node scripts/r2-seed.js` to run it directly.
if (import.meta.url === pathToFileURL(process.argv[1]).href) r2Seed();
