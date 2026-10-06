# Alchemist Suite — Constellation Contracts

The single contract map for the four-repo constellation (`alchemist-v2`, `DealFinder`,
`Alchemist_Dashboard`, `KeepaCompanion`). **This document owns cross-repo semantics
only** — which repo owns what, what each shared Supabase table promises its consumers,
what the browser's anon key may do, what units money is in, and how the shared Keepa
account is split. Implementation detail stays in each repo's local PRD:

- `alchemist-v2/issues/prd.md`
- `DealFinder/issues/prd.md`
- `Alchemist_Dashboard/issues/prd.md`
- `KeepaCompanion/issues/prd.md`

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
| `wholesale_sync_requests` (schema); `qogita-catalog-webhook` Edge Function | `Alchemist_Dashboard` |
| Qogita catalog-download submit/ingest (`wholesale-sync` stage, Phase 3) | `alchemist-v2` |
| SP-API `analytics` stage (`analytics_cache` snapshot) | `alchemist-v2` |
| `gating_status` (schema + semantics); `gating-check` Edge Function | `alchemist-v2` |
| Keepa Product Finder browser columns; `asin_tracker` (schema + semantics) | `KeepaCompanion` |

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
    the ~2.1k `source = 'miner'` rows are legacy), plus, on rows that fail to enrich,
    either a narrow `last_mined_at`-only touch (found on Keepa but failed validation)
    or a narrow `uk_not_found_at` + `last_mined_at` mark (Keepa has no UK product at
    all — alchemist-v2 issue 023, 2026-07-17) so doomed rows don't retry forever.
  - `alchemist-v2` commands worker (`stage-commands.js` → `db.upsertBareProduct`) — bare
    rows: **only** `ean` / `uk_asin` / `brand`, never signal columns.
  - `alchemist-v2` buy-sheet import (`stage-import.js`).
  - `alchemist-v2` bulk catalog loader (`bulk-load-catalog.js`, issue 022 — one-off
    operator-invoked CLI, not a scheduled stage; dry-run by default, `--execute` to
    write). Insert-only bare rows (`ean` + optional `uk_asin`/`brand`): ON CONFLICT DO
    NOTHING with no merge path, so it can never modify an existing row. New rows are
    stamped `last_mined_at` = load time, deliberately **not** `NULL` — `NULL` is the
    "never attempted, user explicitly asked" front-of-queue signal (issue 027), and a
    bulk load claiming it would bury dashboard-queued EANs; stamped rows remain tier-0
    miner candidates behind user-queued ones. Repairs 11-digit stripped-leading-zero
    UPCs by left-padding to GTIN-13 (root issue 005's chosen fix for the re-load path).
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
  - `last_mined_at` (default `now()`) — "UK signal last refreshed *or attempted*";
    `NULL` = never attempted. The column default used to stamp bare command-queued rows
    with `now()` on insert — which both looked like an attempt that never happened *and*
    sorted user-queued rows to the very back of the miner's oldest-first backlog
    (~6 nights, measured live 2026-07-16). As of alchemist-v2 issue 027 (`2e8a88a`,
    2026-07-16) the commands worker inserts bare rows with an explicit `NULL` and the
    miner enriches never-attempted rows first (deploy-gated: inert until the server
    pulls that commit). Either way, consumers must not read `last_mined_at` as "has
    signal"; the dashboard uses `title IS NOT NULL` to tell enriched from queued.
  - `uk_sales_rank_drops30` (integer, nullable, no default, no index — alchemist-v2
    issue 039, migration `2026-10-05-add-products-uk-sales-rank-drops30.sql`; **code
    landed 2026-10-05, migration not yet applied live — apply before deploying that
    commit or every `upsertProduct` fails**) — Keepa `salesRankDrops30` (UK sales-rank
    drops in the last 30 days), written by the alchemist-v2 miner/import on every full
    enrichment (explicit `null` when Keepa omits it). A velocity *proxy*, never
    sales/month: it must not be read as or merged into `monthly_sold`. Same field as
    DealFinder's `deals.uk_sales_rank_drops30`; DealFinder's `products-upsert` does
    not write it (DealFinder issue 047). Consumer: alchemist-v2 issue 041.
  - `last_evaluated_at` — stamped only when a full economics/gating verdict was computed
    (DealFinder); not yet read by any gating logic.
  - `uk_not_found_at` (timestamptz, nullable, no default — added live 2026-07-17,
    alchemist-v2 issue 023, migration `add_products_uk_not_found_at`) — last time a
    UK lookup found **no product at all** for this EAN/ASIN: either a Keepa product
    lookup returned nothing, or (alchemist-v2 issue 040, only when
    `MINER_SP_PRESCREEN_MODE=enforce`) an SP-API `searchCatalogItems` lookup of a
    13-digit EAN returned a confident empty UK result (no Keepa token spent; `shadow`
    mode never writes it). Written only by the alchemist-v2 miner (service_role); cleared by successful enrichment
    (`upsertProduct` sends an explicit `null`). The miner excludes marked rows from
    the backfill pool for 90 days (`NOT_FOUND_RETRY_DAYS`), after which they re-enter
    at the lowest priority. No grant change was needed (anon's table-level SELECT
    covers new columns — anon may read it, e.g. for a future dashboard "not found on
    Amazon UK" state; see alchemist-v2 issue 028). Deploy-gated: the live server
    keeps plain-touching not-found rows until it pulls alchemist-v2 `2957789`.
    DealFinder's write-through column list does not include it and must leave it
    untouched.
  - `de/fr/it/es_360day_min` (default `-1`) — legacy EU-scan minima; `-1` = never scanned.
  - `has_current_deal` (boolean, default `false`, written by DealFinder only) — **true
    only while the ASIN has a `new`/`notified` `deals` row on some market; false
    otherwise.** Was write-only-true from launch through 2026-07-20 (never cleared,
    94.7%+ of rows stuck true, DealFinder issue 034) — fixed 2026-07-21: DealFinder now
    clears it both when a dismissed/expired ASIN resurfaces in-feed and via a
    post-`expireDeals` re-check (an ASIN with a still-live sibling market is not
    cleared). Corrective one-off backfill applied live the same day: 100,435 → 12,780
    true rows. Readers (e.g. alchemist-v2's backfill miner tie-break) can now trust
    "true" as a genuine current-deal signal.

### `commands` — dashboard→server command queue. Owner: `alchemist-v2` (consumer); payload shape co-owned with dashboard

- **PK:** `id`. Columns: `type`, `payload` (jsonb), `status` (default `'pending'`),
  `error`, `created_at`, `processed_at`.
- **Contract:** anon may **only insert** rows shaped
  `{type: 'queue_backfill_ean', payload: {ean, [uk_asin], [brand]}, status: 'pending'}`
  (RLS-enforced, §3). The service-role worker (`stage-commands.js`, every 15 min) claims
  pending rows oldest-first (batch 500 as of alchemist-v2 issue 021, 2026-07-17;
  deploy-gated — the server drains 50 until it pulls `26c6f23`), validates the EAN,
  upserts a bare `products` row,
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
  `commands`, `housekeeping`, `wholesale-sync`, `analytics`. The dashboard renders
  exactly these names — no aliases. Known drift hazards this contract settles: the scheduler's
  internal console label `miner` (cosmetic, must not leak into `run_log.stage`) and
  the dashboard's legacy `ungating` card key (real stage is `scout`) — the latter
  fixed 2026-07-16 (Alchemist_Dashboard issue 012, `8e0a820`): the card's
  `KNOWN_STAGES` mirrored the first five canonical names exactly; non-canonical
  stages render via its `known:false` fallback. **`wholesale-sync` landed
  2026-07-20 (alchemist-v2 issue 033, Phase 3)** and **2026-07-20 (alchemist-v2 issue
  034, Phase 6)** added a `scheduler.js` cron entry (every 15 min, offset from
  `commands`), gated by `WHOLESALE_SYNC_ENABLED` (default `false` — the cron always
  registers but no-ops until an operator flips the env var and restarts, same
  rollback pattern as the miner window/issue 030). **`Alchemist_Dashboard/src/
  pipeline-status.ts`'s `KNOWN_STAGES` was NOT updated as part of issue 034** — it
  still lists five entries, not six — Phase 5 (G5, UI) landed without touching it
  either, so the "Phase 5 touches that file anyway" assumption in this note's prior
  revision turned out false. This is currently harmless (the switch defaults off, so
  no cron-produced `wholesale-sync` row exists yet), but the moment an operator sets
  `WHOLESALE_SYNC_ENABLED=true`, every 15-min cron row will render via the
  `known:false` drift-alarm fallback instead of a proper card — add the sixth entry
  to `KNOWN_STAGES` *before* or *at* that flip, not after.
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
  DealFinder only; anon read-only. The dashboard's Deals-tab ungating section consumes
  it as-is (`Alchemist_Dashboard/issues/done/005`, landed 2026-07-17 — one bounded GET,
  no write path), never redefining gating semantics.

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
- `scout_log` is service-role-only. `ungate_log` is anon **SELECT-only** since
  2026-09-24 (dashboard migration `20260924120000`) — Wholesale Search's Gate column reads
  it; writes stay service-role. (Its over-broad legacy anon grants were revoked by
  alchemist-v2 issue 019, §6.)
- **`ungate_log` is an ungating-*attempt* log. It cannot answer "is this ASIN listable
  right now" — `gating_status` is the table for that** (added 2026-09-19). Three
  properties get in the way, all verified live on 2026-09-19:
  - **Absence is ambiguous.** `stage-import.js` writes a row only when an ASIN is *not*
    listable (`result: 'failed'`); a clean UK restrictions check writes nothing. So "no
    row" means either "never checked" or "checked and fine", with no way to tell.
  - **Failures and errors are conflated.** That same path records a genuine restriction
    and an SP-API error as the same `result: 'failed'`, separated only by
    `reason_code = 'API_ERROR'` — so a transient outage is indistinguishable from a real
    verdict without parsing the reason code.
  - **`marketplace` does not mean what it says.** `checkRestriction()` always queries
    **UK** (`A1F83G8C2ARO7P`), but rows land on the column's `'de'` default; live values
    are `de`/`es`/`it`/`fr` only, with no `uk` rows at all, because the column actually
    records the EU marketplace a *deal* came from.
  Also, the PK is `asin` alone, so writing restriction checks here would overwrite the
  cooldown data `getRecentUngateAttempts()` depends on. Leave it as the attempt log it
  is. (This is the ground-truth gap `issues/006` is open on — `gating_status` plus the
  `gating-check` function is option 2 of that issue's three, now built.)

### `gating_status` — SP-API listing-restriction cache. Owner: `alchemist-v2`

- **PK:** (`asin`, `marketplace`). Columns: `gated` (boolean, **nullable**),
  `reason_code`, `approval_links` (jsonb), `checked_at` (default `now()`),
  `marketplace` (default `'uk'`). Created live 2026-09-19 (migration
  `alchemist-v2/migrations/2026-09-19-create-gating-status.sql`).
- **Contract:** `gated = true` restricted for our seller account, `false` listable,
  **`null` = the check did not complete** (auth failure, throttle, HTTP error). A null
  row is never a verdict and must never be treated as fresh — retry it. The
  `gating-check` edge function only persists completed checks.
- Writes are service-role only (the `gating-check` edge function). Anon is
  **SELECT-only** since 2026-09-25 (dashboard migration `20260925120000`): Wholesale
  Search's Gate column reads cached verdicts directly, preferring them over `ungate_log`,
  so scans cost no SP-API calls. New checks still go only through `gating-check` (§3),
  which holds the SP-API credentials — the dashboard's "Check gating" button calls it for
  deals with no verdict.

### `asin_tracker` — manual per-ASIN triage state. Owner: `KeepaCompanion`

- **PK:** `asin`. Columns: `status` (`checked` / `bought` / `near_miss` / `pass`,
  CHECK-constrained, nullable), `status_at`, `last_searched_at`, `note`, `updated_at`.
  Created live 2026-09-19 (migration
  `KeepaCompanion/supabase/migrations/20260919220000_create_asin_tracker.sql`).
- **Contract:** deliberately filter-agnostic — one row per ASIN, so a verdict reached
  under one Keepa Product Finder filter is still visible under the next. No other repo
  reads or writes it today. Anon read/insert/update, no delete (clearing a status is an
  UPDATE to null); the CHECK constraint, not the policy, is what bounds the values.

### `wholesale_sync_requests` — Qogita catalog-sync request bookkeeping. Owner: `Alchemist_Dashboard`

- **PK:** `id` (bigint identity). Columns: `status` (default `'pending'`),
  `catalog_request_id`, `download_url`, `filename`, `requested_at`, `completed_at`,
  `error`, `created_at` (default `now()`). Created live 2026-07-20 (Alchemist_Dashboard
  issue 015/016, migration `20260720130000`).
- **Contract:** bookkeeping only, never catalog data (owner ruled out a Qogita-catalog
  data table entirely — issue 015 Design). A handful of ephemeral rows. Status lifecycle:
  `pending` (anon-inserted) → `requested` (alchemist-v2's `wholesale-sync` stage submit
  leg, landed 2026-07-20, issue 033 — Phase 3) → `ready` / `failed` (the
  `qogita-catalog-webhook` Edge Function, on Qogita's completion webhook) → `done` (the
  same stage's ingest leg) or `failed` (submit error, or a Storage upload failure on
  ingest).
- **Writers:** anon may only INSERT a fresh `pending` row (§3). The Edge Function and the
  `wholesale-sync` stage both write via service_role, bypassing RLS. **2026-07-20
  correction:** the creation migration (`20260720130000`) never actually granted
  `service_role` anything — this project has no default-privilege rule auto-granting
  new public tables to `service_role` (`pg_default_acl` confirmed empty), unlike the
  common Supabase assumption. Caught live during the G4 pilot (permission denied on
  every real stage invocation, despite 208/208 green mocked tests); fixed with a
  follow-up migration (`20260720140000`, `grant select, update to service_role`).
  Check `information_schema.role_table_grants` for `service_role` before trusting any
  new table's service-role code path.
- **Readers:** the dashboard polls its own request's status (no push channel available to
  a static SPA).
- **Storage:** the ingest leg streams the downloaded CSV into Storage bucket
  `wholesale-catalogs` (private, created live 2026-07-20 via Supabase MCP
  `apply_migration` — Phase 2 didn't create it), path `latest.csv`, overwritten each
  sync (no per-request versioning, single-user tool). Owner: `alchemist-v2` (the only
  writer, service_role). **2026-07-20 (G4 pilot):** the real Qogita full-catalog CSV is
  ~85MB, which exceeded this project's Free-plan Storage cap (global 50MB limit, no
  bucket-level override possible). Resolved by gzip rather than a plan upgrade
  (owner's call): the ingest leg now pipes the download through `zlib.createGzip()`
  before upload — object is `latest.csv.gz`/`application/gzip`, ~76% smaller
  (85MB → 20.6MB on the real catalog), comfortably under the cap. Any reader must
  decompress (`DecompressionStream('gzip')`) before parsing. **2026-07-20 (Phase 5):**
  anon SELECT granted, scoped to this one object (`storage.objects` policy
  `USING (bucket_id = 'wholesale-catalogs' AND name = 'latest.csv.gz')`, dashboard
  migration `20260720150000`) — `anon` already carries table-level SELECT on
  `storage.objects` (Supabase's standard managed grant, verified live), so this
  policy is the only gate. A write to any other path in the bucket stays private.

### `analytics_cache` — SP-API snapshot for the dashboard. Owner: `alchemist-v2`

- **PK:** `id` (bigint identity). Columns: `snapshot_at` (default `now()`), `fba_stock`
  (jsonb), `recent_orders` (jsonb), `next_disbursement` (jsonb), `lot_inventory` (jsonb,
  nullable). Created live 2026-07-21 (alchemist-v2 issue 024, migration
  `2026-07-21-create-analytics-cache.sql`); `lot_inventory` added live 2026-07-23
  (alchemist-v2 issue 036, root RUNLIST I3a, migration
  `2026-07-23-add-analytics-cache-lot-inventory.sql`) — additive, no grant change
  (existing service_role INSERT + anon SELECT already cover new columns).
- **`lot_inventory` shape (issue 036, Phase 1 of Alchemist_Dashboard issue 018):** array
  of per-lot records, one per BuySheet row carrying a real Amazon Seller SKU (going
  forward only — legacy rows sharing one SKU across historical batches have no `sku`
  value and stay in the existing ASIN-blended `fba_stock` cost basis, not retrofitted).
  Each record: `{ sku, asin, qtyPurchased, unitCostPence, purchaseDate, qtyAtAmazon,
  shipped, qtySoldInferred, avgSalePricePence, mismatch }`. `qtyAtAmazon` sums every
  SP-API inventory bucket for that SKU (self-correcting for returns run-over-run, no
  separate return tracking); `shipped` is true when `qtyAtAmazon > 0` **or** the SKU has
  ever appeared in Orders history (disambiguates a fully-sold-out lot from one never
  shipped); `qtySoldInferred = qtyPurchased - qtyAtAmazon`; `avgSalePricePence` is sourced
  from real Orders/Finance order-item history for that SKU (never
  `products.uk_current_price`), null with no matching order items; `mismatch` is true
  only when `qtyAtAmazon > qtyPurchased` (operator-confirmed rule, 2026-07-23 — the one
  unambiguous data error, not a broader reconciliation check). `analytics.js`'s
  `buildLots`/`shapeLots` is the shaping logic; `sp-api.js`'s `getOrderItemsForSku` is the
  new SP-API surface (Orders v0 API + per-order Order Items, filtered to one SellerSKU).
- **Incremental order-history cache (alchemist-v2 issue 037, 22111c9, 2026-10-05):** each
  lot record also carries (additive; existing field names unchanged):
  `cumulativeSoldQtyFromOrders` (int — units across matched Orders lines with a valid qty
  and price; each order counted once, at first sight, deduped by `AmazonOrderId`; counts
  from epoch when the lot has no `purchaseDate`), `cumulativeSaleRevenuePence` (int — sum
  of round(`ItemPrice.Amount` x 100); `Amount` is the line total, excludes shipping),
  `cumulativeOrderLines` (int — matched lines ever seen, including unpriced ones),
  `ordersCheckedThrough` (ISO or null — the Orders `CreatedBefore` bound this lot is fully
  checked through; null = next run full-scans; **never moves earlier than its previous
  value**; lags the window end while an order is `Pending` or its items failed to load)
  and `recentOrders` (`[{orderId, createdAt}]` — internal dedupe bookkeeping; consumers
  ignore it). `avgSalePricePence` is now `round(revenue / qty)` (null at qty 0) and
  `shipped = qtyAtAmazon > 0 || cumulativeOrderLines > 0`; on a lot lookup failure both
  carry forward from the prior record instead of going null / live-qty-only. `Pending`
  orders are not counted until they leave Pending; an order cancelled after being counted
  stays counted; an order arriving >2h behind the watermark is missed (accepted limits).
  A prior record is reused only if its `purchaseDate` matches the BuySheet and its
  accumulators are valid; otherwise that lot full-scans.
- **Contract:** one wide row per stage run (never updated); the dashboard reads only
  the latest row (`order by snapshot_at desc limit 1`). Money in `fba_stock`/
  `recent_orders`/`next_disbursement` is integer pence (§4), computed at the
  read-from-Sheets/SP-API boundary.
- **Scope, settled by a pre-build grill (2026-07-21, root RUNLIST F2 — see
  alchemist-v2 `analytics.js`'s header for the full reasoning):** `fba_stock` is
  **API-only, deliberately partial** — live SP-API inventory units (available +
  reserved + the inbound-to-Amazon pipeline + researching + unfulfillable) valued at
  a per-ASIN cost price averaged from the `alchemist-v2`/`Alchemist_Dashboard` shared
  BuySheet (matched by ASIN, no per-batch lot tracking). Stock still sitting at a 3PL/
  prep centre **before** it ships to Amazon is invisible to every SP-API endpoint and
  is **not estimated** — a DB-inferred ledger (comparing FBA-unit deltas run over run)
  was considered and rejected as it would silently drift on returns/removals with no
  self-correction. `next_disbursement` is likewise an estimate (the currently-open
  finance period's running total), not a true Amazon forward projection — no such
  SP-API endpoint exists.
  **`fba_stock.perAsin` never drops a row (fixed same day, DealFinder-adjacent bug
  spotted via a live Seller Fuse export comparison):** every ASIN SP-API's inventory
  summaries endpoint reports gets a `perAsin` entry, even at `units: 0` — a prior
  version silently discarded any item whose narrower unit formula computed to `<=0`,
  which is how real FBA stock (units sitting in the `researchingQuantity`/
  `unfulfillableQuantity` buckets, not summed at all before this fix) vanished from the
  Inventory tab with no trace and no BuySheet-cost-basis nudge. `unmatchedAsins` still
  only counts `units > 0` rows with no BuySheet match, so its count/note text stays
  accurate to "has real stock, needs a cost row" — a true zero-unit ASIN is shown but
  not counted there.
- **Writers:** `alchemist-v2`'s `analytics` stage (service_role) only, `insertAnalyticsSnapshot` (`db.js`).
  **Manual dispatch only** (`node index.js --stage analytics`) — no cron for v1
  (owner's call: "on request"). Because it's never cron'd, a run's `run_log` row is
  the only regular producer of the `analytics` stage name; `Alchemist_Dashboard`'s
  `KNOWN_STAGES` was deliberately not updated for this — same reasoning as
  `wholesale-sync`'s pre-cron phase (safe to render via the `known:false` drift-alarm
  fallback until/unless this ever gets a cron entry).
- **Readers:** `Alchemist_Dashboard` (issue 008, landed 2026-07-21) built both — a
  "Live check" line on the Finance tab (the capital-invested check this table was
  actually built for) plus the full stock/orders/disbursement breakdown on the
  Inventory tab (the originally-stubbed scope). Both read the latest row only
  (`order=snapshot_at.desc&limit=1`) over the existing anon SELECT grant, no new
  grant/policy needed. `lot_inventory` gained its dashboard reader 2026-07-27
  (Alchemist_Dashboard issue 018 Phase 2, root RUNLIST I3b, `42e62ba`): a per-lot
  table on the Inventory tab, plus Finance tab's `d-fba`/`d-waiting` re-sourced to
  sum `lot_inventory` (`sumLotFbaValuePence`/`sumLotWaitingValuePence`) instead of
  `fba_stock.totalValuePence` / the manual snapshot — SKU-tracked lots only, so those
  two Finance fields now read lower than the Inventory tab's own (unchanged) ASIN-
  blended summary box until lot coverage grows. Deliberate, not a bug — see
  Alchemist_Dashboard CLAUDE.md.

### `tracking_log_archived` — archived, read-only

Frozen history of retired sniper Keepa trackings (0 rows live). No live writer; not a
contract surface. Listed only so nobody "rediscovers" it.

## 3. Anon write surface (the browser key)

The dashboard and the KeepaCompanion extension are the anon-key clients. The
**complete** sanctioned anon surface, verified live 2026-07-15 (grant + policy both
checked), with `asin_tracker` added and verified live 2026-09-19:

| Table | Anon may | Enforced by |
|---|---|---|
| `commands` | INSERT only | grant: INSERT; policy `WITH CHECK (type = 'queue_backfill_ean' AND status = 'pending' AND payload ? 'ean')`. No SELECT/UPDATE/DELETE. |
| `deals` | SELECT all; UPDATE **columns** `status, bought_price_cents, bought_quantity, bought_at, dismissed_at` | column-scoped UPDATE grant; policy `USING (status IN ('new','notified')) WITH CHECK (status IN ('bought','dismissed'))` |
| `business_snapshots` | SELECT / INSERT / UPDATE / DELETE | table grants (TRUNCATE revoked); permissive `using(true)` policy — accepted for single-user finance data |
| `deal_notifications` | SELECT only | grant + read policy |
| `ungating_opportunities` | SELECT only | grant + read policy |
| `products` | SELECT only | grant: SELECT (dashboard migration `20260715120000`, fixing §6 item 3) + pre-existing `USING (true)` read policy |
| `run_log` | SELECT only | grant + `USING (true)` read policy (dashboard migration `20260715120000`) |
| `wholesale_sync_requests` | SELECT all; INSERT rows shaped `{status: 'pending', catalog_request_id: null}` | grant: SELECT, INSERT; policy `WITH CHECK (status = 'pending' AND catalog_request_id IS NULL)` on insert, `USING (true)` on select (dashboard migration `20260720130000`) |
| Storage object `wholesale-catalogs/latest.csv.gz` | SELECT (GET) only | `storage.objects` policy scoped to `bucket_id = 'wholesale-catalogs' AND name = 'latest.csv.gz'` (dashboard migration `20260720150000`) |
| `analytics_cache` | SELECT only | grant: SELECT + `USING (true)` read policy (alchemist-v2 migration `2026-07-21-create-analytics-cache.sql`) |
| `ungate_log` | SELECT only | grant: SELECT + `USING (true)` read policy (dashboard migration `20260924120000`) — Wholesale Search Gate column |
| `gating_status` | SELECT only | grant: SELECT + `USING (true)` read policy (dashboard migration `20260925120000`) — Wholesale Search Gate column; writes only via `gating-check` |
| `asin_tracker` | SELECT / INSERT / UPDATE (no DELETE) | grants + permissive `using(true)` policies (KeepaCompanion migration `20260919220000`); the `status` CHECK constraint is what bounds the values. Accepted for single-user triage data, same call as `business_snapshots`. |

Everything else (`scout_log`, `tracking_log_archived`):
**no anon access**.

Rules:

- The browser never writes `products`, and never triggers Keepa or SP-API work directly —
  it queues a `commands` row and waits for the server (user stories 6, 9, 11).
- **The one sanctioned synchronous exception is the `gating-check` edge function**
  (added 2026-09-19 for KeepaCompanion's Gate column; since 2026-09-25 also called by the
  dashboard's Wholesale Search "Check gating" button, which needed the function's CORS
  preflight support, added in v10). The browser still holds no SP-API
  credentials: the function owns them, runs with the service role, serves the
  `gating_status` cache first, caps a request at 50 ASINs, and is gated on a shared
  secret (`KC_SHARED_SECRET`) on top of the anon JWT. The `commands` queue stays the
  path for anything unbounded or long-running — a 15-minute worker cannot back a live
  grid column, which is why this exists at all. Any further "browser asks the server to
  spend money now" path needs the same shape: server-held credentials, a bounded batch,
  a cache in front, and an entry here.
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
  (every 15 min, 21:00–04:59) — these are the **default** expressions, derived from
  env-tunable `MINER_WINDOW_START_HOUR` / `MINER_WINDOW_END_HOUR` (default 21 / 5,
  end-exclusive like DealFinder's `OVERNIGHT_PAUSE_*_HOUR` above; `start === end` means
  all-day — `miner-schedule.js`'s `minerCronExpressions`, issue 030). Each run sizes
  itself from the **live** balance via Keepa's free `/token` endpoint
  (`keepa.getTokenStatus()`); `TOKEN_LIMIT_MINER` is only an optional operator ceiling.
  Frequent small drains, not two big bursts — the bucket caps out and idles within
  minutes once DealFinder pauses. **Widening the window beyond the default overnight
  split is sanctioned only with DealFinder paused** (e.g. the E4 700k-catalog pilot) —
  otherwise the two probes fight over the same token bucket.
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
