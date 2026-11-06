# Spec: Supplier best offers (grilled 2026-11-06)

Part A of the "supplier tabs" idea: a standing list of the best current offers from each wholesale pull, shown as tabs on the dashboard's Wholesale page. Builds on R53 (`spec-qogita-price-drops.md`, alchemist-v2 062-065). Part B (automated eany.io pull, then an eany tab) is a separate spec, grilled after a joint Chrome session (Q8, Q10). Part A is built supplier-agnostic so eany slots in.

## Problem Statement

The drop alerts (064) only show what got cheaper. They don't show what is profitable right now at a steady price, and nothing on the dashboard lists the current good offers from the last pull. The Wholesale Search page does this only on demand, for a file I upload by hand.

## Facts established 2026-11-06

- Coverage of a random 2,000 Qogita GTINs (today's pull, 243,600 GTINs) against `products` by zero-stripped GTIN key: 332 in `products` (17%), 319 with an ASIN, 262 mined with fees, **18 with `uk_buybox_avg30_pence` (0.9%)**, 261 with `uk_avg30_price`, 83 passing the sales test.
- Whole `products` table: 1,101,341 rows; 7,593 with a buy-box avg30 (buy-box averages are only fetched on `buybox=1` lookups since alchemist-v2 054). The miner touched 136,212 rows in the last 7 days.
- The miner only enriches existing `products` rows (issue 011); it never adds Qogita GTINs. So without a load, ~83% of the Qogita catalogue never gets an ROI.
- eany.io (for Part B): export email from `no-reply@eany.io` to `jurassicdesignlabs@gmail.com` (the connected Gmail), full catalogue CSV, ~817k-852k products, link `http://eany.io/exports/<uuid>/download`, expires ~6 h after the email. Whether the link needs a logged-in session is unknown (Q10 session).

## Decisions (grill 2026-11-06)

| # | Decision |
|---|---|
| Q1 | Spec A now; B is its own spec after the Chrome session. A carries a `supplier` column and no Qogita assumptions in its logic. |
| Q2a | Matched rows only (GTIN in `products` with ASIN and fees). No "unknown ROI" rows. |
| Q2b | Load Qogita GTINs missing from `products` as bare rows via the `bulk-load-catalog.js` rules (insert-only, `last_mined_at` stamped = back of the queue, never null). Only GTINs passing the 064 stock rule. One initial load, then a top-up of new qualifying GTINs on the first pull of each London day. |
| Q3 | ROI basis per row: buy-box averages (BB) where present, else the 30-day new-price average `uk_avg30_price` (NEW). Row shows which. Where two averages exist, the lower ROI must clear the floor (conservative, as 064's profit figure). Fees re-derived at the basis price as 064 does. |
| Q4 | Stock: 064's rule (cheapest offer >= 5 units OR >= £500 stock value ex VAT), same settings. |
| Q5 | Sales test: `uk_sales_rank_drops30 >= 3` OR `monthly_sold > 0` (the miner's buy-box test). Gated ASINs shown with a badge, not hidden. Default sort profit/month. |
| Q6 | Upsert per supplier on each fresh pull, delete rows that no longer qualify; keep `first_qualified_at` for a "new" badge. Cached pulls skip the rebuild. Dashboard reads it: anon SELECT grant + policy (CONTRACTS.md section 3 change). |
| Q7 | Sub-tabs `Qogita` / `eany` on the Wholesale page (eany disabled until Part B). Sortable table: product, brand, ASIN link, cost inc VAT, basis (BB/NEW), sell price 30/90, ROI 30/90, profit/unit, profit/month, units, stock value, gated badge, new badge, drop badge (row also in today's `qogita_drop_candidates`), supplier link. Row action "send to pre-screen". |
| Q9 | Row action "block brand" (with confirm) inserts into `qogita_blocked_brands`; the brand's rows vanish from the tab at once (client-side) and the next pull excludes them. The list is supplier-wide; the table keeps its name, CONTRACTS.md notes the wider meaning. |
| Q10 | Part B debugged as a joint session: Claude drives Chrome via the extension, operator logs in / handles captcha, Claude captures the export request and tests the email link. |
| Q12 | NEW-basis rows are queued for a Keepa buy-box re-mine, max 100/day (setting), highest profit/month first, inside the miner's window, so they move to BB. |
| Q13 | Server stores loose floors (ROI >= 15%, the stock rule, the sales test). The tab has controls (ROI floor default 20%, min units, min stock value) that filter client-side. |

## Solution

### 1. Catalogue load into `products` (alchemist-v2)

- Initial: a one-off run over the latest Qogita snapshot, through `bulk-load-catalog.js` (or a thin wrapper reusing its insert-only path), filtered to the 064 stock rule. Dry-run by default.
- Daily: on the first fresh pull of each London day (the same point 063's rebuild runs), insert qualifying GTINs not yet in `products`, same rules. Count in `run_log.stats` (`productsLoaded`).
- New rows' `last_mined_at` = load time (never null: null is the dashboard/wholesale front-of-queue signal, issue 027/050).

### 2. Amazon signal cache (alchemist-v2, SQLite)

- Nightly, page the `products` rows matching the supplier's GTINs (zero-stripped key, same matcher as 064) into a SQLite table: ASIN, buy-box avg30/90, `uk_avg30_price`, referral %, FBA pick-pack, `monthly_sold`, drops30, brand. Avoids ~2,400 `products` reads per pull.
- Gating comes from the existing cache, as 064 reads it.

### 3. Best-offers rebuild (alchemist-v2)

- On every fresh pull, after 063/064: for each matched GTIN, apply stock rule, sales test, not pre-order, brand not blocked, ROI (Q3) >= 15% stored floor.
- Blocked brands read paged; a failed read skips the rebuild for that pull (never shows blocked brands).
- Write to `supplier_best_offers` (upsert on `(supplier, gtin)`, delete the supplier's rows not in this set). Batches respect PostgREST uniform-keys and URL-size rules.
- A rebuild failure counts an error and never fails the pull.

### 4. `supplier_best_offers` table (migration, operator-applied)

Columns (money integer pence): `supplier`, `gtin`, `uk_asin`, `title`, `brand`, `cost_pence` (ex VAT), `basis` (`bb`|`new`), `sell30_pence`, `sell90_pence`, `roi30`, `roi90`, `profit_unit_pence`, `profit_month_pence`, `offer_units`, `stock_value_pence`, `gated` (nullable), `supplier_link`, `first_qualified_at`, `updated_at`. PK `(supplier, gtin)`. RLS on; `revoke all from anon, authenticated` then `grant select to anon` + a select policy; `service_role` select/insert/update/delete.

### 5. Buy-box re-mine queue (alchemist-v2)

- After the rebuild on the first pull of each London day: take `basis = 'new'` rows not already queued that day, by profit/month desc, up to `BEST_OFFERS_BUYBOX_CAP` (100), and queue them so the miner fetches with `buybox=1`. Ledger in SQLite meta, as 065's Keepa cap.
- Mechanism to confirm in the ticket: `queueBackfillEans` nulls `last_mined_at` (front of queue) and the miner's `wantsBuybox` already says yes for null-`last_mined_at` rows.

### 6. Dashboard tabs (Alchemist_Dashboard)

- Wholesale page sub-tabs; reads `supplier_best_offers` filtered by supplier (paged; rows are a few thousand at most).
- Client-side filter controls (Q13), default sort profit/month, badges (gated, new < 24 h, drop from today's `qogita_drop_candidates` if anon can read it, else omit and note).
- "Send to pre-screen": insert a one-line `wholesale_prescreen` command named `Qogita offer <GTIN>` through the existing anon commands insert.
- "Block brand": confirm, insert into `qogita_blocked_brands` (normalised as CONTRACTS.md requires), hide rows.

## Build Order

1. alchemist-v2: catalogue load (initial one-off + daily top-up). Start first: mining lead time is weeks.
2. Migration: `supplier_best_offers` (HITL apply).
3. alchemist-v2: signal cache + rebuild + re-mine queue.
4. Alchemist_Dashboard: tabs, filters, actions.
5. CONTRACTS.md: new table (sections 2/3), blocked brands supplier-wide.

## Rejected

- Unknown-ROI rows for unmatched GTINs (Q2a): a guess, and tens of thousands of Postgres rows.
- Relying on the 200/day drop queue to grow coverage (Q2b option c): years.
- Buy-box-only ROI (Q3a): under 1% coverage today.
- A Claude routine doing each eany download (pre-grill discussion): costly per run, non-deterministic, file lands in the cloud not the VPS. Claude is for building and debugging the stage only.

## Open Questions

- Does anon have SELECT on `qogita_drop_candidates`? It is service-role only (064), so the drop badge needs either a grant or a `dropped_today` flag written into `supplier_best_offers` by the rebuild. Decide in the ticket; the flag is simpler.
- Initial load size: how many of the ~200k missing Qogita GTINs pass the stock rule. Measure in the load's dry run.
- DB size impact of the load on the self-host / Pro plan (see `db-self-host-plan` memory).
