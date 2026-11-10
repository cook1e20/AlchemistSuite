# Spec: closing the business loop, and the shape around it (grilled 2026-11-10)

From an architecture review done while modelling the constellation in SysML v2 (`docs/sysml/`). The operator
asked whether the suite, grown by bolt-ons, is structurally sound. Three challenges were grilled (Q1-Q38):
the business loop isn't closed, DealFinder and alchemist-v2 duplicate a pipeline, and the economics rules are
copied and drifting. Decisions are recorded in ADRs 0002-0005; this spec holds the detail and the build order.

Written from the coordination docs only. The child repos were not reachable from the grilling session, so each
ticket starts by checking its assumptions in the owning repo's code.

## Goal

Track the business, and offer as many pre-filtered buy deals as possible, so the inventory keeps rolling.
The cycle: find deal -> buy -> in transit -> at Amazon -> sold -> capital back -> buy again, with what actually
happened fed back into what gets suggested.

## How buying works today (operator, Q1, Q2, Q8)

- DealFinder is the most frequent source (higher ROI). Qogita and eany are volume buys nearer 20%. Reverse
  sourcing is quiet; SourceWatch (R41) is its follow-up.
- Every buy, retail or wholesale: check in SellerAmp (SAS) on the phone -> buy -> **SAS "send to sheets"** writes
  the BuySheet row (buy price, assumed sale price, ROI; quantity filled in by hand) -> later, at a computer,
  SellerFuse listing builder -> PrepByMe website.
- The BuySheet's **SKU is a sheet formula**, copied into SellerFuse, so the row carries the Seller SKU from the start.
- The Deals tab's buy/dismiss is not used. SellerFuse tracks inventory and sales. Nothing compares expected with actual.

## Decisions

### Challenge 1: the business loop (ADR 0002)

| # | Decision |
|---|---|
| Q6 | SAS -> Sheets stays the single place purchases are recorded. No "bought creates a purchase" step. |
| Q9 | Lots are keyed on the BuySheet's formula SKU (the existing lot design is right). |
| Q12 | First, get the existing inventory pipeline live: `SP_API_SELLER_ID`, deploy alchemist-v2, confirm the lot code reads the sheet's SKU column, a week of real data. `analytics_cache` has not run live since 2026-07-21; that, not missing SKUs, is why `lot_inventory` showed 0 lots. |
| Q22 | A `lots` table, one row per BuySheet row (SKU), created when first seen, updated by the daily run. `analytics_cache` stays the daily display snapshot. |
| Q17 | At ingest, one Keepa lookup (buybox=1) is stored with the lot as the buy-time snapshot: BB now vs avg90, rank drops, offer count, Amazon on listing, monthly sold. If the buy matches a DealFinder alert, reuse that alert's data. |
| Q10 | Attribution is automatic: a new row's ASIN is matched to alerts in the previous 7 days (deal notifications, Qogita drops, best offers, SourceWatch). No match = own find. Matched deals show as bought on the Deals tab; manual buy/dismiss retires. |
| Q14 | In transit / at prep = bought - at Amazon (all buckets incl. inbound) - sold (Amazon orders for the SKU). Sold-through lots come out at 0. A lot over 30 days with an in-transit remainder is flagged, not assumed. Valued at buy price; feeds the Finance tab automatically. The current `qtySoldInferred = purchased - atAmazon` rule is replaced (it reads an unshipped lot as sold). PrepByMe's inventory export is an optional manual upload for flagged lots only. |
| Q15, Q19 | Realised ROI: Amazon's side from the Finances API (fees, refunds); prep and shipping as one flat setting, **£1.00/unit** (label £0.50 + box share + subscription, measured ~£1.05). Revives alchemist-v2 043. |
| Q13, Q16 | The loop must change what the app does. **Winner:** a lot selling at or faster than expected, expected = Keepa monthly sold x 10% share (Q16a b), pace measured from arrival at Amazon. A winner still at **>= 20% ROI** at today's source price and today's sell basis gets a **top-up** suggestion. |
| Q16b | Fire when remaining units cover fewer days than restock lead time + buffer (lead time a setting, per source). |
| Q16c | Suggested quantity: expected units over the next 60 days, capped by supplier stock and minimum order value. You still check in SAS and buy as normal. |
| Q16d | Wholesale winners are rechecked against the Qogita/eany catalogue pulls. Retail winners: the SAS source URL becomes a **SourceWatch** watch automatically; alert when the price is back at a >= 20% ROI level. |
| Q18 | **Post-mortem** when any of: realised ROI < half of predicted; realised ROI < 10%; > 50% unsold after 60 days. Weekly, compares the buy-time snapshot with what happened (bought at a BB peak, offers piled in, price fell with velocity held, velocity fell when price rose, Amazon returned). |
| Q13 | **Sources report:** predicted vs realised ROI, days to sell, profit per £ per month, per source. Report first; price calibration per source later (about 30 sold lots per source); floors stay the operator's call. |
| Q20 | Legacy (pre-SKU) stock stays on per-ASIN blended cost until sold out; excluded from winners and post-mortems. |
| Q21 | Dashboard tabs: Finance (auto in-transit and FBA values), Deals, Inventory (lots, stage, hold-or-sell verdicts and suggested price, R51), Wholesale, **Review** (top-ups, post-mortems, sources), **Watches** (SourceWatch), **Settings** (Q36). |

### Challenge 2: the boundary between DealFinder and alchemist-v2 (ADR 0003)

| # | Decision |
|---|---|
| Q25 | Organise by stage, not by source: source adapters produce **candidates**; one pipeline screens, evaluates, gates and alerts every candidate; an operations side owns catalogue, BuySheet, lots, inventory, finance and the feedback loop. |
| Q28 | **DealFinder = the sourcing pipeline** for every source (Keepa deals, Qogita, eany, Zappies, SourceWatch, top-ups). **alchemist-v2 = operations + catalogue + source pulls** (Qogita/eany downloads feed candidates to DealFinder). 064 alerts, 065 night pre-screen alerts and duplicate evaluators retire as DealFinder covers them. No repo merge. |
| Q31 | One generic **`candidates`** table (source, GTIN/ASIN, cost ex VAT, quantity, link, source ref, found_at, evaluation state), written by every source, read by DealFinder. `qogita_drop_candidates` folds into it after the 067 cut-over. |
| Q32 | The best-offers list stays computed in alchemist-v2 (batch over catalogue data it holds), using the shared economics. |
| Q33 | Keepa/SP-API split unchanged in hours; sourcing (DealFinder) by day, operations (alchemist-v2) by night: miner, buy-ingest snapshots, lot rechecks, post-mortems, winner checks, analytics. |
| Q39 | **SourceWatch is a source, not its own pipeline** (operator 2026-11-10). It keeps the Chrome extension, the VPS checker and the `source_watches` / `source_watch_changes` tables. When a watched page comes back in stock or its price changes, it writes a **candidate** (cost from the page, `vat_basis`, link, ASIN/EAN, the watch's per-watch buy price as a candidate field). DealFinder applies the per-watch buy price when set (it takes priority, as in the SourceWatch spec), else the shared ROI floor, and sends the Discord alert. SourceWatch does no ROI calculation and posts nothing to Discord. Supersedes the 2026-10-13 R41 scope ("alert on entering in stock AND ROI >= floor") and the SourceWatch spec's own alert path; change `SourceWatch/issues/spec.md` and tickets 001-008 before 001 is built. The repo is local-only (no remote): push it to GitHub first. |
| Q34 | One alert per drop, no double-ping trial: 064's Discord posts switch off and DealFinder 067's card is kept. Already under way on main as RUNLIST R58 (alchemist-v2 078, `QOGITA_ALERT_POSTS_ENABLED=false`); 067 went live 2026-11-09. 065's night summary leaves Discord for a tab (R62). |
| Q26 | Free-plan workarounds are lifted (Supabase Pro), after the loop's first steps: Qogita price history moves from SQLite into Postgres; the 015 "no catalogue table" ruling is lifted for Postgres; purges lengthen; old `deals` rows are archived. |
| Q27 | R50 home server postponed: stay on Pro and the VPS. |
| Q30 | Parked: moving the Surface's Claude sessions to cloud sessions (needs the Claude GitHub App on every child repo; sessions use local `.env` and SSH a lot). |

### Challenge 3: one set of economics (ADR 0004)

| # | Decision |
|---|---|
| Q35 | A shared TypeScript package (own repo, e.g. `alchemist-economics`) with one test suite, installed by DealFinder, alchemist-v2 and the Dashboard. The browser shows server-computed numbers wherever possible. |
| Q36 | A Supabase **`settings`** table read by every app, edited from a Dashboard **Settings** page: prep cost, VAT treatment, default and per-source ROI floors, lead times, the 10% share, 60-day cover, 30-day in-transit flag, top-up buffer. |
| Q37 | Canonical rules: sell price = lower of BB avg30/avg90, never the live buy box (fallback new-price avg, flagged); cost = supplier ex VAT x 1.2 + prep + Amazon fees; ROI floor 20% default with per-source overrides; profit/month = profit/unit x min(10% of monthly sold, units bought); velocity = monthly sold, fallback rank drops 30. |

### Discord (ADR 0005)

| # | Decision |
|---|---|
| Q38 | Discord only for urgent, perishable actions: DealFinder deals, Qogita/eany drops (via 067), SourceWatch price-back alerts, top-ups whose timing says order now, pipeline failures. Everything else goes on a tab: best offers, night pre-screen results, post-mortems, sources report, ungating digest, routine stage summaries. Every message says what to do. |

## Build order

1. **Inventory pipeline live** (Q12): RUNLIST R51's remaining operator steps, then confirm lots appear.
2. `lots` table, BuySheet ingest, Keepa snapshot at ingest, automatic attribution (Q17, Q22, Q10). alchemist-v2.
3. In-transit rule and automatic Finance values (Q14). alchemist-v2 + Dashboard.
4. `settings` table + Settings page; shared economics package (Q35-Q37). Root, then each repo adopts it.
5. Realised ROI from the Finances API + prep setting (Q15, Q19; alchemist-v2 043).
6. Winners and wholesale top-ups (Q16). alchemist-v2 (detection), Discord via the Q38 rule.
7. Automatic SourceWatch watches for retail winners (Q16d). Needs R41, rescoped by Q39 (SourceWatch writes candidates).
8. Post-mortems (Q18), Sources report (Q13), Review tab (Q21). alchemist-v2 + Dashboard.
9. `candidates` table; `qogita_drop_candidates` folds in (Q31). DealFinder + alchemist-v2. (Q34's one-alert switch is RUNLIST R58.)
10. Free-plan workarounds lifted (Q26).

Steps 1-3 make Finance and Inventory accurate even if nothing later lands.

## Open questions

- Which BuySheet column holds the formula SKU, and does the lot code read it? (step 1, alchemist-v2)
- Does every current evaluator include a prep cost, and at what value? (step 4, each repo)
- What ROI floor does DealFinder use for EU retail deals today? If above 20%, it becomes that source's override.
- Restock lead time per source (order -> PrepByMe -> live), for Q16b's default.
