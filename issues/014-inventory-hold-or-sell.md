type: HITL
kind: coordination

## Parent PRD

`issues/constellation-prd.md`. Owners: `alchemist-v2` (data, issue 059) and
`Alchemist_Dashboard` (display, issue 026). Related: `issues/008-repricer.md` (the Reprice
verdict is a repricer input), `alchemist-v2/issues/043-realised-net-roi-per-lot.md`.

## Why

The operator wants to see what is sitting in Amazon and decide, per item, whether it is a
**bad buy to clear** or a **valid buy to work** (hold, reprice). Asked 2026-10-23:

> a way to know what is in amazon, how long its been there, my current price, the buy box
> current price, the 30 day and 90 day price, and the last sale made ... determine bad buys
> vs buys that are still valid and i need to work on.

## State at filing (2026-10-23, live read)

- `analytics_cache` latest row is **2026-07-21** (2 rows ever): 241 ASINs, 31 with units.
  The `analytics` stage is manual-dispatch only.
- `lot_inventory` holds **0 lots**: no BuySheet row carries a Seller SKU in that snapshot.
- Of the 31 held ASINs, 28 are in `products`; **0** have `uk_buybox_avg90_pence` (the miner
  only does `buybox=1` lookups for velocity rows, alchemist-v2 054).
- `sp-api.js` has `getCompetitivePricing` (buy box now). Nothing fetches my price,
  inventory age or last sale date.

## Operator decisions (2026-10-23)

1. **Freshness:** the `analytics` stage runs **daily** on the scheduler (no longer manual only).
2. **Cohorts: line in the sand.** Stock in FBA at the baseline (the first daily run after
   deploy) is the **legacy** cohort: per ASIN, BuySheet blended cost, age from Amazon's own
   inventory-age data. Purchases from then on are tracked **per Seller SKU** (lot), cost and
   purchase date from the BuySheet. No retrofit of legacy rows to SKUs.
3. **Sell means sell.** When the verdict is a bad buy, the advice is to **clear it at the price
   that sells now**, not to hold out for break-even. The original analysis was wrong; sitting on
   the stock to claw back cost ties up capital and storage and is itself a bad decision.
4. **Suggested price:** yes, every row carries one, with the projected profit/loss at it.

## Verdict rules (v1)

Break-even = the sale price whose proceeds after referral fee, FBA fee and VAT equal the unit
cost. Reuse the dashboard's existing fee/VAT maths (Dashboard 023's corrected basis), not new
maths.

| Verdict | Condition | Suggested price |
|---|---|---|
| **Sell now** | buy box now < break-even **and** BB avg90 < break-even | price that sells now: buy box now, else lowest FBA offer |
| **Hold** | buy box now < break-even, BB avg90 ≥ break-even | BB avg90 (the recovery target) |
| **Reprice** | my price > buy box now, buy box now ≥ break-even | buy box now |
| **Healthy** | my price ≤ buy box now (or within 1p), ≥ break-even | my price |
| **No data** | any input missing | none; never defaults to Hold |

**Amazon on the listing (operator, 2026-10-23):** "is Amazon dominating it right now, and is it
still worth holding". Measured from the same Keepa `buybox=1` lookup 059 already adds (no extra
tokens): Amazon's 90-day buy-box share (`stats.buyBoxStats`, Amazon UK seller id), Amazon's
90-day out-of-stock % (`stats.outOfStockPercentage90[0]`), Amazon's price now and avg90 (csv 0).
Field names to verify against a live Keepa response. Applied before the table above:

- **Amazon dominant** = buy-box share ≥ 80% (default) **and** out of stock < 10% of 90 days.
  Dominant with Amazon's price below break-even → **Sell now** (Amazon rarely leaves; the BB avg90
  is Amazon's price, not a recovery). Dominant with Amazon's price ≥ break-even → normal rules, but
  suggested price is Amazon's price (you share the buy box at best).
- **Amazon present, not dominant** (goes out of stock often) → a Hold is genuine: the price
  recovers in Amazon's gaps. Show "Amazon OOS x% of 90d" beside the verdict.
- No Amazon offer → normal rules.

Thresholds are starting values to tune once real rows are visible.

Flags beside the verdict: **Amazon dominant** / **Amazon on listing**, **Aged** (>90 days; >180 days when Amazon's aged-inventory surcharge
applies) and **No sale in 30/90 days**.

## Holds and velocity (operator, 2026-10-23)

- **Holds never expire; they are re-measured daily.** If the price stays low, the BB avg30/avg90
  fall with it and the verdict flips to Sell now by itself. No time-based override; Aged alone
  never forces Sell now (it stays a flag).
- **Velocity columns**, because averages track price, not whether units move:
  - **My sales 30d / 90d:** units shipped (planning report `units-shipped-t30/t90`).
  - **Market velocity:** `products.monthly_sold` (Amazon badge, often null) and
    `uk_sales_rank_drops30` (always the fallback).
  - **Months to clear** = units held / my monthly sales (30d rate, else 90d / 3); "no sales"
    when both are 0.
- **Flags only, no verdict change:** **Slow** when months to clear > 6 (the stock would reach
  Amazon's aged-inventory surcharge before it sells), **Stalled** when the market moves
  (drops30 ≥ 3) but I've sold nothing in 90 days (probably not winning the buy box: check price).

## Open

- `analytics_cache` grows one row a day once cron'd. DB is near the free cap (R1/R50):
  retention (e.g. 30 days) in housekeeping.
