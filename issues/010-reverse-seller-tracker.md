type: HITL
kind: coordination

## Parent PRD

`issues/constellation-prd.md`. Backlog idea, not yet scoped. Grill it before it gets an owning
repo or a build slot.

## Idea (operator, 2026-10-14)

Reverse seller tracking, as several paid tools do. Pick a handful of successful arbitrage
sellers, poll their storefronts once or twice a day, and alert on ASINs they have **newly
listed**. A new listing from a seller who buys well is a lead: if we're quick, the source
deal they used may still be live.

Extension: use SP-API to tell **fresh stock** from old. If a seller's offer shows next-day
delivery, the stock has probably been there a while. If it shows 3, 5 or 7 days, it may have
just been shipped in, which marks it as a new buy.

## What the data sources probably give us (to verify in a spike, not trusted yet)

- **Keepa `/seller` with `storefront=1`** returns the seller's ASIN list and, per ASIN, when
  Keepa first and last saw it listed (`asinList` / `asinListLastSeen`). Diffing two polls gives
  "new since yesterday" directly. Token cost per seller and per storefront refresh needs
  checking against current Keepa pricing. The storefront is refreshed by Keepa on its own
  schedule, not live, so a daily poll may lag a day.
- **Keepa product `offers`** gives per-offer seller ID, FBA flag and stock history, but it's
  expensive per product. Use it only to enrich a new-listing hit, not to discover hits.
- **SP-API `getItemOffers`** returns up to ~20 offers per ASIN with seller ID, FBA flag and
  `ShippingTime` (min/max hours plus an availability type: now, future with date, future
  without date). **Unverified:** whether an FBA offer's shipping time really reflects stock
  that is inbound or in a distant fulfilment centre, rather than being near-constant for FBA.
  Many FBA offers only appear once stock is received, so "3–7 days" may mostly flag FBM
  sellers or Amazon's own distribution delays, not fresh inbound. Treat this as a hypothesis
  and test it on known recent listings. This operation is the offers allowance (the same one
  as DealFinder's offers batch), not the competitivePrice/fees split in ADR 0001, but the
  slow rate (~0.1 req/s live) caps how many ASINs we can check a day.

## Fit with the constellation

- A new-listing hit is an ASIN with no source. It wants the same treatment as a DealFinder
  candidate: velocity check, then ROI against a source price we still have to find. The source
  hunt is the hard part: Google / SourceWatch (issue 009) / KeepaCompanion's search button.
- Likely home: DealFinder (it already owns Keepa feed polling, SP-API offers and Discord alerts),
  or a small new stage there. Shares the Keepa token budget, so it needs a fixed daily token
  allowance that doesn't starve DealFinder or the miner (CONTRACTS.md token split).

## Open questions (for the grill)

1. Which sellers, and how many? Who picks them (operator list in an env/table, or auto-found from
   sellers who keep winning the buy box on our good ASINs)?
2. Poll cadence: once or twice a day, and is Keepa's storefront refresh frequent enough to make
   twice worthwhile?
3. Token budget per day, and where it comes from (DealFinder's daytime share, the miner's night
   share, or a bigger Keepa plan; R36 is the Keepa plan decision).
4. What does an alert contain: ASIN, title, BSR/velocity, the seller, current buy box, how many
   tracked sellers listed it (two tracked sellers listing the same ASIN in a day is a strong
   signal)?
5. Filters before alerting: velocity floor, price band, gating (`gating_status`), already in
   our stock or already alerted by DealFinder?
6. The fresh-stock signal: is it worth building before the spike proves `ShippingTime` means
   anything for FBA offers?
7. Storage: a small `seller_watch` table plus a per-seller "seen ASINs" set, and the DB is near
   its 500 MB cap (R1), so keep it tiny and purge.

## Suggested first step

A spike, operator-run and token-budgeted: take 3–5 sellers, pull storefronts on two consecutive
days, diff them, and for the new ASINs call `getItemOffers` and record each tracked seller's
`ShippingTime`. That answers token cost, hit rate and whether the fresh-stock signal is real
before anything is built.
