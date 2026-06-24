# CTG CF Worker

A clone-me starter for a **Cloudflare Worker** backed by **D1** (Cloudflare's SQLite database) and **R2** (object storage). Clone it as the root of a new Worker project and you get the bindings wired up, seedable D1 scenarios + R2 fixtures, and one-command npm verbs for the whole lifecycle — local development through deploy.

There's **no container or separate environment to stand up** — `wrangler` *is* the runtime: `wrangler dev` emulates D1 and R2 locally against the same `workerd` Cloudflare runs in production, and `wrangler deploy` ships the same Worker to your account.

---

## Why not just use `create-cloudflare`?

Cloudflare's official scaffolder (`npm create cloudflare`, aka C3) gets you a running
**Worker** — and if that's all you need, use it. What it does *not* give you is a
**staging environment for your data**: even C3's D1 template is just a binding plus maybe
a schema — no R2, no seed fixtures, no one-command seed/reset/snapshot, and none of the
`--persist-to` wiring that makes local R2 actually work.

This repo is the Worker **plus** that staging layer:

- **D1 + R2 both wired**, seeded by a single `npm run init` (`scenarios/*.d1.sql` +
  `fixtures/r2/**`);
- the ongoing **stage → reset → inspect** loop — `npm run reset`, `dump`, `query`;
- the [workers-sdk #13034](https://github.com/cloudflare/workers-sdk/issues/13034)
  `--persist-to` fix baked in, so CLI-seeded R2 is visible to the running Worker;
- a smoke test that proves the wiring, and recipes for extending it.

So: reach for `create-cloudflare` for a bare Worker; clone this when you want a Worker whose
**D1 + R2 are already staged and reseedable**. (This repo isn't built on C3 — bootstrap is a
plain `git clone` + `npm run setup`, git and npm only.)

---

## Prerequisites

- **Node.js** (18+).
- A **2022-or-newer 64-bit Linux or macOS** host. `wrangler`'s local mode runs on Cloudflare's `workerd` binary, which needs **glibc ≥ 2.32** on Linux (Ubuntu 22.04+, Debian 12+) — Node alone isn't sufficient. On an older host (e.g. Ubuntu 20.04 / glibc 2.31), run the commands inside a modern container, e.g. `node:22-bookworm`.
- `wrangler` itself is pinned as a dev dependency and run via `npx` — nothing to install globally.

```bash
npm install
```

A Cloudflare account is only needed for the **Remote** scripts (`deploy`, `db-create`, `r2-create`); local development needs nothing.

---

## Quick start

```bash
npm install            # install wrangler
npm run init           # seed the local D1 (guitars) + R2 (fixtures)
npm run dev            # start the Worker locally
```

Then open the Worker URL that `wrangler dev` prints. The smoke-test Worker queries both stores and returns JSON:

```json
{
  "ok": true,
  "d1": { "count": 9, "guitars": [ ... ] },
  "r2": { "count": 2, "keys": ["specs/fender-stratocaster.txt", "specs/ibanez-grx20l.txt"] }
}
```

If both come back green, your bindings and seed data are wired correctly.

---

## Start a new project

The Quick start above runs the demo as-is. To turn a clone into *your own* project,
run the one-shot setup — it renames the Worker / D1 / R2 identifiers, detaches this
starter's git history, and then deletes itself:

```bash
git clone git@github-ctg:claymoretechgroup/ctg-cf-worker.git my-app
cd my-app
npm install
npm run setup -- my-app          # rename everything to "my-app"
#   add --strip-demo for a bare Worker (no guitars scenario / R2 fixtures)
```

`<project-name>` must be lowercase letters, digits, and hyphens (a valid Worker
name); the D1 database gets the underscored form (`my_app`). Only **git and npm**
are used — both are already required for any wrangler project, so setup adds no
extra tooling. Afterward: `npm run init && npm run dev`.

---

## Architecture

```
┌────────────────────────────────────────────────────────┐
│                      Your machine                        │
│                                                          │
│   npm run dev  ──►  wrangler dev (workerd)               │
│                       │                                  │
│                       ├─ D1 binding ("DB")    ──► local D1│
│                       └─ R2 binding ("BUCKET")──► local R2│
│                                                          │
│        both persist under .wrangler/state (git-ignored)  │
│                                                          │
│   scenarios/*.d1.sql  ── npm run init / load-scenario (D1)│
│   fixtures/r2/**      ── npm run init / r2-seed       (R2)│
└────────────────────────────────────────────────────────┘
```

- `src/index.js` — the Worker (here, a D1 + R2 smoke test).
- `wrangler.jsonc` — the `DB` (D1) and `BUCKET` (R2) bindings. `database_id` is a placeholder for local use; replace it for remote deploys.
- `scenarios/` — D1 seed/snapshot `.sql` files. `guitars.d1.sql` is the default fixture.
- `fixtures/r2/` — files seeded into the local R2 bucket; the object key is the path under `fixtures/r2/`.
- `scripts/` — small Node helpers behind the npm scripts (`init`, `r2-seed`, the `d1` verbs). They centralize the binding names and the local-state flags.

> **Local store consistency:** `wrangler dev` and every local CLI command are pinned to the same `--persist-to .wrangler/state`. This is required for R2 — without a matching persist path, CLI-seeded objects aren't visible to the running Worker ([workers-sdk #13034](https://github.com/cloudflare/workers-sdk/issues/13034)). The npm scripts handle this for you.

---

## npm scripts

Run `npm run` to list them. Arguments are passed after `--`:

| Script | What it does |
|---|---|
| `npm run dev` | Start the Worker locally with local D1 + R2 (foreground) |
| `npm run init` | Seed the local D1 (`SCENARIO=guitars`) and R2 (`fixtures/r2/`) |
| `npm run reset` | Wipe all local state and re-seed D1 + R2 |
| `npm run load-scenario -- x` | Load `scenarios/x.d1.sql` into the local D1 |
| `npm run dump -- x` | Export the local D1 to `scenarios/x.d1.sql` |
| `npm run query -- "SELECT …"` | Run SQL against the local D1 (inspection) |
| `npm run r2-seed` | Seed the local R2 bucket from `fixtures/r2/` |
| `npm run db-create` | Create the remote D1 database (one-time) |
| `npm run r2-create` | Create the remote R2 bucket (one-time) |
| `npm run load-remote -- x` | Import `scenarios/x.d1.sql` into the **remote** D1 |
| `npm run dump-remote -- x` | Export the **remote** D1 to `scenarios/x.d1.sql` |
| `npm run deploy` | Deploy the Worker to Cloudflare (staging — **unminified**) |
| `npm run deploy-prod -- <flags>` | Deploy with **minification** on (production); append project flags after `--` |

Pick a different D1 scenario for `init`/`reset` with the `SCENARIO` env var, e.g. `SCENARIO=with-prs npm run init`.

---

## Seed data

### D1 scenarios

Scenarios are plain SQLite `.sql` files in `scenarios/`. Capture the current local state as a new scenario:

```bash
npm run query -- "INSERT INTO guitars (make, model, color, year_purchased) VALUES ('PRS','Custom 24','Whale Blue',2025)"
npm run dump -- with-prs
```

Load it later (or in another clone) with `npm run load-scenario -- with-prs`.

`guitars.d1.sql` was ported from `ctg-php-staging/data/guitars.sql`; the MariaDB→SQLite transform notes live in that file's header.

### R2 fixtures

R2 has no single-file dump/load model — a "fixture set" is just a directory tree under `fixtures/r2/`. Each file becomes an object whose key is its path beneath `fixtures/r2/` (e.g. `fixtures/r2/specs/ibanez-grx20l.txt` → object `specs/ibanez-grx20l.txt`). Add files there and run `npm run r2-seed` (or `npm run reset` to rebuild both stores).

---

## Working with Cloudflare (remote)

Everything above runs **locally** and needs no account. The commands below talk to
your real Cloudflare account, so they require `wrangler login` (or a
`CLOUDFLARE_API_TOKEN` env var), a real `database_id` in `wrangler.jsonc`, and the
remote bucket to exist.

> **R2 needs more than `wrangler login`.** `wrangler login` (OAuth) has **no R2
> scope** — it can't create buckets or read/write objects, and it can't deploy a
> Worker that has an R2 binding. Remote R2 requires a **`CLOUDFLARE_API_TOKEN`**
> (with *Workers R2 Storage → Edit*), **and** R2 must be enabled on the account —
> which currently needs **billing set up (a card on file), even on the free tier**.
> D1 and Workers, by contrast, work with `wrangler login` alone. (Verified
> 2026-06-23: the D1 remote path — `db-create` + `load-remote` — works on OAuth;
> R2 was blocked by both of the above.)

### One-time setup

```bash
npm run db-create       # wrangler d1 create ctg_cf_worker
# copy the returned database_id into wrangler.jsonc
npm run r2-create       # wrangler r2 bucket create ctg-cf-worker
```

### Deploy the Worker

```bash
npm run deploy          # wrangler deploy — uploads src/index.js + bindings
```

> **First deploy needs a `workers.dev` subdomain.** A brand-new account has none, so
> the first `deploy` can't publish a URL — it prints an onboarding link
> (`dash.cloudflare.com/<account>/workers/onboarding`). Register your `*.workers.dev`
> subdomain there once (account-level, you pick the name); after that, every deploy
> gets a URL. The upload and binding wiring still succeed before this step — it's
> purely the public route that's gated. (Verified 2026-06-23.)

### Deploy to a custom domain (production)

The `*.workers.dev` URL is fine for testing; for production you'll want a real
hostname (e.g. `api.example.com`). Cloudflare calls this a **Custom Domain** — it
binds the whole hostname to the Worker and **auto-creates the DNS record and TLS
cert**. (A *route* like `example.com/api/*` is the other option — a path on an
existing site, with a DNS record you manage yourself.)

**Prerequisite:** `example.com` must be an **active zone on the same Cloudflare
account** (its DNS managed by Cloudflare), and the target hostname must not already
have a conflicting CNAME.

Keep prod separate from local/dev with a **named environment**. Two gotchas: a named
env **does not inherit bindings**, so redeclare D1/R2 inside it; and it suffixes the
Worker name (`<name>-production`) unless you override `name`.

```jsonc
// wrangler.jsonc
{
  "name": "ctg-cf-worker",
  "main": "src/index.js",
  "compatibility_date": "2025-01-01",
  "d1_databases": [{ "binding": "DB", "database_name": "ctg_cf_worker", "database_id": "…" }],
  "r2_buckets":   [{ "binding": "BUCKET", "bucket_name": "ctg-cf-worker" }],

  "env": {
    "production": {
      "routes": [{ "pattern": "api.example.com", "custom_domain": true }],
      "workers_dev": false,
      "d1_databases": [{ "binding": "DB", "database_name": "ctg_cf_worker_prod", "database_id": "<REAL_PROD_ID>" }],
      "r2_buckets":   [{ "binding": "BUCKET", "bucket_name": "ctg-cf-worker-prod" }]
    }
  }
}
```

```bash
npx wrangler d1 create ctg_cf_worker_prod     # paste the id into env.production
npx wrangler r2 bucket create ctg-cf-worker-prod
npm run deploy-prod -- --env production       # minified; creates the custom domain (DNS + cert), goes live
npx wrangler secret put <NAME> --env production   # prod secrets
```

`workers_dev: false` makes the Worker reachable **only** on the custom domain.

> **Staging vs. production deploys.** `npm run deploy` ships the top-level config
> **unminified** — readable in `wrangler tail` for troubleshooting your staging
> Worker. `npm run deploy-prod` is identical but adds `--minify` (smaller bundle;
> source maps still uploaded). It bakes in **no** environment — pass anything
> project-specific (like the named env above) as flags **after `--`**:
> `npm run deploy-prod -- --env production`. The `--` is required; without it npm
> swallows the flags instead of forwarding them to `wrangler`.

### Import / export a remote D1

D1 has no separate "import" command — you import by applying a `.sql` file:

```bash
npm run load-remote -- guitars
#  → wrangler d1 execute ctg_cf_worker --remote --file=scenarios/guitars.d1.sql

npm run dump-remote -- prod-snapshot
#  → wrangler d1 export ctg_cf_worker --remote --output=scenarios/prod-snapshot.d1.sql
```

Export flags worth knowing: `--no-data` (schema only), `--no-schema` (data only),
`--table=<name>` (one table). Raw `.sqlite3` binaries can't be imported — data must
come in as SQL.

### Remote R2 objects

```bash
wrangler r2 object put ctg-cf-worker/<key> --remote --file=<path>
wrangler r2 object get ctg-cf-worker/<key> --remote --file=<path>
```

### Beyond this starter

A few wrangler commands you'll likely want but that aren't wrapped here:

- `wrangler d1 migrations create|apply <db> [--local|--remote]` — versioned schema
  changes; preferable to ad-hoc `execute` once the schema starts evolving.
- `wrangler secret put <NAME>` — store a secret for the deployed Worker.
- `wrangler tail` — live-stream logs from the deployed Worker.

---

## Adding a binding

> Written as a verbatim recipe so a person **or an AI agent** can add a binding by
> pattern-matching the existing D1/R2 wiring — every step names the exact file to
> edit and the existing block to mirror. Skip any step that doesn't apply.

Cloudflare exposes each resource to the Worker as a **binding** (`env.<NAME>`).
Wiring a new one is four steps:

1. **Declare it** in `wrangler.jsonc` — add the binding block beside `d1_databases`
   / `r2_buckets`. The `binding` value becomes the `env.<NAME>` key in `src/index.js`.
2. **Add a provision verb** to `package.json` scripts (mirror `db-create` /
   `r2-create`) *only if the resource is created server-side*. No-op for Durable
   Objects (code classes), Service bindings, and Workers AI.
3. **Seed it** for local dev *only if it holds data* — add the resource name as a
   constant in `scripts/lib.js`, then a fixture + seed step mirroring
   `scripts/init.js` (D1) or `scripts/r2-seed.js` (R2). Queues (you publish, not
   seed) and DOs (populated by Worker code) have no seed model.
4. **Extend the smoke test** in `src/index.js` — read the binding and add a field to
   the JSON response, mirroring the `d1` / `r2` blocks, so `npm run dev` proves it.

**Invariants — keep these or the binding breaks:**

- Every local CLI command and `wrangler dev` must share `--persist-to
  .wrangler/state` (the `LOCAL` array in `scripts/lib.js`), or seeded state isn't
  visible to the running Worker ([workers-sdk #13034](https://github.com/cloudflare/workers-sdk/issues/13034)).
- Match the `wrangler.jsonc` resource name **exactly** in `scripts/lib.js`. R2/KV
  names use hyphens; D1 uses underscores.
- Never build a wrangler command as a shell string — push argv tokens through the
  `wrangler([...])` helper in `scripts/lib.js` (this is what the dropped Makefile
  got wrong).

**Worked example — adding a KV namespace** (`CACHE`), which fits all four steps:

```jsonc
// 1. wrangler.jsonc — declare
"kv_namespaces": [
  { "binding": "CACHE", "id": "local-placeholder-replace-for-remote" }
]
```

```json
// 2. package.json — provision verb (returns an id to paste into wrangler.jsonc)
"kv-create": "wrangler kv namespace create ctg_cf_worker_cache"
```

```js
// 3. scripts/lib.js — name constant; then mirror scripts/r2-seed.js to loop a
//    fixtures/kv/*.json of { key: value } via:
//      wrangler(["kv", "key", "put", key, value, "--binding", KV, ...LOCAL])
export const KV = "CACHE";
```

```js
// 4. src/index.js — smoke check
const cached = await env.CACHE.list();
// add to the JSON: kv: { count: cached.keys.length }
```

---

## Porting a MariaDB schema to D1

> Same idea as *Adding a binding* — a recipe an AI agent can follow to turn a
> MariaDB schema/dump into a D1 scenario file rather than guess at SQLite's
> differences. `scenarios/guitars.d1.sql` is the worked example; its header lists
> the transforms that particular dataset used.

D1 *is* SQLite, so porting is mostly a mechanical type/DDL rewrite into a
`scenarios/<name>.d1.sql`:

| MariaDB | D1 / SQLite |
|---|---|
| `INT AUTO_INCREMENT PRIMARY KEY` | `INTEGER PRIMARY KEY AUTOINCREMENT` |
| `TINYINT`/`SMALLINT`/`BIGINT`/`INT` (± `UNSIGNED`) | `INTEGER` (no unsigned — drop it) |
| `TINYINT(1)` / `BOOLEAN` | `INTEGER` (0/1) |
| `DECIMAL(p,s)` / `FLOAT` / `DOUBLE` | `REAL` (or `TEXT` if you need exact precision) |
| `VARCHAR(n)` / `CHAR(n)` / `*TEXT` | `TEXT` (length not enforced) |
| `ENUM('a','b')` | `TEXT CHECK (col IN ('a','b'))` |
| `SET(...)` | `TEXT` (no equivalent — delimit, or normalize to a join table) |
| `DATE` / `DATETIME` / `TIMESTAMP` | `TEXT` (ISO-8601) or `INTEGER` (unix epoch) — pick one |
| `YEAR` | `INTEGER` |
| `JSON` | `TEXT` (query with SQLite's `json_*()` functions) |
| `BLOB` / `BINARY` / `VARBINARY` | `BLOB` |

**Strip these — SQLite rejects them:** table options (`ENGINE=…`, `DEFAULT
CHARSET=…`, `COLLATE=…`, `AUTO_INCREMENT=<n>`, `ROW_FORMAT=…`), column `COMMENT
'…'`, `UNSIGNED`/`ZEROFILL`, and mysqldump noise (`LOCK TABLES`, `/*!40101 … */`
conditional comments).

**Gotchas that silently break the load:**

- **Inline indexes aren't allowed.** MariaDB's `KEY idx (col)` / `UNIQUE KEY name
  (col)` *inside* `CREATE TABLE` must become separate statements after it:
  `CREATE INDEX idx ON tbl(col);` / `CREATE UNIQUE INDEX …`. (A plain `UNIQUE
  (col)` column constraint is fine inline.)
- **`ON UPDATE CURRENT_TIMESTAMP` is unsupported** — use an `AFTER UPDATE` trigger
  or set the value in app code. (`DEFAULT CURRENT_TIMESTAMP` *is* fine.)
- **String escaping:** convert MySQL's `\'` to SQLite's `''`.
- `FOREIGN KEY` carries over as-is — **D1 enforces foreign keys by default** (no
  `PRAGMA foreign_keys` needed).

**Verify the port by loading it** — D1 enforces `CHECK` and `FOREIGN KEY`
constraints, so a bad conversion fails loudly rather than silently:

```bash
npm run load-scenario -- <name>          # applies scenarios/<name>.d1.sql locally
npm run query -- "SELECT count(*) FROM <table>"
```

---

## Scope

This starter ships with a **Worker + D1 + R2** wired end-to-end. The remaining
Cloudflare bindings (KV, Durable Objects, Queues, Service bindings, Workers AI, …)
are intentionally **not** pre-built — they're added per the recipe above when a
consuming project actually needs them, so each binding's seed/snapshot tooling is
designed against a real use case rather than guessed at.
