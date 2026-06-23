// One-shot project personalization. Run once, right after cloning this
// starter, then it removes itself:
//
//   npm run setup -- <project-name> [--strip-demo]
//
// What it does:
//   * renames the Worker / D1 / R2 identifiers from the starter's
//     "ctg-cf-worker" (D1: "ctg_cf_worker") to <project-name>;
//   * detaches the starter's git history (`rm -rf .git && git init`);
//   * with --strip-demo, removes the demo guitars Worker + seed data and
//     drops in a minimal Worker;
//   * deletes this script and its npm-script entry.
//
// Only git + npm are required — both are already needed for any wrangler
// project, so setup adds no new dependency.

import { readFileSync, writeFileSync, rmSync, unlinkSync, existsSync } from "node:fs";
import { spawnSync } from "node:child_process";

const TEMPLATE_HYPHEN = "ctg-cf-worker"; // package / Worker / R2 bucket name
const TEMPLATE_UNDER = "ctg_cf_worker"; // D1 database name (underscores)

const argv = process.argv.slice(2);
const stripDemo = argv.includes("--strip-demo");
const name = argv.find((a) => !a.startsWith("--"));

if (!name) {
  console.error("Usage: npm run setup -- <project-name> [--strip-demo]");
  process.exit(1);
}
if (!/^[a-z0-9][a-z0-9-]*$/.test(name)) {
  console.error(
    `Invalid project name "${name}": use lowercase letters, digits, and hyphens (must start with a letter or digit).`
  );
  process.exit(1);
}

const hyphen = name; // Worker / bucket / package name
const under = name.replace(/-/g, "_"); // D1 database name — no hyphens allowed

// --- rename identifiers --------------------------------------------------

// package.json: parse so we can also drop the setup script entry cleanly.
const pkg = JSON.parse(readFileSync("package.json", "utf8"));
pkg.name = hyphen;
pkg.description = `${hyphen} — a Cloudflare Worker (D1 + R2).`;
pkg.scripts["db-create"] = `wrangler d1 create ${under}`;
pkg.scripts["r2-create"] = `wrangler r2 bucket create ${hyphen}`;
delete pkg.scripts.setup;
writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
console.log("updated package.json");

// wrangler.jsonc + scripts/lib.js: plain token replacement (jsonc has comments,
// so don't parse it).
for (const file of ["wrangler.jsonc", "scripts/lib.js"]) {
  const out = readFileSync(file, "utf8")
    .split(TEMPLATE_UNDER)
    .join(under)
    .split(TEMPLATE_HYPHEN)
    .join(hyphen);
  writeFileSync(file, out);
  console.log(`updated ${file}`);
}

// --- optional: strip the demo --------------------------------------------

if (stripDemo) {
  rmSync("scenarios/guitars.d1.sql", { force: true });
  rmSync("fixtures/r2", { recursive: true, force: true });
  writeFileSync(
    "src/index.js",
    `export default {\n` +
      `  async fetch(request, env) {\n` +
      `    return new Response("Hello from ${hyphen}");\n` +
      `  },\n` +
      `};\n`
  );
  console.log("stripped demo (guitars scenario, R2 fixtures, smoke-test Worker)");
  console.log("note: add a scenarios/<name>.d1.sql and run `npm run load-scenario -- <name>` before `npm run init`");
}

// --- detach git history --------------------------------------------------

rmSync(".git", { recursive: true, force: true });
const init = spawnSync("git", ["init", "-q"], { stdio: "inherit" });
if (init.status === 0) console.log("re-initialized a fresh git repository");

// --- remove this script --------------------------------------------------

if (existsSync("scripts/setup.js")) unlinkSync("scripts/setup.js");

console.log(`\n${hyphen} is ready. Next:`);
console.log("  - set your git remote and identity");
console.log(stripDemo ? "  - add a D1 scenario, then `npm run init`" : "  - `npm run init && npm run dev`");
