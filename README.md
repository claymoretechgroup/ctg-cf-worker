# CTG CF Template

A clone-me starter for a **Cloudflare Worker** backed by **D1** (Cloudflare's SQLite database) and **R2** (object storage). Clone it as the root of a new Worker project and you get the bindings wired up, seedable D1 scenarios + R2 fixtures, and one-command npm verbs for the whole lifecycle — local development through deploy.

There's **no container or separate environment to stand up** — `wrangler` *is* the runtime: `wrangler dev` emulates D1 and R2 locally against the same `workerd` Cloudflare runs in production, and `wrangler deploy` ships the same Worker to your account.

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
| `npm run deploy` | Deploy the Worker to Cloudflare |

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

### One-time setup

```bash
npm run db-create       # wrangler d1 create ctg_cf_template
# copy the returned database_id into wrangler.jsonc
npm run r2-create       # wrangler r2 bucket create ctg-cf-template
```

### Deploy the Worker

```bash
npm run deploy          # wrangler deploy — uploads src/index.js + bindings
```

For separate prod/staging targets, add `[env.<name>]` blocks to `wrangler.jsonc`
and deploy a named environment with `wrangler deploy --env <name>`.

### Import / export a remote D1

D1 has no separate "import" command — you import by applying a `.sql` file:

```bash
npm run load-remote -- guitars
#  → wrangler d1 execute ctg_cf_template --remote --file=scenarios/guitars.d1.sql

npm run dump-remote -- prod-snapshot
#  → wrangler d1 export ctg_cf_template --remote --output=scenarios/prod-snapshot.d1.sql
```

Export flags worth knowing: `--no-data` (schema only), `--no-schema` (data only),
`--table=<name>` (one table). Raw `.sqlite3` binaries can't be imported — data must
come in as SQL.

### Remote R2 objects

```bash
wrangler r2 object put ctg-cf-template/<key> --remote --file=<path>
wrangler r2 object get ctg-cf-template/<key> --remote --file=<path>
```

### Beyond this template

A few wrangler commands you'll likely want but that aren't wrapped here:

- `wrangler d1 migrations create|apply <db> [--local|--remote]` — versioned schema
  changes; preferable to ad-hoc `execute` once the schema starts evolving.
- `wrangler secret put <NAME>` — store a secret for the deployed Worker.
- `wrangler tail` — live-stream logs from the deployed Worker.

---

## Scope

This template covers a **Worker + D1 + R2**. The remaining Cloudflare bindings
(KV, Durable Objects, Queues) are intentionally **not** included — they'll be added
when a consuming project actually needs them, so their seed/snapshot tooling is
designed against a real use case rather than guessed at.
