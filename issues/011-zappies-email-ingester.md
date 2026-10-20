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

## Answered (operator, 2026-10-20)

1. **Buy price:** yes, each product carries one in the email. It is the ROI cost basis.
2. **Gmail access:** Gmail API on the jurassicdesignlabs@gmail.com account, polled hourly
   during business hours (exact window still to pin: days and hours, UK time).

## Sample findings (2026-10-20, read via the Gmail connector)

- ~200 emails, all from `chris@zappies.com`, typically several a day. Subjects follow
  `<In Stock|Incoming> [*flag*] - <product or "Lines xN"> - Zappies`; `xN` gives the product
  count for multi-product emails.
- **The plain-text part is just `.`; all content is in the HTML part.** Images are inline
  attachments (emails are 1–8 MB), so fetch `format=full` and only read the `text/html` part.
- Outlook-generated HTML, one block per product, in order:
  image → Amazon link → "(links & images are for reference only)" →
  `Price: £X   Case Qty: N` → `SKU: <zappies sku> [EAN/GTIN]`.
  The EAN, when present, follows the SKU on the same line (13 digits, sometimes a 14-digit
  GTIN with a leading 0). "Sku"/"SKU" casing varies.
- Some emails put the stock or price in the header text instead ("x144 @ £4.31",
  "x306 Units Take All £6.50", "79 Units", "1 Case Only").
- Not every email from that sender is a deal list: e.g. "Pokémon New Release" is a personal
  note to the operator. Skip emails that contain no `Price:` block.
- "In Stock" vs "Incoming" is in the subject; the operator labels some Incoming emails in Gmail.
- Amazon links carry tracking/search params and slugs; the ASIN is the `/dp/<ASIN>` segment.
  Zappies says links are "for reference only", so a link can point to the wrong variant. Where
  both a link and an EAN are present, cross-check them.

3. **Parsing:** the HTML structure is regular enough for a deterministic parser: convert the
   HTML to text, split it into product blocks on the Amazon link or on `Price:`, then regex
   out the ASIN, price, case qty, SKU and EAN. No LLM step is needed for v1. Save a handful
   of these emails as fixtures, including the header-price variant and a non-deal email.

4. **Pricing (operator, 2026-10-20):** use the same basis as the wholesale recovery view
   (issue 012 / R47): sell price = **buy-box 30/90-day average** (Keepa `stats.avg30[18]` /
   `stats.avg90[18]`), not today's price. Fees are re-derived at the average. Velocity comes
   from Keepa (rank drops/30d, the demand figure from issue 012). Keepa is fine for this:
   ~10–15 products a day (operator, from memory) is a negligible share of the shared budget
   (R36). The EAN → ASIN step stays on SP-API catalog (free, alchemist-v2 045).
5. **Dedup (operator, 2026-10-20):** one row per email product, keyed on ASIN plus buy price.
   A repeat with the same ASIN only alerts again when the price drops.

6. **Alert filters (operator, 2026-10-20):**
   - Alert when ROI ≥ 30% at the recovery basis (buy-box avg90 − 10%, as DealFinder 048).
     Only the 90-day ROI gates the alert.
   - The alert line shows ROI now, ROI at avg30 and ROI at avg90.
   - Demand gate: DealFinder's rank-drops/30d floor.
   - Gating status is shown on the alert, not filtered.
   - **No category exclusions**: the feed is all toys.
   - The alert shows MOQ cost (price × case qty).

Poll window: Mon–Fri 08:00–18:00 UK, hourly (proposed 2026-10-20, operator did not object;
emails seen so far arrive between about 08:30 and 16:00).

## Grill status

Complete 2026-10-20. **Owning repo: DealFinder** (decided 2026-10-20). It is not Keepa-only:
it already has `sp-api-client`, `keepa-client` product queries, `deal-economics` (fees, VAT,
ROI), `deal-store` and `notifier`, which is everything after "parse the email". A separate repo
would have to copy those, because the constellation has no shared package. The ingester is a
new module (e.g. `src/email-source/`) with its own entry point and its own PM2 app in
`ecosystem.config.cjs`, so it runs and restarts independently of the Keepa probe. The Gmail
OAuth secret lives only in that app's env. Next: write the tickets:
Gmail API OAuth + hourly poller, HTML parser with fixtures, EAN → ASIN via SP-API, Keepa
pricing at avg30/avg90, dedup table, Discord alert.

## Open questions

None.

### Original Q4–Q6 wording

4. Pricing source: SP-API (free, ADR 0001 window) vs Keepa tokens (shared budget, R36).
5. Dedup: the same ASIN across emails/days, and against DealFinder alerts already sent.
6. Alert format and filters: velocity floor, ROI floor, gating (`gating_status`), apparel
   exclusion.

## Suggested first step

Collect sample emails and count products per email and the split of link / EAN / SKU-only, to
size the hit rate before building.
