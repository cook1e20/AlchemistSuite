type: HITL
kind: coordination

## Parent PRD

`issues/constellation-prd.md`; builds on `issues/spec-wholesale-prescreen.md`. Grill before it gets
tickets.

## Idea (operator, 2026-10-17)

The wholesale scanner "never really flags any winners" on today's price. Wholesale is a slower-turnover
game: if the sales are there, assume the price recovers. Judge lines on a **30/90-day average** (a
"recovery ROI"), the way DealFinder's UK price-recovery alerts already do (sell basis = avg90 - 10%,
DealFinder 048). Operator: the 90-day average ROI data will be valuable on the wholesale scanner.

## What we know

- First live job (NDA-TOys.xlsx, 2026-10-16): 6,557 lines -> 1,624 shortlisted, but only ~180 really
  priced above the floor; 1,444 were unknown (700 no buy box, 744 fees errors - alchemist-v2 bug 051).
  Some of the "no winners" is that bug and the 15% optimistic referral (fixed to 7% in R43, not yet
  deployed), not the pricing basis.
- **The night cut stays on today's price (operator accepts).** SP-API competitive pricing has no
  history, so the overnight stage cannot see an average. The recovery view comes from Keepa data in
  the morning view, after the miner has run the shortlist (issue 050: 1,160 of 1,535 enriched in one
  night).
- `products` has `uk_avg30_price` but **no 90-day average** column. The miner already receives Keepa
  `stats` (avg90 is there), so it is one nullable column + one upsert field (same shape as issue 039,
  `uk_sales_rank_drops30`) + a migration the operator applies. DB is near the free cap (R1) - a few
  bytes a row.

## Questions to grill

1. Basis: avg90, avg30, min(avg30, avg90), or avg90 - 10% (DealFinder's)? Which buy box series?
2. Demand gate for "recovery" winners: minimum `uk_sales_rank_drops30`? Amazon on the listing? FBA
   offer count?
3. Hold time: rank by ROI per month of expected hold rather than raw ROI? Cap on expected hold?
4. Display: "ROI now" beside "recovery ROI" in the morning view, a separate "recovery" label/filter,
   and in the Discord summary?
5. Night cut: today's-price lines cut as `roi_below_floor` never reach Keepa. Accept, or loosen the cut
   (e.g. only drop lines that fail even at a generous multiple) so a crashed price still gets mined?
6. Which repo owns what: alchemist-v2 (column + miner write), Alchemist_Dashboard (morning view ROI),
   CONTRACTS.md section 2 (new `products` column) and section 4 (unit).

## Blocked by

Grill. Nice to have first: alchemist-v2 bug 051 and R43 deployed, so the baseline is honest.
