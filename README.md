# CTG CF Staging

A local staging environment for developing and testing **Cloudflare Workers** backed by **D1** (Cloudflare's SQLite database). It's the Cloudflare counterpart to `ctg-php-staging`: clone it into a project's `staging/` directory, run one command, and develop against a realistic Worker + database stack with seedable scenarios.

Unlike the PHP staging (which runs MariaDB in Docker), there's **no container to manage** — `wrangler dev` emulates D1 locally against a SQLite file, using the same `workerd` runtime Cloudflare runs in production.

---

## Prerequisites

- **Node.js** (18+)
- That's it — `wrangler` is pinned as a dev dependency and run via `npx`.

```bash
npm install
```

A Cloudflare account is only needed for the **Remote** targets (`deploy`, `db-create`); local development needs nothing.

---

## Quick start

```bash
npm install            # install wrangler
make init              # create + seed the local D1 with the guitars scenario
make dev               # start the Worker locally
```

Then open the Worker URL that `wrangler dev` prints. The smoke-test Worker queries D1 and returns the seeded guitars as JSON:

```json
{ "ok": true, "datastore": "d1", "count": 9, "guitars": [ ... ] }
```

If that comes back green, your D1 binding and seed are wired correctly.

---

## Architecture

```
┌──────────────────────────────────────────────────┐
│                  Your machine                      │
│                                                    │
│   make dev  ──►  wrangler dev (workerd)            │
│                    │                               │
│                    │  D1 binding ("DB")            │
│                    ▼                               │
│              local D1 (SQLite file under           │
│              .wrangler/state, git-ignored)         │
│                    ▲                               │
│   scenarios/*.d1.sql  ── make init / load-scenario │
└────────────────────────────────────────────────────┘
```

- `src/index.js` — the Worker (here, a D1 smoke test).
- `wrangler.toml` — the D1 binding. `database_id` is a placeholder for local use; replace it for remote deploys.
- `scenarios/` — seed/snapshot `.sql` files. `guitars.d1.sql` is the default fixture, ported from `ctg-php-staging/data/guitars.sql`.

---

## Make targets

Run `make help` for the list. The verbs mirror `ctg-php-staging`:

| Target | What it does |
|---|---|
| `make dev` | Start the Worker locally with a local D1 (foreground) |
| `make init` | Seed the local D1 with the default scenario (`SCENARIO=guitars`) |
| `make reset` | Wipe local D1 state and re-seed |
| `make load-scenario NAME=x` | Load `scenarios/x.d1.sql` into the local D1 |
| `make dump NAME=x` | Export the local D1 to `scenarios/x.d1.sql` |
| `make query CMD="SELECT …"` | Run SQL against the local D1 (inspection) |
| `make db-create` | Create the remote D1 database (one-time) |
| `make load-remote NAME=x` | Apply a scenario to the **remote** D1 |
| `make deploy` | Deploy the Worker to Cloudflare |

---

## Scenarios

Scenarios are plain SQLite `.sql` files in `scenarios/`. To capture the current local state as a new scenario:

```bash
make query CMD="INSERT INTO guitars (make, model, color, year_purchased) VALUES ('PRS','Custom 24','Whale Blue',2025)"
make dump NAME=with-prs
```

Load it later (or in another clone) with `make load-scenario NAME=with-prs`.

### Porting a MariaDB schema to D1

`guitars.d1.sql` was hand-ported from the MariaDB original. The recurring transforms:

- `INT AUTO_INCREMENT PRIMARY KEY` → `INTEGER PRIMARY KEY AUTOINCREMENT`
- `YEAR` → `INTEGER` (SQLite has no `YEAR` type)
- `ENUM(...)` → `TEXT … CHECK(col IN (...))`
- `VARCHAR(n)` → `TEXT`; drop `ENGINE=…`, `CHARSET=…`, `COLLATE=…`
- `ON UPDATE CURRENT_TIMESTAMP` → an `AFTER UPDATE` trigger (not needed for the guitars fixture)
- inline non-unique `INDEX` definitions → separate `CREATE INDEX` statements (not needed here)

---

## Scope

This template covers a **Worker + D1** only. Other Cloudflare bindings (KV, R2, Durable Objects, Queues) are intentionally **not** included — they'll be added when a consuming project actually needs them, so the seed/snapshot tooling is designed against a real use case rather than guessed at.
