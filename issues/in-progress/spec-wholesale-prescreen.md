# Spec: Wholesale pre-screen

Grilled 2026-10-09 (Q1–Q16, all accepted as recommended). Vocabulary is in `GLOSSARY.md`, and the SP-API window decision is in `docs/adr/0001-sp-api-pricing-window-split.md`.

## Problem Statement

I've cancelled my sourcing-scanner subscriptions (ArbiSource and similar) and now source from supplier stock lists such as Bliss's 3,077-line list of TCG accessories. Alchemist's Wholesale Search only matches barcodes against the existing catalogue. For a new supplier most lines aren't there: 2,144 of Bliss's 2,676 barcodes weren't. Those lines are sent to the overnight Keepa miner blind, so every line costs a token even when it is obviously unprofitable.

There is no cheap first pass. I find out which lines are worth looking at a day later. Some lines are lost entirely because barcodes are matched badly: UPCs that lost their leading zero, and 12-digit UPCs that are never padded to 13.

## Solution

I upload a stock list and click "Pre-screen (free)".
- **Within minutes, using only the free SP-API catalog lookup:** every supplier line gets its ASINs, title and BSR. Lines with no Amazon listing or a dead BSR are cut.
- **That evening, in alchemist-v2's SP-API window:** the remaining lines are priced and their fees estimated, and ROI is worked out against the supplier cost under my VAT model. Lines that pass become a shortlist.
- **Overnight:** the shortlist is gating-checked and queued at the front of the Keepa miner. I get a Discord message with the funnel numbers.
- **In the morning:** the pre-screen view shows the shortlist with Keepa's monthly sales and target price, under my usual ROI and sales filters.

Keepa tokens are spent only on the shortlist, and DealFinder's SP-API use is never affected.

## User Stories

1. As a seller, I want to upload a supplier stock list and start a free pre-screen with one click, so that I don't spend Keepa tokens on lines that can't work.
2. As a seller, I want the pre-screen to cover only lines that have no fresh data in the catalogue, so that lines Alchemist already knows use the stored figures and spend no SP-API calls.
3. As a seller, I want 11-digit and 12-digit barcodes padded to GTIN-13 and matched in both forms, so that lines are never missed or dropped.
4. As a seller, I want lines with no barcode reported as "no barcode", so that I know why they were skipped.
5. As a seller, I want every supplier line resolved to its Amazon ASINs, title and BSR straight away, so that I can see within minutes what the list contains.
6. As a seller, I want up to 3 ASINs per barcode pre-screened separately, so that a single unit is not judged against a multipack listing.
7. As a seller, I want lines whose best BSR is above a ceiling I set (default 150,000) cut before pricing, so that slow sellers don't use the pricing allowance.
8. As a seller, I want the BSR ceiling and the ROI floor shown on the results, so that I know what decided each verdict.
9. As a seller, I want to choose whether a list's costs are ex VAT or inc VAT, so that ROI is right for each supplier.
10. As a VAT-registered seller, I want ROI calculated as profit ÷ gross cash cost, with input VAT reclaimed, so that it matches DealFinder and SellerAmp.
11. As a seller, I want an optimistic ROI check (buy box − 15% referral − minimum FBA fee) before real fees are fetched, so that the fee lookups are spent only on plausible lines.
12. As a seller, I want lines with no buy box or a pricing error kept on the shortlist when their BSR passed, so that out-of-stock opportunities are not lost.
13. As a seller, I want lines with no buy box and a dead BSR dropped, so that tokens are not wasted on dead listings.
14. As a seller, I want lines that pass to be queued for Keepa automatically and mined first that night, so that I have sales data by morning.
15. As a seller, I want the shortlist gating-checked overnight, so that I don't chase lines I can't list.
16. As a seller, I want a Discord summary of the funnel when the night stage finishes (lines → ASINs → BSR pass → shortlist → ungated), so that I know without opening the dashboard.
17. As a seller, I want a progress bar while the pre-screen runs, so that I can see it working.
18. As a seller, I want each line's verdict and reason shown (no barcode, no ASIN, BSR too high, ROI below floor, no buy box, shortlisted), so that I trust the cut.
19. As a seller, I want the morning view to merge shortlist lines with live catalogue data (monthly sold, target price) under my existing ROI and sales filters, so that I can make the final buy decision on one screen.
20. As a seller, I want the Wholesale scan to stop sending unmatched barcodes to Keepa on its own, with a "queue all" override, so that tokens go only where the pre-screen sends them.
21. As a seller re-uploading a weekly list, I want ASIN and BSR results under 7 days old reused, and lines re-priced only when the cost changed or the price is over 24 hours old, so that repeat lists are quick and cheap.
22. As the operator, I want pricing and fees calls made only 20:00–08:00, so that DealFinder's pre-screen is never slowed.
23. As the operator, I want the daytime stage to use only the catalog lookup, which DealFinder never calls, so that a daytime pre-screen has no effect on DealFinder.
24. As the operator, I want the pre-screen and the miner's own catalog pre-screen never to run catalog calls at the same moment, so that they don't trip each other's limits.
25. As the operator, I want results purged after 14 days, so that the database stays under the 500 MB cap.
26. As the operator, I want jobs capped at 10k lines, so that a 700k Qogita catalogue can't be pushed through by accident.
27. As the operator, I want the barcode → ASIN mappings the pre-screen learns written onto existing catalogue rows, so that the miner and the R6 not-found screen benefit, without new bare rows being created.
28. As the operator, I want the browser to be able to submit only a bounded pre-screen command, so that the anon write surface stays narrow.

## Implementation Decisions

- **Ownership.** alchemist-v2 owns the pre-screen job and its tables. Alchemist_Dashboard owns the upload, the anon policy and the views. Cross-repo contracts go in CONTRACTS.md: the new tables in §2, the anon policy in §3, and the SP-API window in §1/§5 with a reference to the ADR.
- **Submission.** The browser inserts a `commands` row of type `wholesale_prescreen` whose payload carries the supplier lines (barcode, cost, stock, description), the VAT basis, the BSR ceiling, the ROI floor and a list name. The anon insert policy is widened to accept this type alongside `queue_backfill_ean`, with a line-count cap of 10k. The dashboard owns that migration.
- **Storage.** There are two tables, owned by alchemist-v2.
  - A **job** table: id, list name, created time, status, settings, and funnel counts by stage.
  - A **line** table, with one row per supplier line × candidate ASIN: job, raw barcode, GTIN-13, supplier cost in pence, ASIN, title, BSR, buy box in pence, fees in pence, optimistic ROI, ROI, verdict and reason.
  - Both are anon read-only. Prices are integer pence (§4).
- **Stages.** The worker runs three stages.
  1. **Catalog stage.** Runs at any time. Batched searchCatalogItems by identifier: summaries, sales ranks and dimensions, up to 3 ASINs per barcode. Then the BSR cut.
  2. **Pricing stage.** Runs only in the alchemist-v2 SP-API window, 20:00–08:00. Competitive price, then the optimistic ROI cut, then a fees estimate at the buy box, then the real ROI.
  3. **Night completion.** Shortlist barcodes are queued as `queue_backfill_ean` commands. Shortlist ASINs are gating-checked into `gating_status`. A Discord summary is sent.
- **Dashboard-wide filters.**
  - Lines already fresh in `products` (has a price and was mined within 30 days) are not sent to the pre-screen; the scan's own result stands.
  - Lines with no barcode are reported, not sent.
- **Verdict logic** is a pure function of the supplier line, the catalog result, the pricing result, the fees result and the settings.
  - **Verdicts:** `no_barcode`, `no_asin`, `bsr_too_high`, `roi_below_floor` (optimistic or real), `shortlisted`, and `shortlisted_unknown` for fail-open lines.
  - **Fail-open rule:** an SP-API unknown (no buy box, error) is shortlisted only if the BSR passed.
- **VAT model.** This follows DealFinder 052 with VAT_REGISTERED = true.
  - Gross cash cost = supplier cost × 1.2 when the list is ex VAT, or the supplier cost as given when it is inc VAT.
  - Net proceeds deduct output VAT.
  - The input VAT reclaim reduces landed cost.
  - ROI = profit ÷ gross cash cost.
- **SP-API calls.** competitivePrice and getMyFeesEstimates are added to alchemist-v2's CommonJS SP-API module. They follow the issue 040 decision to reimplement rather than share DealFinder's TypeScript client, and use DealFinder's parsers and recorded fixtures as reference. Pacing follows the `x-amzn-RateLimit-Limit` header, and a 429 backs off.
- **Catalog call lock.** The pre-screen catalog stage and the miner's catalog pre-screen (R6) never call the catalog at the same moment. They take turns through a shared lock row or an in-process mutex in the same alchemist-v2 process (implementer's choice; same process, so a mutex is enough).
- **Catalogue write-back.** The pre-screen writes `uk_asin` onto existing `products` rows (and rows it is about to queue) whose `uk_asin` is null. It never writes prices and never creates new rows by itself. Shortlist queueing goes through the existing `queue_backfill_ean` path.
- **Reuse.** On re-upload:
  - Catalog results for a barcode under 7 days old are reused.
  - Pricing results are reused if under 24 hours old and the supplier cost hasn't changed.
  - Rows older than 14 days are purged on a daily schedule.
- **Wholesale scan change.** The scan no longer auto-queues unmatched barcodes. A "queue all for Keepa" button keeps the old behaviour on demand.
- **Barcode normalisation.** Keep digits only. 11- and 12-digit codes are left-padded to 13. Matching tries both the raw and the padded form, and queueing sends the GTIN-13 form. This follows the repair logic already in alchemist-v2's catalog loader.
- **Deployment.**
  - Migrations are applied live by the operator: the tables first, then the anon policy.
  - alchemist-v2 is deployed to the VPS.
  - New config:
    - **Optional:** `WHOLESALE_PRESCREEN_ENABLED`, default true once deployed.
    - **Defaults:** window hours (20–08), BSR ceiling (150,000), job line cap (10,000), retention days (14).
    - Each goes in `.env.example`.

## Testing Decisions

Tests check external behaviour (verdicts, rows written, commands queued, calls made), never internals. The seams are:
1. **Dashboard wholesale-matcher functions** (vitest). Cover normalisation (11, 12, 13 and 14 digits, junk), pre-screen payload building (fresh lines excluded, no-barcode counted, cap enforced), and the morning merge with `products` under the filters. Prior art: the existing wholesale-matcher and wholesale-queue tests.
2. **The pure pre-screen module in alchemist-v2** (node:test). Cover the verdict table, the ROI and VAT maths (ex and inc VAT), the fail-open rule, and the window rule for times either side of 08:00 and 20:00 in the UK time zone, including BST changes.
3. **The pre-screen job handler**, driven through the commands stage with a fake SP-API client and a fake db. Cover the daytime run (catalog only, no pricing calls), the night run (pricing, fees, queueing, gating, Discord), reuse on re-upload, and the purge. Prior art: the stage-miner-prescreen, stage-commands and sp-api-batch tests. Parsers are tested against recorded SP-API fixtures.
4. **The live contract** is a human-gated read-only check after the migrations: the anon key can insert a bounded `wholesale_prescreen` command and read both tables, and cannot insert other shapes.

## Out of Scope

- Pricing in the daytime. This is a later issue, and only cheap if the two projects turn out to use separate SP-API app logins (ADR 0001).
- The Qogita 700k catalogue sync, which stays on its existing path. Jobs over 10k lines are refused.
- Changes to the Keepa miner's ordering beyond the existing user-queued tier 0.
- Per-category BSR ceilings.
- Writing SP-API prices into `products`. `target_gb_price` stays Keepa-derived.
- Buying more Keepa tokens. That's a HITL decision after measurement.

## Further Notes

- Measured on 2026-10-09:
  - The miner enriches 12–15k rows a night at ~21 tokens/min.
  - The candidate backlog is ~906k: 546k missing signal and 360k stale.
  - Bliss: 2,676 unique barcodes, 2,144 unmatched, 205 eleven-digit codes dropped, and 31 twelve-digit codes missed even though they exist padded.
- Before daytime pricing is considered, check whether DealFinder and alchemist-v2 use the same LWA client id on the VPS.
