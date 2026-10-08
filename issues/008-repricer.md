type: HITL
kind: coordination

## Parent PRD

`issues/constellation-prd.md`. This brief becomes the new repo's `issues/prd.md` once
the open questions below are settled (`/write-a-prd` → `/prd-to-issues`).

## Why

The operator's FBA stock is repriced by SellerFuse today, and it is failing them: bugs (it
doesn't pull through competitor data) and no control over how it decides. The
constellation already holds most of what a repricer needs:
- per-SKU cost basis and purchase dates (BuySheet → `analytics_cache.lot_inventory`, issues
  036/037/043);
- SP-API credentials and pricing and fee calls (alchemist-v2 `sp-api.js`, DealFinder's
  `sp-api-client`);
- a VPS with PM2, and a shared Supabase project;
- a dashboard to host the controls.

Start with the repricer and grow towards a SellerFuse replacement.

Operator answers (2026-10-08):
- **Scale:** under 100 active SKUs today; may grow.
- **Floors:** set by **rules**, which can be edited manually.
- **Rollout:** shadow first.

## What it must do (v1)

**Per-SKU pricing from rules, re-evaluated every few minutes.**

1. **Rule sets**, stored in Supabase and edited in the dashboard, assigned to SKUs (with a
   default rule set). A rule set is a time ladder on days in stock. Example from the
   operator:
   - days 0–60: floor = price giving **30% ROI**;
   - day 60+: floor = **15% ROI**;
   - a manually triggered **"sell all"** mode for old stock: floor drops to a
     liquidation level (e.g. break-even, or the lowest offer).

   ROI is computed ex-VAT on both sides (the operator is VAT-registered; same model as
   alchemist-v2 043): BuySheet unit cost against Amazon net proceeds after referral and
   FBA fees (live `getMyFeesEstimate`).

2. **Competition:**
   - Track the other sellers' offers for the ASIN, **not Amazon's own retail offer**.
   - Default strategy: match the lowest comparable competitor (FBA vs FBA; ignore FBM
     unless landed price is lower), never below the floor, never above the max.
   - The max price defaults to e.g. the 90-day high, and can be overridden per SKU.

3. **Write the price** with the Listings Items API `patchListingsItem`
   (`purchasable_offer.our_price`). Only when the change exceeds a minimum step, and with
   a per-SKU change-rate limit so it can't oscillate.

4. **Audit everything:** every decision (inputs, competitor set, floor and why, chosen
   price, written or not) goes to a `repricer_log` table. The dashboard shows the last
   decision per SKU and its history. This is the "control" the operator says SellerFuse
   lacks.

5. **Safety:**
   - It never writes below the floor or above the max.
   - A global `REPRICER_MODE` = `off` | `shadow` | `on`, plus a per-SKU enable flag.
   - A kill switch the dashboard can flip.
   - A missing cost basis or failed fee estimate → no write, logged.
   - Writes are rate-limited per SP-API's granted rates (check the real
     `x-amzn-RateLimit-Limit` headers live, per alchemist-v2 CLAUDE.md).

**Competitor data, given the scale:**
- Poll `getItemOffersBatch` (20 ASINs per request) every 5 minutes. That's enough for
  under 100 SKUs and needs no AWS setup.
- Design the input as an event ("offers changed for ASIN X") so a later phase can swap
  in SP-API Notifications (`ANY_OFFER_CHANGED` → AWS SQS) as stock grows, without
  touching the rules engine.

**Rollout:**
- Shadow: compute and log the price it would set, next to the live price (SellerFuse's),
  for a few days, and compare in the dashboard.
- Then hand over a few chosen SKUs (removed from SellerFuse first, so two repricers never
  fight), then everything.

## Where it lives

A **new sibling repo `Repricer`** (TypeScript, the same starter kit as DealFinder), run
on the VPS under PM2.

- It owns new tables: `repricer_rule_sets`, `repricer_skus` (assignment, overrides,
  mode, sell-all flag), `repricer_log`.
- It reads `analytics_cache.lot_inventory` for cost and days in stock.
- Dashboard work goes to Alchemist_Dashboard: rule editor, SKU table, log view and kill
  switch. That means anon grants and a CONTRACTS.md §3 change.
- It is not part of alchemist-v2 (a catalog feeder) or DealFinder (a buy-side scanner),
  because repricing writes live prices and deserves its own process, kill switch and logs.

## Grill answers (2026-10-08, operator)

- **Amazon on the listing:** a per-rule-set setting. Default:
  - ignore Amazon and target the next FBA seller;
  - if there are no other sellers, and matching Amazon's price is within the rule's ROI
    range, match Amazon;
  - otherwise hold at the floor.
- **Days in stock:** counted from when the units **arrived at FBA** (receive date / FBA
  inventory age), not from the BuySheet purchase date. Mixed-age stock for one SKU: age the
  oldest units first. Confirm the SP-API source in the PRD: the FBA Inventory
  Summaries `inventoryDetails` doesn't carry receive dates, so this probably needs the
  Inventory Ledger or the FBA inventory-age report.
- **"Sell all":** floor = **lowest competitor**, i.e. clear the stock, triggered manually
  per SKU. The global max/kill switch still applies. Open item: whether to keep an
  optional per-SKU "never below £X" safety, given that lowest competitor can be below
  cost.
- **SellerFuse handover:** SellerFuse can exclude individual SKUs, so after shadow, hand
  over SKU by SKU.

## Open questions (still to settle in the PRD)

Questions 1–3 and 6 below are answered above.

1. **"Not with Amazon":** when Amazon retail is on the listing, should we
   - ignore Amazon and price against the other sellers only (we'll rarely win the buy box
     while Amazon is cheaper), or
   - sit just above Amazon's price, or
   - something else?
2. **Days in stock from when:**
   - BuySheet purchase date, or
   - date the units arrived at FBA (inventory age)?

   With mixed lots of one SKU, which lot's age counts (oldest units first)?
3. **"Sell all" floor:** break-even, a fixed ROI (e.g. 0% or −10%), or the lowest
   competitor regardless? Should it switch on automatically after N days, or only
   manually?
4. **Max price default:**
   - 90-day high or average,
   - the price at purchase, or
   - manual only?
5. **Buy box vs lowest price:** match the buy-box winner or the lowest FBA offer? Allow
   1p under, or match exactly?
6. **SellerFuse handover:** does SellerFuse let us exclude individual SKUs, so shadow and
   phased handover work SKU by SKU?
7. **FBM:** any FBM listings to reprice, or FBA only?

## Acceptance criteria (for this coordination issue)

- [ ] Grill held; answers recorded here.
- [ ] `Repricer` repo created from the starter kit, `issues/prd.md` written, and first
      issues split (tracer bullet: one SKU, shadow mode, log only).
- [ ] CONTRACTS.md updated for the new tables and their grants (§1–§3).
- [ ] RUNLIST entry for each phase.

## Blocked by

Nothing hard. Rules need cost basis and days in stock, so alchemist-v2 043 (and running
`analytics` daily) should land first or alongside; shadow mode can start without it on
manual costs.
