# Spec: Qogita drops as a DealFinder feed (draft 2026-11-06)

Follow-on to R53 (`spec-qogita-price-drops.md`, alchemist-v2 062-065). Reverses that spec's Q18/Q19 for the instant alert:
a Qogita price drop is treated as a deal candidate and goes through DealFinder's own pipeline (ASIN, free SP-API
pre-screen, Keepa, `evaluateDeal`, gating, Amazon-on-listing, DealFinder card), instead of an estimate from stored
`products` data.

## Problem Statement

The 064 alerts estimate ROI and gating from `products` only. On 2026-11-06, of 109 matched drops only 12 had a
buy-box average and 2 a cached gating result, so nearly every alert read "ROI n/a / gating not checked". ~80% of
drops (unmatched GTINs) never get an alert at all. DealFinder already does the full check for Keepa deals.

## Decisions (operator 2026-11-06)

| # | Decision |
|---|---|
| D1 | Qogita drops become a DealFinder deals feed and go through DealFinder logic. |
| D2 | Volume is controlled by DealFinder's existing free SP-API ROI pre-screen (issue 041), run before any Keepa token, not by a hard cap. A safety cap per tick still applies (see 3). |
| D3 | Keep both alchemist-v2 064 (hourly estimate alerts) and 065 (19:50 night pre-screen) running during a trial. Decide on retiring them afterwards. Expect two pings for some drops. |
| D4 | Pass rule: the trigger is the Qogita drop (alchemist-v2's rule: >= 10% below its 30-day average, enough stock, not a pre-order, brand not blocked). Sell basis = the UK **buy-box 30- and 90-day averages**, never the current Amazon buy box (a temporarily depressed Amazon price must not sink a deal). ROI at both; the lower must be **>= 20%** on the gross cash cost (conservative, as 064's profit figure and best-offers Q3). Velocity floor as the UK market. No Amazon-below-avg90 guard. |
| D3 update | 2026-11-10 (spec-business-loop Q34, ADR 0005): no double-ping trial. 067 runs in shadow a few days, then 064's alerts switch off the day 067 starts posting. |
| D5 | Posts to the wholesale channel (`DISCORD_QOGITA_WEBHOOK`, `#wholesale`). |

## Scope boundary

Two separate things, kept separate:
- **This spec:** the alert feed. Qogita drop -> stock check (alchemist-v2) -> DealFinder logic -> card in `#wholesale`.
- **`spec-supplier-best-offers.md`:** the dashboard Wholesale tab listing every currently profitable Qogita item
  (not just drops), Part A Qogita, Part B eany.io.

## Solution

### 1. Producer (alchemist-v2): no change

`qogita_drop_candidates` already holds every drop (matched and unmatched) per UK day: gtin, uk_asin (matched),
baseline/current pence (ex VAT), drop %, offer stock, found_at. DealFinder reads it. It needs two more columns for a
standalone deal: `name`, `brand`, `link` (Qogita product link). Migration + 064 write change.

### 2. Consumer (DealFinder): Qogita source

- Poll `qogita_drop_candidates` for rows not yet evaluated (own state: a `dealfinder_evaluated_at` column, or a
  DealFinder-owned ledger table; decide in the ticket. A column on an alchemist-v2 table is a contract change).
- Run inside DealFinder's day window (08:00-20:00 UK), the same as its SP-API pre-screen (ADR 0001). Keepa from
  DealFinder's day budget (CONTRACTS.md section 5).
- Per candidate:
  1. ASIN: `uk_asin` when matched, else SP-API catalogue lookup by GTIN (the Zappies issue 061 path, shared).
     No ASIN = skip, logged.
  2. Free SP-API pricing + fees -> `spApiPreScreen` with a GBP ex-VAT cost. A confident reject stops here
     (no Keepa). Because D4 sells on the averages, not the live buy box, the pre-screen's sell price must be an
     upper bound: max(live buy box, stored `products` buy-box avg30/avg90 when present). With no stored average a
     low live buy box is not a confident reject: pass it to Keepa (operator 2026-11-06). This is a short-term
     cost: Qogita's range is fairly static, so once `products` holds averages for it (best-offers catalogue load
     + buy-box re-mine, and step 3's write-back below) the pre-screen rejects on real averages.
  3. Keepa UK `/product` with buy-box stats (avg30/avg90, drops30, monthly sold, FBA offers, image).
     Write `uk_buybox_avg30_pence` / `uk_buybox_avg90_pence` back to the `products` row (DealFinder's
     `products-upsert` does not write them today), so each Qogita item costs Keepa tokens once and the next
     drop on it is pre-screened on real averages.
  4. `evaluateDeal` with a wholesale GBP source: cost = Qogita price ex VAT, gross cash cost x1.2, reclaim x0.2
     (`VAT_REGISTERED=true`; the Zappies 062 treatment, not the consumer-price one the UK->UK path uses).
     Sell basis and floor per D4. No `ukRecoveryGuardFailures`.
  5. Gating + Amazon-on-listing as now (labels, not filters, issue 036/041).
  6. Pass -> DealFinder card (image, badge, velocity, links incl. Qogita), footer `DealFinder · Qogita`,
     to `DISCORD_QOGITA_WEBHOOK` (or a new channel: operator to say).
- Dedup: once per GTIN per UK day, again only on a further 10% drop (same as 064's alert_posts rule).
- Stats in DealFinder's run log: drops read, no-ASIN, pre-screen rejects, Keepa tokens, passes, posted.

### 3. Shared with Zappies (DealFinder 059-064, not built)

061 (EAN->ASIN catalogue lookup) and 062 (wholesale GBP evaluation) are the same machinery. Build them once as a
"supplier offer" source; Qogita is the first consumer, Zappies the second.

## Open questions

- Q2 (settled 2026-11-06): Keepa cap 200/day for this source (biggest drops first, the rest roll to
  the next tick) while `products` fills; revisit once survivor counts are known.

## Tickets (RUNLIST R56)

- alchemist-v2 075: name/brand/link on `qogita_drop_candidates`
- DealFinder 065: wholesale supplier evaluation (shared with Zappies 062)
- DealFinder 066: buy-box averages write-back to `products` (narrow writer for the feed)
- DealFinder 067: Qogita feed (poller, pre-screen shadow, 200/day Keepa cap, card, dedup; dark)

## Build order

1. Migration: `name`/`brand`/`link` on `qogita_drop_candidates`; consumer state. alchemist-v2 064 writes the new columns.
2. DealFinder: supplier-offer source pieces (061 catalogue lookup, 062 wholesale evaluation), generic.
3. DealFinder: Qogita poller + notifier variant, behind `QOGITA_FEED_ENABLED` (dark).
4. CONTRACTS.md: DealFinder reads `qogita_drop_candidates` (section 2), Keepa day budget share (section 5).
5. Trial, then decide on 064/065 (D3).
