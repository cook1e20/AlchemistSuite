type: HITL
kind: coordination

## Parent PRD

`issues/constellation-prd.md`. Backlog idea, not yet scoped. Grill it before it gets an owning
repo or a build slot.

## Idea (operator, 2026-10-16)

Zappies deal emails arrive in the operator's Gmail. Ingest them, pull out the products, price
them through a DealFinder-style pipeline and ping Discord when one is a deal.

## What the emails contain (operator)

- Mixed per product: sometimes an EAN, sometimes an Amazon link, sometimes only a Zappies SKU.
- **Several products per email.**

## Extraction rule (operator)

Per product in an email:

1. A web link that decodes to an ASIN (amazon.co.uk `/dp/`, `/gp/product/`, short links if they
   resolve) → run the ASIN.
2. Otherwise an EAN → run the EAN (EAN → ASIN lookup first).
3. Neither (Zappies SKU only) → skip, but count it so the skip rate is visible.

## Fit with the constellation

- Same shape as DealFinder's funnel: candidate ASIN → velocity → ROI → Discord. The buy price
  comes from the email (if present), not a Keepa source market, so it needs its own sell/buy
  basis, as UK→UK did (DealFinder 048).
- The EAN path resembles the wholesale pre-screen's catalog stage (alchemist-v2 045):
  barcode → ASINs via SP-API, no Keepa tokens.
- Likely home: DealFinder (owns Discord alerts and the deal evaluator), or a small stage there.

## Open questions (for the grill)

1. Does each product carry a buy price in the email? If not, what is the ROI cost basis?
2. Gmail access: Gmail API with OAuth on the VPS, a filter + label, or a forwarding address?
   How often to poll?
3. Parsing: HTML structure stable enough for a parser, or does it need an LLM extraction step?
   Need 5–10 sample emails as fixtures.
4. Pricing source: SP-API (free, ADR 0001 window) vs Keepa tokens (shared budget, R36).
5. Dedup: the same ASIN across emails/days, and against DealFinder alerts already sent.
6. Alert format and filters: velocity floor, ROI floor, gating (`gating_status`), apparel
   exclusion.

## Suggested first step

Collect sample emails and count products per email and the split of link / EAN / SKU-only, to
size the hit rate before building.
