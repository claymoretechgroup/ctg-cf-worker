# CTG CF Staging

A local staging environment for developing and testing **Cloudflare Workers** backed by **D1** (Cloudflare's SQLite database) and **R2** (object storage). It's the Cloudflare counterpart to `ctg-php-staging`: clone it into a project's `staging/` directory, run one command, and develop against a realistic Worker + database + object-store stack with seedable fixtures.

Unlike the PHP staging (which runs MariaDB in Docker), there's **no container to manage** — `wrangler dev` emulates D1 and R2 locally against the same `workerd` runtime Cloudflare runs in production.

---

## Prerequisites

- **Node.js** (18+)
- That's it — `wrangler` is pinned as a dev dependency and run via `npx`.

```bash
npm install
```

A Cloudflare account is only needed for the **Remote** targets (`deploy`, `db-create`, `r2-create`); local development needs nothing.

---

## Quick start

```bash
npm install            # install wrangler
make init              # seed the local D1 (guitars) + R2 (fixtures)
make dev               # start the Worker locally
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
│   make dev  ──►  wrangler dev (workerd)                  │
│                    │                                     │
│                    ├─ D1 binding  ("DB")    ──► local D1 │
│                    └─ R2 binding  ("BUCKET")──► local R2 │
│                                                          │
│        both persist under .wrangler/state (git-ignored)  │
│                                                          │
│   scenarios/*.d1.sql  ── make init / load-scenario  (D1) │
│   fixtures/r2/**      ── make init / r2-seed        (R2) │
└────────────────────────────────────────────────────────┘
```

- `src/index.js` — the Worker (here, a D1 + R2 smoke test).
- `wrangler.toml` — the `DB` (D1) and `BUCKET` (R2) bindings. `database_id` is a placeholder for local use; replace it for remote deploys.
- `scenarios/` — D1 seed/snapshot `.sql` files. `guitars.d1.sql` is the default fixture.
- `fixtures/r2/` — files seeded into the local R2 bucket; the object key is the path under `fixtures/r2/`.

> **Local store consistency:** `wrangler dev` and every local CLI command are pinned to the same `--persist-to .wrangler/state`. This is required for R2 — without a matching persist path, CLI-seeded objects aren't visible to the running Worker ([workers-sdk #13034](https://github.com/cloudflare/workers-sdk/issues/13034)). The Makefile handles this for you.

---

## Make targets

Run `make help` for the list. The verbs mirror `ctg-php-staging`:

| Target | What it does |
|---|---|
| `make dev` | Start the Worker locally with local D1 + R2 (foreground) |
| `make init` | Seed the local D1 (`SCENARIO=guitars`) and R2 (`fixtures/r2/`) |
| `make reset` | Wipe all local state and re-seed D1 + R2 |
| `make load-scenario NAME=x` | Load `scenarios/x.d1.sql` into the local D1 |
| `make dump NAME=x` | Export the local D1 to `scenarios/x.d1.sql` |
| `make query CMD="SELECT …"` | Run SQL against the local D1 (inspection) |
| `make r2-seed` | Seed the local R2 bucket from `fixtures/r2/` |
| `make db-create` | Create the remote D1 database (one-time) |
| `make r2-create` | Create the remote R2 bucket (one-time) |
| `make load-remote NAME=x` | Import `scenarios/x.d1.sql` into the **remote** D1 |
| `make dump-remote NAME=x` | Export the **remote** D1 to `scenarios/x.d1.sql` |
| `make deploy` | Deploy the Worker to Cloudflare |

---

## Seed data

### D1 scenarios

Scenarios are plain SQLite `.sql` files in `scenarios/`. Capture the current local state as a new scenario:

```bash
make query CMD="INSERT INTO guitars (make, model, color, year_purchased) VALUES ('PRS','Custom 24','Whale Blue',2025)"
make dump NAME=with-prs
```

Load it later (or in another clone) with `make load-scenario NAME=with-prs`.

`guitars.d1.sql` was ported from `ctg-php-staging/data/guitars.sql`; the MariaDB→SQLite transform notes live in that file's header.

### R2 fixtures

R2 has no single-file dump/load model — a "fixture set" is just a directory tree under `fixtures/r2/`. Each file becomes an object whose key is its path beneath `fixtures/r2/` (e.g. `fixtures/r2/specs/ibanez-grx20l.txt` → object `specs/ibanez-grx20l.txt`). Add files there and run `make r2-seed` (or `make reset` to rebuild both stores).

---

## Working with Cloudflare (remote)

Everything above runs **locally** and needs no account. The commands below talk to
your real Cloudflare account, so they require `wrangler login` (or a
`CLOUDFLARE_API_TOKEN` env var), a real `database_id` in `wrangler.toml`, and the
remote bucket to exist.

### One-time setup

```bash
make db-create          # wrangler d1 create ctg_cf_staging
# copy the returned database_id into wrangler.toml
make r2-create          # wrangler r2 bucket create ctg-cf-staging
```

### Deploy the Worker

```bash
make deploy             # wrangler deploy — uploads src/index.js + bindings
```

For separate prod/staging targets, add `[env.<name>]` blocks to `wrangler.toml`
and deploy a named environment with `wrangler deploy --env <name>`.

### Import / export a remote D1

D1 has no separate "import" command — you import by applying a `.sql` file:

```bash
make load-remote NAME=guitars
#  → wrangler d1 execute ctg_cf_staging --remote --file=scenarios/guitars.d1.sql

make dump-remote NAME=prod-snapshot
#  → wrangler d1 export ctg_cf_staging --remote --output=scenarios/prod-snapshot.d1.sql
```

Export flags worth knowing: `--no-data` (schema only), `--no-schema` (data only),
`--table=<name>` (one table). Raw `.sqlite3` binaries can't be imported — data must
come in as SQL.

### Remote R2 objects

```bash
wrangler r2 object put ctg-cf-staging/<key> --remote --file=<path>
wrangler r2 object get ctg-cf-staging/<key> --remote --file=<path>
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
