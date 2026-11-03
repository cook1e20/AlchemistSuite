# Spec: Qogita price drops (grilled 2026-11-03)

Drafted 2026-10-30 from FBA Mogul's "Qogita Scout" preview (stream of the same date, transcript in `docs/research/2026-10-30-fba-mogul-qogita-scout-transcript.txt`, timestamps below refer to it). The transcript is from audio only, so anything he showed on screen and did not say is missing, and spoken numbers may be mis-transcribed. Concepts are taken from the talk; nothing is copied from his product.

Grilled 2026-11-03 (decisions Q1-Q20 below), with live probes of the Qogita API the same day. This is the parked "Job 1" from RUNLIST G4. Ready for tickets.

## Problem Statement

Qogita deals appear as price drops, and the good ones go within hours. Wholesale Search shows what is profitable at today's prices, on demand. Nothing shows what has just changed, and nothing tells me unprompted. Q4 is the best time for this: he expects perfume to peak around 10-15 December (18:31). I also want to use Qogita's marketplace invoices to get ungated on brands.

## What his tool does

| Concept | Timestamp | Notes |
|---|---|---|
| Every Qogita product matched to its Amazon listing | 09:49 | |
| Price-drop feed: was/now, % drop, profit, ROI | 09:56 | |
| Filters: profitable only, min profit, drop window (24h/7d), min drop %, min monthly sales | 10:12 | Slow on his build |
| Defaults: market-based invoice only, Amazon-matched only | 10:50 | "We only buy with market-based invoices" (29:56) |
| Sort by sales per month | 11:03 | |
| Hover chart in the Keepa style: price and sales | 11:25 | |
| Warnings: brand on listing, parallel import risk | 12:45 | His AI warning was wrong live (23:50) |
| Blocked-brand filter | 15:30 | Not working on stream, his top fix (31:13) |
| Christmas profit: this product's profit at each of the last 3 Christmases | 16:13, 17:58 | Not shipped yet |
| Minimum quantity or minimum order value (planned) | 17:21 | His biggest live pain: the cheapest seller has 1-3 units |
| AI overlay reading price charts (planned) | 20:21 | |
| AI check on every match | 35:26 | Costs him 8 AI plans; not worth copying |
| Delivery: site, Discord pings, CSV, MCP | 30:50 | |

## His sourcing rules, worth encoding

- Value a listing by profit per month, not per unit (01:04:15). Take about 10% of a listing's sales as your share (42:40).
- 15% ROI is fine on fast, low-return lines such as perfume. Sometimes 10%. Not on slow lines (42:02, 43:00).
- Use a "realistic low" price, not the current price, for the worst case (21:29).
- Treat a brand on the listing as extreme caution (32:03). Parallel-import complaints are survivable with a Qogita invoice (26:34).
- Card fee is about 2%; bank transfer avoids it (39:13).
- Carts of £5k or more: ask the account manager for a supplier discount. He got 5% (46:39-48:22).
- Good offer but thin stock: take the seller's catalogue and build up to their minimum (27:44).
- Qogita prices are ex VAT: he multiplies by 1.2 (12:14).

## Facts established 2026-11-03

- **The invoice filter reaches the API.** Qogita's Profile setting "Only show products with marketplace invoices available" filters the catalogue download. Same hour, setting on vs off: 247,834 vs 465,639 products; 247,670 in both. Of those, the price was the same for 67%, and higher in the invoice-only file for 33% (82,506; median +13.2%, p90 +54.6%). The categories with the most products missing from the invoice-only file: Eau De Parfum 9,648, Hair Dye 5,763, Shampoo 5,688, Hair Coloring 4,660, Eau De Toilette 4,315. Files are kept on the VPS at `/root/qogita-snapshots/`.
- **It is an account setting, not a request parameter.** One account cannot pull both versions on a schedule. The CSV has no invoice column; the filter just drops rows.
- **The catalogue has grown:** 333,511 rows in July, 465,639 today with no filter.
- **Qogita builds on request and caches the result.** A file built at 13:01 was served again at 13:17. A request at 14:22 got a new file built 21 s later. So the cache lasts between 16 and 81 minutes: hourly pulls get fresh data. The cached file comes back under the new request's id (same `filename`, old `completed_at`), so "new data" means a new filename, not a new request id. The July "two requests 30 minutes apart got the same file" was this cache.
- **The Qogita token dies in under 20 minutes**, but `qogita-api.js` caches it for 50. A long-lived caller gets 401s. Logged as alchemist-v2 061 (major); it must land first.
- **VPS:** 48 GB disk, 34 GB free, 3.8 GB RAM, no swap. The pull must stream (issue 022's OOM lesson).
- **`service_role` has no INSERT on `wholesale_sync_requests`** (only SELECT/UPDATE). The webhook matches rows by `catalog_request_id`.
- **The DB is full:** 497 of 500 MB on 2026-11-03, growing about 5 MB/day (`products` 354 MB, `deals` 94 MB).
- **Qogita on ungating:** it claims an 80-90% success rate, with no guarantee. Request a marketplace invoice per order (order page: "request marketplace invoice", reason "ungating"). You get a supplier self-billing invoice and a Chain of Supply letter.

## Decisions (grill 2026-11-03)

| # | Decision |
|---|---|
| Q1 | Supabase Pro now as a bridge; home server in January (R50). |
| Q2/Q15 | Do not keep hourly full copies. Keep one full gzipped copy a day for 30 days, for recovery only. Keep price history as a change log (Q17). |
| Q3 | Drop = today vs the 30-day average from the summary. Until 7 days of history exist, compare with the previous pull. Revisit the baseline after 2 weeks of data. |
| Q4 | Thresholds (settings): drop >= 10%; cheapest offer has >= 5 units or >= £500 stock value; not a pre-order. |
| Q5 | Blocked brands: a small table edited from the dashboard. |
| Q6 | For this Q4: slices 1-5 below. The view and the Christmas lens come in January. |
| Q7/Q16 | A drop goes straight through a deal check, then to a new Qogita Discord channel. |
| Q8 | The "no scheduled wholesale downloads" rule (alchemist-v2 done/003) is relaxed for this one Qogita pull only, behind its own on/off switch. Every other wholesale automation stays removed. |
| Q9 | The 015 "no Qogita catalogue table" ruling is about Postgres. Files and SQLite on the VPS are allowed. CONTRACTS.md:426 gets this wording. |
| Q10/Q13 | Invoice use: (a) buying filter and (b) ungating finder, both. |
| Q11 | No permission email. Operator accepts the terms risk (2026-11-03): 24 pulls/day is far under the known 3/min limit. If Qogita objects, switch the pull off. |
| Q12/Q14 | The invoice setting stays ON permanently. Every price we store is the cheapest offer with an invoice. The dashboard's manual Qogita sync becomes invoice-only too (accepted). |
| Q17 | The change log and summary live in SQLite on the VPS, owned by alchemist-v2. Only candidates go into Postgres. They move to Postgres with the home server. |
| Q18 | Two steps. An instant ping with ROI estimated from `products` (Keepa 30/90-day buy box, referral %, FBA fee). The full SP-API price comes that night. |
| Q19 | A drop with no `products` row is queued for Keepa backfill overnight, at most 200 a day, biggest drops first. It is posted the next day. |
| Q20 | alchemist-v2 owns all of it: pull, history, check and Discord. |
| VAT | Every cost shown to me is inc VAT (ex x 1.2), labelled. ROI already uses gross cash cost (`grossCashCostPence`). Display fix is Dashboard 027. |

## Solution

### 1. Hourly pull (alchemist-v2)

- A new cron entry pulls the catalogue every hour, with its own kill switch (`QOGITA_DROPS_ENABLED`, default off).
- It needs a request row the stage can create:
  - Either add an INSERT grant for `service_role` on `wholesale_sync_requests` (Dashboard migration).
  - Or give the pull its own bookkeeping. Pick at ticket time.
- If the result's `filename` matches the last one processed, it is a cached file. Stop.
- Otherwise stream the CSV. Never buffer it.
- The first pull after midnight also writes the day's gzipped copy to `/root/qogita-snapshots/`. Copies older than 30 days are deleted.
- The pull does not touch `wholesale-catalogs/latest.csv.gz`, so dashboard syncs are unaffected.

### 2. History (SQLite on the VPS)

- `price_changes(gtin, at, price_pence, offer_stock, offers, total_stock)`. Write a row only when the price or offer stock changed from the last row for that GTIN.
- `price_summary(gtin, name, brand, category, current_pence, avg30_pence, avg90_pence, low30_pence, dec_median_pence, last_change_at)`.
  - `current_pence` updates on each pull.
  - The averages are rebuilt nightly from `price_changes`, time-weighted (a price holds until the next change).
  - `dec_median_pence` is the median from 1-24 December of the most recent December recorded. It is null until December 2026 is in.
- Prices are integer pence ex VAT, as Qogita gives them (CONTRACTS.md section 4: convert the GBP decimal at the boundary).

### 3. Drop detection and the instant check

A GTIN is a candidate when all of these hold:
- `current_pence` <= the baseline (Q3) x (1 - drop %)
- the stock minimum holds
- it is not a pre-order
- its brand is not blocked

Each candidate is costed straight away from `products`, matched by GTIN-13 like Wholesale Search:
- estimated ROI at the 30-day and 90-day buy box, on gross cash cost
- estimated profit per month = profit per unit x (monthly sales x 10%), capped at offer stock

The Discord post (Qogita channel) shows:
- product and brand
- was/now inc VAT, and % drop
- offer stock
- estimated ROI 30/90
- est. profit per month
- gating status, if cached
- links to Qogita and Amazon

A GTIN is posted at most once a day. If it drops a further 10% or more after that, post it again.

Candidates with no `products` row go to the Keepa queue (Q19, cap 200/day) and are posted the day they are matched.

### 4. Night confirmation (existing pipeline)

- Before the SP-API window opens (default 20:00), the day's candidates go in as one `wholesale_prescreen` job with `vat_basis: ex`.
- That job reuses ASIN lookup, BSR cut, pricing, fees, ROI, gating, Keepa queueing, the Discord summary and the 14-day purge.
- The job's summary posts to the Qogita channel.
- The existing 10k-line cap applies: biggest drops first.

### 5. Ungating finder

- Daily, from `price_summary`. Brands that `gating_status` says I am gated on, and that have products with offer stock >= 10.
- Ranked by the cheapest cost to buy 10 units of one product inc VAT. Show that product's estimated ROI, so I can see when an unlock is cheap or even profitable.
- One daily Discord digest, top 20.
- `gating_status` covers checked ASINs only. A brand with no checked ASIN is listed as "gating unknown".

### Blocked brands

- A small Postgres table, `qogita_blocked_brands(brand, note, created_at)`, edited from the dashboard.
- It needs a migration with anon SELECT/INSERT/DELETE grants and policies. That is a contract change, so CONTRACTS.md section 3 is updated.
- alchemist-v2 reads it with service_role (explicit grant).

## Build Order

1. **Operator:** Supabase Pro (Q1).
2. alchemist-v2 061: Qogita token 401 retry. Blocks everything that polls.
3. Hourly pull plus the daily copy (slice 1). Switch it on as soon as it lands. History cannot be backfilled, so this goes first.
4. SQLite change log and summary (slice 2).
5. Drop detection, instant check and Qogita channel (slice 3), plus the blocked-brand table.
6. Night confirmation (slice 4) and the Q19 Keepa queue.
7. Ungating finder (slice 5).
8. Dashboard 027 (inc-VAT display) can land any time.

January: Price Drops view on Wholesale Search, the Christmas lens from `dec_median_pence`, realistic low, and moving SQLite into Postgres on the home server.

## Later slices

- **Price Drops view** on Wholesale Search, with the same columns as the Discord post plus filters. Default sort: est. profit per month.
- **Christmas lens.** Use `dec_median_pence` once December 2026 is recorded. For this Q4, check Keepa by hand on shortlisted ASINs.
- **Realistic low.** A low-percentile buy box over 90 days, with ROI shown at that price.
- **Brand on listing.** From `getItemOffersBatch`, already used by stock health.
- **Card-fee toggle.** Adds 2% to cost when paying by card.
- **Per-offer invoice data**, if Qogita's reply to the email offers it.

## Rejected

- AI check on every match: a GTIN match is cheap and the multi-ASIN handling already exists.
- MCP access, CSV export of the feed, accounts and subscriptions: single-user tool.
- Hourly full snapshots kept for 400 days: about 130 GB. The change log keeps the same detail.
- Pulling both catalogues (invoice on and off): the filter is an account setting, so it cannot be done on a schedule. The invoice-only prices are the ones I buy at.
- Moving the whole DB to SQLite: the browser apps need PostgREST, RLS and Edge Functions, and SQLite cannot be shared across hosts.
- Putting the catalogue summary in Postgres now: the DB is full and the 015 ruling holds for Postgres.
- DealFinder owning the check: its model converts EU prices to UK landed costs; the ex-VAT UK ROI is already in alchemist-v2.

## Open Questions

1. Is there per-offer invoice data (seller, invoice type)? Not asked; ask if it becomes worth having.
2. Is the 30-day time-weighted average a good baseline, given the cheapest invoice offer flips between sellers? Revisit after 2 weeks (Q3).
3. How should the pull create its bookkeeping row: a `service_role` INSERT grant on `wholesale_sync_requests`, or its own row? (Ticket-time call.)
