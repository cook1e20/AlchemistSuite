# Alchemist Suite — Constellation Contracts

The single contract map for the three-repo constellation (`alchemist-v2`, `DealFinder`,
`Alchemist_Dashboard`). **This document owns cross-repo semantics only** — which repo
owns what, what each shared Supabase table promises its consumers, what the browser's
anon key may do, what units money is in, and how the shared Keepa account is split.
Implementation detail stays in each repo's local PRD:

- `alchemist-v2/issues/prd.md`
- `DealFinder/issues/prd.md`
- `Alchemist_Dashboard/issues/prd.md`

Parent PRD: `issues/constellation-prd.md`. Per the root `README.md`: if this document
conflicts with a child repo on a *cross-repo contract*, this document wins; on *local
implementation detail*, the child repo wins.

**Live verification.** Every schema/RLS/grant claim below was verified read-only against
the live shared Supabase project **A2ASearch (`rzxtppclwfulyxfatezr`)** on **2026-07-15**
via the Supabase MCP tools — not taken from local schema files, which have drifted before
(see `alchemist-v2/CLAUDE.md` on `setup-db.js`). Discrepancies found during verification
were logged as repo-local issues in the owning repo (listed at the end), not silently
corrected here. Re-verify against the live DB before trusting this doc for a change; it
is a snapshot, refreshed when re-verified.

---

## 1. Workflow ownership

| Workflow | Owner |
|---|---|
| `products` enrichment (Keepa UK signal, channel-neutral target price) | `alchemist-v2` |
| `commands` consumption (claim/complete dashboard-queued backfills) | `alchemist-v2` |
| `run_log`, `scout_log`, `ungate_log` production | `alchemist-v2` |
| Scheduler (long-running cron process) + Discord stage summaries | `alchemist-v2` |
| Buy-sheet import, SP-API ungating checks | `alchemist-v2` |
| EU→UK deal probing and deal lifecycle | `DealFinder` |
| `deals`, `deal_notifications`, `ungating_opportunities` (schema + semantics) | `DealFinder` |
| `products` write-through from evaluated deals (signal columns only) | `DealFinder` |
| Browser UI; all anon-key payload shapes | `Alchemist_Dashboard` |
| `business_snapshots` (finance history) | `Alchemist_Dashboard` |
| Deal review actions (buy/dismiss), wholesale matching, command insertion, status rendering | `Alchemist_Dashboard` |

Code and schema changes are implemented in the owning repo. A system issue may name
several repos, but the work is split so one iteration owns one task in one repo.

## 2. Shared table contract

RLS is **enabled on every table** in the shared project (verified live 2026-07-15).
Server-side writers use the **service_role** key, which bypasses RLS; the browser
uses the **anon** key, which needs *both* a grant *and* a policy. Effective anon access
per table is in §3.

### `products` — permanent master catalog. Owner: `alchemist-v2`

- **PK:** `ean` (text). Permanent: rows are re-enriched when stale, never deleted for
  staleness; the table only grows (~34.8k rows at verification).
- **Writers (service_role):**
  - `alchemist-v2` backfill miner (`stage-miner.js`) — full enrichment upsert
    (`source = 'backfill-miner'` — corrected 2026-07-16 against code and live data;
    the ~2.1k `source = 'miner'` rows are legacy), plus a narrow `last_mined_at`-only
    touch on rows that fail to enrich (so doomed rows don't retry forever).
  - `alchemist-v2` commands worker (`stage-commands.js` → `db.upsertBareProduct`) — bare
    rows: **only** `ean` / `uk_asin` / `brand`, never signal columns.
  - `alchemist-v2` buy-sheet import (`stage-import.js`).
  - `DealFinder` write-through (`src/products-upsert/`, `source = 'dealfinder'`) — writes
    only the columns its header comment lists (ean, uk_asin, de_asin, title, brand,
    uk_current_price, uk_avg30_price, monthly_sold, seller_count, source,
    has_current_deal, last_mined_at, last_evaluated_at); everything else is
    Alchemist-owned and must be left untouched. That header comment is the authoritative
    column reference on the DealFinder side.
- **Readers:** dashboard Wholesale Search (EAN matching), DealFinder cache pre-filter,
  alchemist-v2 candidate selection.
- **Key column semantics:**
  - `target_gb_price` — the channel-neutral desired price; see §4.
  - `last_mined_at` (default `now()`) — "UK signal last refreshed *or attempted*". The
    default means a bare command-queued row gets `now()` on insert **before any real
    enrichment** — consumers must not read `last_mined_at` as "has signal"; the dashboard
    uses `title IS NOT NULL` to tell enriched from queued.
  - `last_evaluated_at` — stamped only when a full economics/gating verdict was computed
    (DealFinder); not yet read by any gating logic.
  - `de/fr/it/es_360day_min` (default `-1`) — legacy EU-scan minima; `-1` = never scanned.

### `commands` — dashboard→server command queue. Owner: `alchemist-v2` (consumer); payload shape co-owned with dashboard

- **PK:** `id`. Columns: `type`, `payload` (jsonb), `status` (default `'pending'`),
  `error`, `created_at`, `processed_at`.
- **Contract:** anon may **only insert** rows shaped
  `{type: 'queue_backfill_ean', payload: {ean, [uk_asin], [brand]}, status: 'pending'}`
  (RLS-enforced, §3). The service-role worker (`stage-commands.js`, every 15 min) claims
  pending rows oldest-first (batch 50), validates the EAN, upserts a bare `products` row,
  and sets `status` to `'done'` or `'failed'` (+ `error`, `processed_at`). Duplicates of
  an already-queued EAN are marked `done`.
- The payload shape is pinned on both sides: dashboard `wholesale-queue.ts`
  (`buildQueueBackfillRows`) must match `stage-commands.js`'s handler. Extra payload keys
  are tolerated; `ean` is mandatory (the RLS policy checks `payload ? 'ean'`).
- Anon has **no SELECT** on `commands` — the dashboard tracks its own queued EANs in
  localStorage by design.

### `run_log` — Alchemist operational status. Owner: `alchemist-v2`

- **PK:** `id`. Columns: `stage`, `status` (default `'running'`), `stats` (jsonb),
  `started_at` (default `now()`), `finished_at`.
- **Canonical stage names (the published contract):** `mine`, `import`, `scout`,
  `commands`, `housekeeping`. The dashboard renders exactly these names — no aliases.
  Known drift hazards this contract settles: the scheduler's internal console label
  `miner` (cosmetic, must not leak into `run_log.stage`) and the dashboard's legacy
  `ungating` card key (real stage is `scout`) — the latter fixed 2026-07-16
  (Alchemist_Dashboard issue 012, `8e0a820`): the card's `KNOWN_STAGES` now mirrors
  the five canonical names exactly; non-canonical stages render via its
  `known:false` fallback.
- **Current state:** writers landed 2026-07-15 (alchemist-v2 `7a0e170`, issue 017):
  `run-log.js`'s `withRunLog` wraps every stage run in both dispatchers (`index.js`
  CLI and `scheduler.js`, the deployed cron process). Statuses: `running` →
  `completed` / `completed_with_errors` (from `stats.errors`) / `failed` (stage threw;
  message in `stats.error`). `full` CLI runs log child stages individually — no `full`
  row; dry runs write nothing. **Live state (2026-07-16, root issue 003):** the server
  pulled and restarted on `36084f3` and the first canonical row (`commands`,
  `completed`, 08:00:00Z) was verified live — run_log recency is now the primary
  scheduler-liveness signal (VERIFICATION.md §2.2). 86 legacy `stage='wholesale'` rows
  remain (newest 2026-07-06, pre-strip code; housekeeping purges them at >60d) —
  `wholesale` is not a canonical name; the dashboard must keep ignoring it.
- Timestamp gotcha: values come back as `+00`-offset strings that `new Date()` rejects;
  the dashboard compares them lexically (`pipeline-status.ts`).

### `deals` — deal lifecycle. Owner: `DealFinder`

- **PK:** `(asin, marketplace)` (marketplace default `'de'`). Large (~132k rows at
  verification) — consumers fetch bounded slices, never the lot.
- **Writers:** DealFinder (service_role) owns creation, enrichment, evaluation, and
  status transitions to `notified`; the dashboard (anon) may only record buy/dismiss
  decisions via the column-scoped surface in §3.
- **Status lifecycle:** `new` / `notified` → `bought` / `dismissed`. The anon policy
  enforces exactly that transition; `deal-actions.ts` (dashboard) is the single source of
  the payload shape.
- Units are deliberately mixed per side — see §4.

### `deal_notifications` — notification dedupe. Owner: `DealFinder`

- **PK:** `asin`. Columns: `notified_price_cents` (EUR cents), `notified_at`,
  `notified_marketplace`, `updated_at`. Written by DealFinder only; anon read-only.

### `ungating_opportunities` — gated-but-attractive deals. Owner: `DealFinder`

- **PK:** `(asin, marketplace)`. EU side in cents, UK side in pence (§4). Written by
  DealFinder only; anon read-only. The dashboard's Ungating tab consumes it as-is
  (`Alchemist_Dashboard/issues/005`), never redefining gating semantics.

### `business_snapshots` — finance history. Owner: `Alchemist_Dashboard`

- **PK:** `id`; `snap_date` unique. All money columns integer **pence** (§4); `*_pct`
  columns `numeric` percentages. Dashboard-only data: written and read by the Finance tab
  via anon (§3); no server writer.

### `scout_log`, `ungate_log` — ungating operational logs. Owner: `alchemist-v2`

- `scout_log` PK `brand`: per-brand scout batch results (`asin_count`, `ungated_count`,
  `scouted_at`).
- `ungate_log` PK `asin`: per-ASIN ungating attempt (`brand`, `result`, `reason_code`,
  `attempted_at`, `marketplace` default `'de'`). DealFinder reads gating **live from
  `ungate_log`** rather than from any denormalized column on `products` (none exists —
  deliberate, see DealFinder issue 028).
- Both are service-role-only in practice. (`ungate_log`'s over-broad legacy anon grants
  are a logged discrepancy, §6.)

### `tracking_log_archived` — archived, read-only

Frozen history of retired sniper Keepa trackings (0 rows live). No live writer; not a
contract surface. Listed only so nobody "rediscovers" it.

## 3. Anon write surface (the browser key)

The dashboard is the only anon-key client. The **complete** sanctioned anon surface,
verified live 2026-07-15 (grant + policy both checked):

| Table | Anon may | Enforced by |
|---|---|---|
| `commands` | INSERT only | grant: INSERT; policy `WITH CHECK (type = 'queue_backfill_ean' AND status = 'pending' AND payload ? 'ean')`. No SELECT/UPDATE/DELETE. |
| `deals` | SELECT all; UPDATE **columns** `status, bought_price_cents, bought_quantity, bought_at, dismissed_at` | column-scoped UPDATE grant; policy `USING (status IN ('new','notified')) WITH CHECK (status IN ('bought','dismissed'))` |
| `business_snapshots` | SELECT / INSERT / UPDATE / DELETE | table grants (TRUNCATE revoked); permissive `using(true)` policy — accepted for single-user finance data |
| `deal_notifications` | SELECT only | grant + read policy |
| `ungating_opportunities` | SELECT only | grant + read policy |
| `products` | SELECT only | grant: SELECT (dashboard migration `20260715120000`, fixing §6 item 3) + pre-existing `USING (true)` read policy |
| `run_log` | SELECT only | grant + `USING (true)` read policy (dashboard migration `20260715120000`) |

Everything else (`scout_log`, `ungate_log`, `tracking_log_archived`): **no anon
access**.

Rules:

- The browser never writes `products`, and never triggers Keepa or SP-API work directly —
  it queues a `commands` row and waits for the server (user stories 6, 9, 11).
- Any new anon capability is a **contract change**: it needs a dashboard-owned migration
  (grant *and* narrow policy, `deals`-style — not `using(true)` unless genuinely
  single-user/low-stakes) and an update to this table.
- Locally the connection pill may hold a service key, which bypasses all of this — "works
  locally" is not evidence the anon contract works.

## 4. Money and price units

**Global rule: prices are integer pence/cents, never floats.** Convert at the display
edge only.

| Table | Columns | Unit |
|---|---|---|
| `products` | `uk_current_price`, `uk_avg30_price`, `uk_breakeven_ex_vat`, `uk_breakeven_inc_vat`, `target_gb_price`, `target_gb_price_high`, `fba_pick_pack` | GBP **pence** (integer) |
| `products` | `referral_pct` | numeric percentage |
| `products` | `de/fr/it/es_360day_min` | EUR **cents** (legacy EU scan; `-1` = never scanned) |
| `deals` | `eu_price_cents`, `avg30_price_cents`, `notified_price_cents`, `bought_price_cents` | EUR **cents** (buy side) |
| `deals` | `uk_*_pence`, all `eval_*_pence` | GBP **pence** (sell side) |
| `deals` | `eval_roi`, `eval_per_seller_monthly_share` | fractions (×100 for %) |
| `deal_notifications` | `notified_price_cents` | EUR **cents** |
| `ungating_opportunities` | `eu_price_cents` | EUR **cents**; `uk_*_pence` GBP **pence** |
| `business_snapshots` | `bank`, `amazon_balance`, `fba_inventory`, `waiting_to_ship`, `amex_balance`, `cot_balance`, `net_invested`, `capital_injected`, `capital_withdrawn`, `total_cash`, `total_inventory`, `total_liabilities`, `total_capital`, `pnl` | GBP **pence** (integer, since dashboard migration `20260709150000`) |
| `business_snapshots` | `roic_pct`, `inv_pct` | `numeric(6,2)` percentages |

**Channel-neutral target price** (`products.target_gb_price`): the maximum **landed
cost** at a **20% ROI floor** — `netUkProceeds / 1.20` — with **zero postage or
channel-specific cost baked in**. Server-computed only (alchemist-v2 miner, aligned with
DealFinder's economics model). Each consumer (DealFinder EU probe, OA reverse sourcing,
manual wholesale) subtracts its *own* costs downstream. Never bake one channel's cost
into the stored price, and never recompute/"adjust" it in the UI.

## 5. Keepa account coordination

One Keepa account (one token bucket) is shared deliberately:

- **DealFinder stands down overnight:** the hourly probe skips its tick entirely during
  the UK-local window **21:00–05:00** (defaults; env-tunable
  `OVERNIGHT_PAUSE_START_HOUR` / `OVERNIGHT_PAUSE_END_HOUR`, DST handled via
  `Intl` `Europe/London` — `DealFinder/issues/done/031-overnight-pause.md`,
  `src/overnight-pause/`).
- **alchemist-v2's miner owns that window:** cron `*/15 21-23 * * *` + `*/15 0-4 * * *`
  (every 15 min, 21:00–04:59). Each run sizes itself from the **live** balance via
  Keepa's free `/token` endpoint (`keepa.getTokenStatus()`); `TOKEN_LIMIT_MINER` is only
  an optional operator ceiling. Frequent small drains, not two big bursts — the bucket
  caps out and idles within minutes once DealFinder pauses.
- **Rule: Keepa-token spend is server-side and schedule-gated only.** No dashboard action
  spends tokens live; the dashboard's only path to Keepa work is queueing a `commands`
  row that the overnight miner eventually services.
- **Gotcha (fixed 2026-07-16, alchemist-v2 issue 020 / commit `36084f3`):** `--dry-run`
  used to gate only the DB write — the Keepa API calls fired unconditionally, so a
  casual `node index.js --stage mine --dry-run` cost real tokens. Now both `mine` and
  `import` stop before the first paid Keepa call under `--dry-run` (candidate-selection
  / sheet-validation report only; the free `/token` balance read stays). **Deploy
  caveat resolved:** the server pulled `36084f3` and was verified live 2026-07-16
  (first canonical `run_log` row at 08:00:00Z) — `--dry-run` is now genuinely
  spend-free on the deployed scheduler too. Re-verify via VERIFICATION.md §2.2 after
  any future deploy before trusting dry-run on the server.

## 6. Discrepancies found during live verification (2026-07-15)

Logged as repo-local issues in the owning repo, per the issue-routing rule:

1. **`alchemist-v2/issues/018-bug-claude-md-rls-note-stale.md`** — CLAUDE.md still says
   "RLS is disabled; access relies on explicit grants"; live, RLS is enabled on all 10
   tables. **Fixed 2026-07-16** (alchemist-v2 `b6aa0ee`): CLAUDE.md and ARCHITECTURE.md
   now describe the live model and defer per-table detail to §2/§3 here.
2. **`alchemist-v2/issues/019-bug-ungate-log-anon-grants-overbroad.md`** — `ungate_log`
   grants anon/authenticated full table privileges (incl. TRUNCATE/DELETE) with RLS on
   and zero policies. Effective anon access is denied today, but the grants are the same
   over-broad legacy pattern dashboard issue 011 fixed elsewhere.
3. **`Alchemist_Dashboard/issues/013-bug-anon-read-surface-gaps.md`** — `products` had an
   anon read *policy* but no anon SELECT *grant* (anon reads failed); `run_log` had no
   anon access at all. **Fixed 2026-07-15** by dashboard migration
   `20260715120000_anon_read_products_run_log.sql` (SELECT-only grants + `run_log` read
   policy; verified live as the anon role, no write privilege added).
