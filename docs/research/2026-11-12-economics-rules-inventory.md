# Economics rules inventory (RUNLIST R60, step 1)

Date: 2026-11-12. Read-only research. Source: code at the working-tree state on branch `claude/gracious-fermat-c689v8`; no live calls, no `.env` reads. Paths are relative to the AlchemistSuite root. "DF" = `DealFinder/`, "A2" = `alchemist-v2/`, "DB" = `Alchemist_Dashboard/`. Citations are `file:line`.

Canonical target (ADR 0004 + `issues/spec-business-loop.md` Q35-Q37, lines 65-71), quoted for reference:

- Q37: sell price = lower of BB avg30/avg90, never the live buy box (fallback new-price avg, flagged). Cost = supplier ex VAT x 1.2 + prep + Amazon fees. ROI floor 20% default with per-source overrides. Profit/month = profit/unit x min(10% of monthly sold, units bought). Velocity = monthly sold, fallback rank drops 30.
- Q36: `settings` table for prep cost, VAT treatment, default and per-source ROI floors, lead times, the 10% share, 60-day cover, 30-day in-transit flag, top-up buffer.
- ADR 0004: measured prep is about GBP 1.05 versus the GBP 0.50 coded in places (`docs/adr/0004-...md:3`).
- Spec open question (`spec-business-loop.md:97-98`): "Does every current evaluator include a prep cost, and at what value?" and "What ROI floor does DealFinder use for EU retail deals today?" Both are answered below (prep: only DF; EU retail floor: code default 0.30).

Abbreviations: BB = buy box; ROI "gross" = profit divided by gross cash cost (cost before the VAT reclaim).

---

## 1. Evaluators

### 1.1 DF `evaluateDeal` (retail arbitrage, EU->UK and UK->UK)

- Where: `DealFinder/src/deal-economics/deal-economics.ts:188-251` (`evaluateDeal`), shared tail `deriveOutcome` 319-358, cost `sourceCostBreakdown` 388-407, proceeds `netProceedsAt` 260-274. Config loader `DealFinder/src/config/config.ts:459-505` (`loadEconomicsConfig`, per-market via `withMarketSuffixResolved` 606-614). Defaults `deal-economics.ts:73-85`.
- Drives: whether a Keepa-feed deal passes and is posted to Discord and stored in `deals` (`eval_*` columns). The main decision evaluator.
- Sell basis:
  - EU source: `pickSellBasis` (409-414): `min(live buyBoxPence, buyBoxAvg30Pence)`; label `current` or `avg30`. If either is missing, uses the other; both missing = no basis (`no_uk_price`). This is the live BB when it is below avg30.
  - UK (GBP) source, `config.gbp` set: `pickUkSellBasis` (421-427) = feed `buyBoxAvg90 x (1 - discount)`; `UK_SELL_BASIS_DISCOUNT` default 0.1 (`config.ts:490`). Null avg90 = no basis, never falls back to current.
- Cost basis (`sourceCostBreakdown`):
  - EU price in euro cents x `FX_RATE_EUR_TO_GBP` (default 0.86) / (1 + source VAT) x (1 + UK 20%) (396). Source VAT `EU_VAT_RATE` default per market: de 0.19, fr 0.2, it 0.22, es 0.21, uk 0 (`config.ts:579-585`); global default 0.19 (`deal-economics.ts:84`). So the listed (gross, consumer) price is VAT-swapped, not an ex-VAT supplier price.
  - GBP source: listed pence as-is (394-395).
  - VAT reclaim if `vatRegistered` (`VAT_REGISTERED`, default true, global only: `config.ts:543-560`): `(buy + shipping) x 1/6` for EU, `buy x 1/6` only for GBP (shipping not reclaimed) (397-400). Prep is never reclaimed (comment 383).
  - Landed (net) = buy + shipping + prep - reclaim (405).
- Shipping: weight model `SHIPPING_BASE_PENCE` 50 + `SHIPPING_PER_KG_PENCE` 100 x kg; no weight = `SHIPPING_FLAT_FALLBACK_PENCE` 150 (`deal-economics.ts:197-203`, 82). VAT-inclusive quote. Dashboard can override (`applyShippingOverride` 282-315).
- Prep fee: `PREP_FEE_PENCE` default 50 (`deal-economics.ts:83`; `config.ts:483`). Included in cost.
- Amazon fees (`netProceedsAt` 260-274): referral = Keepa/SP-API `referralFeePct` else `REFERRAL_FEE_RATE` default 0.15; FBA = `fbaFeePence` else `FBA_FULFILMENT_FEE_PENCE` default 300; other fees (closing etc., SP-API) default 0. Net proceeds = sell / 1.2 (when `vatRegistered`, `OUTPUT_VAT_RATE` 0.2) - referral - FBA - other. Referral is charged on the gross sell price, not on the ex-VAT price. Live fees come from SP-API only when `SP_API_PRESCREEN` is `shadow`/`enforce` (`DealFinder/CLAUDE.md` issue 041 note); Keepa never supplies fees here. `LIVE_FEE_FLOOR` does not apply in `evaluateDeal` (see 1.2).
- ROI definition (333): `profit / (landed + vatReclaim)`, i.e. gross cash cost denominator; profit = net proceeds - net landed (331). Comment 332: "SAS's basis".
- ROI floor: `ROI_FLOOR`, code default 0.30 (`deal-economics.ts:75`); per-market override `ROI_FLOOR_<MARKET>` (`config.ts:587-614`, key list 588). Fail code `roi_below_floor` (344-348).
- Velocity (119-130, 205-209): pass when `monthlySold >= VELOCITY_FLOOR` (default 50) OR `salesRankDrops30 >= floor`; rank-drops floor is `VELOCITY_FLOOR_RANK_DROPS[_<M>]` (issue 047), absent = same as `VELOCITY_FLOOR`. Missing signal counts as 0. Per-market `VELOCITY_FLOOR_<M>`. Also `perSellerMonthlyShare` = monthlySold / fbaOfferCount (184-186), informational (not a gate in this file).
- Guards: UK source only: `no_sell_basis`, `no_90d_history` (avg90 or amazonAvg90 missing), `drop_vs_90d_below_min` (current BB must be at least `MIN_DROP_PERCENT_UK` below avg90; default falls back to `MIN_DROP_PERCENT` 25) (`deal-economics.ts:433-461`; `config.ts:494`). Category filtering at feed level: `INCLUDE_CATEGORIES`/`EXCLUDE_CATEGORIES[_<MARKET>]` (`config.ts:322-323, 334-351`), a feed filter, not part of the evaluator. Amazon-on-listing: label only on the Discord card (`DealFinder/src/notifier/notifier.ts:156-159, 287-290`), never a gate.
- Profit/month: none computed.

### 1.2 DF `cachePreFilter` (free pre-filter against cached `products` row)

- Where: `DealFinder/src/cache-pre-filter/cache-pre-filter.ts:44` (`LIVE_FEE_FLOOR`), 52-65 (`optimisticRoi`), 86-110 (`cachePreFilter`).
- Drives: whether a candidate is sent to Keepa (token spend). Rejection is permanent for the 30-day staleness window (`DealFinder/CLAUDE.md`).
- Sell basis: EU: cached `uk_avg30_price` (99); GBP: feed avg90 less discount via `pickUkSellBasis` (96-98). No cached value = pass.
- Cost: `sourceCostBreakdown(priceCents, config.shipping.basePence, config)` (62), same as evaluateDeal but shipping fixed at base 50p (optimistic bound), prep as config.
- Fees: config defaults (15%, 300p) by default (90); `LIVE_FEE_FLOOR` = referral 0.05, FBA 100p when SP-API fees can reach the live eval (`probe.ts:661` `feeBound = pricingMode === 'off' ? undefined : LIVE_FEE_FLOOR`). Other fees 0.
- ROI: same gross-denominator definition as deriveOutcome (64). Floor = `config.roiFloor` (103) (same `ROI_FLOOR`, default 0.30).
- Velocity: not applied here (screen runs later, `probe.ts:955-985` uses `economics.velocityFloor` + `rankDropsFloor`).

### 1.3 DF `spApiPreScreen` (free pre-screen against live SP-API buy box)

- Where: `DealFinder/src/sp-api-pre-screen/sp-api-pre-screen.ts:32-77`.
- Drives: whether a candidate is sent to Keepa stage 1; shadow mode computes but drops nothing.
- Sell basis: live SP-API buy box (46), explicitly an upper bound on live `min(current, avg30)`; GBP source: avg90 less discount (47-51). This is the one place the live BB is deliberately the basis, as a bound.
- Cost: `optimisticRoi` (65): base shipping 50p, config prep and VAT.
- Fees: SP-API `ok` estimate converted to a rate (`liveFeeInputs`), else `LIVE_FEE_FLOOR` (57-64). Defaults from config where `ok` but a fee is missing.
- ROI floor: `config.roiFloor` (66). Failure code `sp_api_roi_below_floor`.

### 1.4 DF `evaluateWholesale` + Qogita feed (`QOGITA_FEED_ENABLED`)

- Where: `deal-economics.ts:464-626` (`evaluateWholesale`, `defaultWholesaleParams` 515-519, `avg30AndAvg90Rule` 491-494). Qogita runner `DealFinder/src/qogita-feed/qogita-feed.ts:173-197` (`wholesalePreScreen`), 380-427 (evaluation). Loader `config.ts:631-644` (`loadWholesaleParams`), `main.ts:144-145`.
- Drives: Qogita drop candidates (read from A2's `qogita_drop_candidates`) -> Discord card via DF 067.
- Sell basis: both BB averages. `avg30AndAvg90Rule`: avg30 and avg90 as separate bases; one missing = judge on the other; the line must clear the floor at the LOWEST-ROI basis (`deal-economics.ts:591-603`). Never the live BB. No new-price fallback.
- Cost: supplier price ex VAT; `grossPrice = price x 1.2`, then `sourceCostBreakdown(..., isGbpSource=true)` (561-562). Reclaim = price x 0.2 if `vatRegistered` (else 0). Gross cash cost = price x 1.2 + shipping + prep (609).
- Shipping: `WHOLESALE_SHIPPING_PENCE`, default 0, gross, not reclaimed (`config.ts:641`).
- Prep: `config.prepFeePence` (`PREP_FEE_PENCE`, default 50), part of gross and net cost (579-583). The Qogita runner uses the global (no-market) economics config (`main.ts:144`).
- Fees: `netProceedsAt`; live SP-API fee at the buy box when `ok` else fee estimated at the lower average (`qogita-feed.ts:381-400`), else config defaults 15%/300p. Per-basis `feesBySource` supported (570-575).
- ROI: gross denominator via `deriveOutcome`. Floor `WHOLESALE_ROI_FLOOR` default 0.20, valid 0 <= x < 5 (`config.ts:635-640`; `deal-economics.ts:506`). Pre-screen rejects at `wholesale.roiFloor` (`qogita-feed.ts:196`).
- Velocity: `velocityPasses(stats, config.velocityFloor, rankDropsFloor(config))` (566): monthlySold >= 50 OR rank drops >= floor (global `VELOCITY_FLOOR`, default 50). Applied to wholesale as a gate (604-606).
- Pre-screen bound (`qogita-feed.ts:173-197`): sell = `max(live BB, stored avg30, stored avg90)`; fees live `ok` else `LIVE_FEE_FLOOR`; no stored average = never rejects; no live BB = `unknown`.
- Guards: no recovery guard, no category rules (`deal-economics.ts:552-553`). Amazon-on-listing label only (`qogita-feed.ts:432, 447`). Stock/MOV/drop rules live in A2 (1.9), not here. Re-post rule `isDuplicatePost`: only after a further 10% drop (`qogita-feed.ts:162-164`).
- Profit/month: none.

### 1.5 DF Zappies evaluation (issue 062)

- Where: `DealFinder/src/email-source/zappies-evaluate.ts:21-30` (params), 76-131 (`evaluateZappiesLine`); batch in `zappies-batch.ts`; loader `config.ts:646-654` (`loadZappiesParams`).
- Drives: whether a Zappies email line is worth buying. Not wired at runtime yet: `loadZappiesParams` and the batch have no non-test caller (grep of `DealFinder/src`, excluding tests, finds only the definitions). See Unverified.
- Sell basis: `avg90 x (1 - 0.10)` single basis (`avg90DiscountedRule`, `deal-economics.ts:497-502`; `ZAPPIES_AVG90_DISCOUNT` 0.1, hard-coded constant, line 21). Current-BB and avg30 ROIs are informational only (zappies-evaluate.ts:97-123).
- Cost: price ex VAT x 1.2 gross, reclaim x 0.2, prep from config, same as 1.4 (header lines 1-3).
- Shipping: `ZAPPIES_SHIPPING_PENCE` default 0.
- Fees: live SP-API per basis price when provided, else config defaults.
- ROI floor: 0.30 (`ZAPPIES_ROI_FLOOR`, hard-coded, line 22; not an env var).
- Velocity: shared `velocityPasses` (monthlySold >= 50 or rank drops >= floor).
- Guards: none (no recovery guard, no category exclusions; header 5-8).

### 1.6 DF static dashboard (`DealFinder/public/index.html`)

- Where: `DealFinder/public/index.html:242-254, 393-404, 517`; generated module `DealFinder/public/deal-economics.js` via `DealFinder/scripts/build-dashboard-economics.ts` (`npm run build:dashboard`).
- Drives: editable-shipping recalculation of ROI for stored deals; ROI colouring.
- Rules: runs the DF formula unchanged (`applyShippingOverride`, `defaultEconomicsConfig`). Floor shown = `defaultEconomicsConfig.roiFloor` (0.30, line 253), i.e. the code default, not the VPS env value. Velocity floor 50 (254). VAT reclaim inferred from stored columns (373-375, 401-403).

### 1.7 A2 `pricing.js` `desiredPrice` (channel-neutral target price)

- Where: `alchemist-v2/pricing.js:14-45`; called from `stage-miner.js:117` and `stage-import.js:144`; inputs from `keepa.js:88-113` (`extractUkProduct`).
- Drives: `products.target_gb_price` ("desired"), the maximum landed cost at 20% ROI. Consumed by DB wholesale scan and morning view (1.11, 1.12).
- Sell basis: `pickSellBasis(currentPrice, avg30Price)` (37-43) = `min(current, avg30)` (same shape as DF's `pickSellBasis`). The inputs are Keepa price series index 1 (NEW price) with fallback to Amazon price (index 0), then avg30 new (`keepa.js:94-97`), and `avg30Price = stats.avg30[1]` (`keepa.js:116`). They are NOT buy-box averages (comment `keepa.js:114-115` and A2 CLAUDE.md issue 054: "`uk_avg30_price` ... is a different series (index 1, new price)"). So the basis is lower of current new price / avg30 new price, labelled `current`/`avg30`. The live current price can set it.
- Cost: none (desired = net proceeds / (1 + 0.20)). No shipping, prep, FX or VAT-on-cost. Netting: sell / 1.2 - referral - FBA (24).
- Fees: Keepa `referralFeePercent` default 15 and `fbaFees.pickAndPackFee` default 400 pence when absent (`keepa.js:90-91, 108-109`) (the defaults differ from DF's 300p).
- ROI floor: hard-coded `ROI_FLOOR = 0.20`, `OUTPUT_VAT_RATE = 0.20` (14-15). Formula `net / (1 + floor)` implies net-cost denominator in the target, unlike the gross definition elsewhere (see 1.11 for how DB reinterprets).
- Velocity, guards: none.

### 1.8 A2 wholesale pre-screen (SP-API, night)

- Where: `alchemist-v2/wholesale-prescreen.js:301-364` (constants, `roiOf`, `optimisticRoi`, `realRoi`, cuts), `stage-wholesale-pricing.js:233-315`. Payload validation 212-268 (`roi_floor` fraction, 0 <= x < 5). Config `config.js:257` (`WHOLESALE_PRESCREEN_ROI_FLOOR`, default 0.20).
- Drives: shortlist of supplier-list lines (dashboard upload, Qogita evening confirmation) that go on to Keepa queueing (`roi_below_floor` vs `shortlisted`).
- Sell basis: LIVE SP-API competitive-pricing buy box (`stage-wholesale-pricing.js:266, 314`; `realRoi(line.buy_box_pence, ...)`). No avg30/avg90.
- Cost: `grossCashCostPence` (313-315): ex-VAT list = cost x 1.2; inc-VAT list = cost as given. Net cost = gross / 1.2 (always treats operator as VAT-registered; no flag). `vat_basis` per job (`ex_vat`/`inc_vat`).
- Shipping: none. Prep: none. Other/closing fee: included only as part of SP-API `totalFeesPence` (real); excluded in the optimistic cut.
- Fees: real = SP-API `totalFeesPence` at the buy box (314); optimistic = 7% referral + 100p minimum FBA (`OPTIMISTIC_REFERRAL_RATE` 0.07, `MIN_FBA_FEE_PENCE` 100: 305-306, 337). Fees are subtracted from the ex-VAT proceeds un-adjusted (326-328).
- ROI (324-331): `(bb/1.2 - fees - gross/1.2) / gross`, gross denominator, clamped to +-9999.9999. Per-job `roi_floor` else `WHOLESALE_PRESCREEN_ROI_FLOOR` 0.20 (`stage-wholesale-pricing.js:233`); dashboard UI default sends 20 (see 1.12).
- Velocity: none. Instead BSR ceiling `DEFAULT_BSR_CEILING` 150000 (`wholesale-prescreen.js:7`), best main-category rank only; `bsr_ceiling` per job. Fail-open rules for unpriceable lines (`unpriceableVerdict`).
- Guards: gating (restrictions) stage before Keepa queueing (`stage-wholesale-gating.js`); BSR; no recovery guard.
- Profit/month: none.

### 1.9 A2 Qogita drop alerts (064/076) `qogita-alerts.js`

- Where: `alchemist-v2/qogita-alerts.js:1-60` (rules header), 63-65 (defaults), 142-160 (`estimate`), 164-170 (`alertFloorSkip`), 425-440 (floor use). Config `config.js:196-200, 207`.
- Drives: Discord post per drop (now switchable off: `QOGITA_ALERT_POSTS_ENABLED`, `config.js:207`, RUNLIST R58) and the `qogita_drop_candidates` rows read by DF 067.
- Candidate rules: price drop >= `QOGITA_DROP_PCT` (default 10%) vs baseline (avg30 after 7 days of history, else previous pull); stock value (units x price ex VAT) >= `QOGITA_MIN_STOCK_VALUE_GBP` (default 500, stored as pence 50000); not a pre-order; brand not blocked.
- Sell basis: `products.uk_buybox_avg30_pence` and `..._avg90_pence`; ROI computed at each (`estimate` 147-153), null if missing. No new-price fallback in the alert. Never live BB.
- Cost: offer price ex VAT x 1.2 gross (143, `grossCashCostPence(..., 'ex_vat')`); net = gross / 1.2 (via `realRoi`).
- Shipping, prep: none.
- Fees: re-derived per average: `referral_pct/100 x price + fba_pick_pack` from the `products` row (unrounded); missing = ROI null (never defaulted) (144-150). The stored `products.referral_pct`/`fba_pick_pack` are Keepa's, which the extractor defaults to 15 / 400 when Keepa omits them (`keepa.js:90-91, 108-109`); whether those defaults land in the table: see Unverified.
- ROI: gross denominator (`realRoi`). Posting floor: lower of roi30/roi90 >= `QOGITA_ALERT_ROI_FLOOR` default 0.20 AND profit/unit >= `QOGITA_ALERT_MIN_PROFIT_PENCE` default 200 (`config.js:199-200`; `qogita-alerts.js:164-170`). Profit/unit = lower ROI x gross cost rounded (155).
- Velocity: none for the alert (sales count only for profit/month).
- Profit/month: `profit/unit x min(monthly_sold / 10, offer stock)` (`SALES_SHARE_DIVISOR = 10`, line 54; `estimate` 156-159). Matches Q37's formula.

### 1.10 A2 supplier best offers (069/070) `supplier-best-offers.js`

- Where: `alchemist-v2/supplier-best-offers.js:1-110` (header + `evaluateOffer` 74-110+), `config.js:223-227`.
- Drives: Postgres `supplier_best_offers` table read by the DB Qogita tab (the "Best offers" list).
- Qualifying: shared value-only stock rule (default GBP 500 ex VAT); not pre-order; not blocked; matched (ASIN, referral_pct, fba_pick_pack present); sales test `uk_sales_rank_drops30 >= 3` OR `monthly_sold > 0` (`MIN_DROPS30 = 3`, line 69; 87); ROI >= `BEST_OFFERS_MIN_ROI` default 0.15 (`config.js:224`; `supplier-best-offers.js:58`).
- Sell basis: basis `bb` when any BB average (30/90) is usable; else basis `new` = `uk_avg30_price` (30-day NEW-price average) passed as the "30" average (header 33-37; `evaluateOffer` 95-104). The only evaluator with a new-price fallback; stored in the `basis` column.
- Cost, fees, ROI: identical to 1.9 (reuses `alerts.estimate`): ex VAT x 1.2, no shipping/prep, fees re-derived at each price, gross denominator, lower of the two ROIs gates.
- Profit/month: `profit/unit x min(monthly_sold x 10%, offer stock)` (header 36-37).
- Velocity: the 3-drops-or-any-monthly-sold test above (not a 50/month floor).
- Stored floor 0.15 is below the DB default 20%; DB clamps its display floor up to 15 (`best-offers.ts:10`).

### 1.11 DB wholesale scan ("Product Finder"/Wholesale tab) `wholesale-matcher.ts`

- Where: `Alchemist_Dashboard/src/wholesale-matcher.ts:223-268` (ROI maths), 196-216 (row build), 271-303 (filters); UI defaults `main.ts:1286-1308, 1352-1356, 2683-2685`; table `supplier-table.ts:32, 62, 80`.
- Drives: which rows of an uploaded supplier file are shown as deals (client-side, browser matching against `products`).
- Sell basis (headline `roi`): `roiFromTarget` (251-254) = ROI at `target_gb_price x 1.2` as net proceeds, i.e. the Keepa NEW-price `min(current, avg30)` basis from A2 `desiredPrice` (1.7) at the 20% floor (`TARGET_ROI_FLOOR = 0.20`, 227). Extra columns `roi30`/`roi90` use `roiAtPrice` (260-269) at `uk_buybox_avg30_pence`/`avg90_pence` (215-216). Headline ROI is NOT BB-average based.
- Cost: `grossCashCostPence` (235-237): ex VAT x 1.2 (`UK_VAT_MULT = 1.2`, 233) or inc-VAT as given; net = gross / 1.2 (always reclaimed). Non-GBP supplier files converted via `fxRateEurToGbp` (`DEFAULT_FX_RATE_EUR_TO_GBP`, DB constant; value not checked, see Unverified).
- Shipping, prep: none (the UI text states "before inbound shipping or prep": `main.ts:1778`).
- Fees: `roiAtPrice` re-derives `referral_pct/100 x price + fba_pick_pack` from `products`; missing = null (never defaulted). Headline ROI uses fees embedded in target (Keepa defaults 15%/400p when absent, 1.7).
- ROI: gross denominator (245-248).
- Floor: UI `Min ROI` default 20, persisted in localStorage (`WS_MIN_ROI_KEY`, `main.ts:1286, 1302, 2683-2685`), per-user, invalid = 20. Optional `minRoi30`, `minRoi90` and `minDrops30` floors default off (`main.ts:1288`), unknown fails a floor (`wholesale-matcher.ts:280-290`).
- Velocity: "50+ sales/mo" tick: `WS_MIN_SOLD = 50` (`main.ts:1308`) on `monthly_sold` (unknown fails; 296-301); optional drops floor separately; no OR between the two signals.
- Guards: `uk_not_found_at` exclusion; no recovery guard.

### 1.12 DB morning view `wholesale-morning.ts`

- Where: `Alchemist_Dashboard/src/wholesale-morning.ts:141-150` (filter), 160-182 (row build).
- Drives: shortlisted pre-screen lines with live `products` data, filtered "under the scan's Min ROI / 50+ sales filters" (`main.ts:2239`).
- Rules: same maths as 1.11 (`roiFromTarget` + `roiAtPrice`), plus `apiRoiPct` = A2 pre-screen ROI (1.8) shown beside. The ROI floor and 50/month floor are the scan's UI values. Cost basis uses the job's `vat_basis`. Lines without Keepa data fail open (143).

### 1.13 DB Qogita tab / best offers `best-offers.ts`

- Where: `Alchemist_Dashboard/src/best-offers.ts:10-16, 50-57, 83-115`; `supplier-table.ts:62`; `main.ts:2470-2474, 2581`.
- Drives: client-side filter over server-computed `supplier_best_offers` rows (1.10). No ROI maths here; reads stored `roi30`/`roi90`/`profit_unit_pence`/`profit_month_pence`.
- Defaults: `DEFAULT_ROI_FLOOR_PCT = 20`, clamped up to `SERVER_ROI_FLOOR_PCT = 15` (the server floor) (`best-offers.ts:10-12, 109`); `DEFAULT_MIN_PROFIT_PENCE = 200`; `DEFAULT_MIN_STOCK_VALUE_PENCE = 60_000` (GBP 600 INC VAT, = 500 ex VAT x 1.2) (14-15). Floor tests lower of roi30/roi90 (112-115). This is the only existing screen that shows server-computed numbers (the direction ADR 0004 asks for).
- Cost display: ex VAT x 1.2 (`grossCashCostPence`, 50-52).

### 1.14 DB deals tab `deal-actions.ts` / `main.ts`

- Where: `Alchemist_Dashboard/src/deal-actions.ts:62-146`; `main.ts:917-1033`.
- Drives: display of DF `deals` rows. No ROI maths; shows stored `eval_roi` (DF 1.1). Derives `grossCostPence = buy + shipping + prep` (125-129).
- Hard-coded colour threshold: ROI green at >= 30% (`main.ts:1012`), a literal, not read from any setting; coincides with DF's 0.30 default.

### 1.15 DB lot actual-cost ROI `analytics.ts`

- Where: `Alchemist_Dashboard/src/analytics.ts:100-106` (`shapeLotView`), shown at `main.ts:1273`.
- Drives: per-lot "ROI" on the Inventory/Finance lots table.
- Rule: `(avgSalePricePence - unitCostPence) / unitCostPence x 100`, net cost denominator, no fees, no VAT handling, no prep; `unitCostPence` is the lot's batch cost and `avgSalePricePence` from A2's order scan (`alchemist-v2/analytics.js`). Whether sale price is VAT-inclusive: Unverified.

### 1.16 A2 analytics / stock_health, KeepaCompanion

- `alchemist-v2/analytics.js`, `stage-analytics.js`, `stock-health.js`, `stage-analytics-stock-health.js`: no ROI or economics rule. `stock-health.js:5` states "No verdict here: the dashboard owns the rules". grep of `stock-health.js` and `analytics.js` for roi/vat/profit finds no ROI computation (only a "margin" comment at `analytics.js:233`). A hold-or-sell verdict does not exist in `Alchemist_Dashboard/src` (grep for `hold.or.sell`/`holdOrSell`/`stock_health` over `src` returns no files).
- `KeepaCompanion/`: no ROI, profit or fee computation in `src/` (only matches are CSS `margin`). Not an evaluator.

---

## 2. Comparison table

Legend: BB = buy box, "gross" = denominator is gross cash cost, n/a = not part of this evaluator, "-" = none. Floors are code defaults; live env values were not read (see Unverified).

### 2a. Sell basis, cost, fees

| Rule | DF evaluateDeal (EU) | DF evaluateDeal (UK src) | DF cachePreFilter | DF spApiPreScreen | DF wholesale/Qogita feed | DF Zappies |
|---|---|---|---|---|---|---|
| Sell basis | min(live BB, avg30) `deal-economics.ts:409` | avg90 x 0.9 (`UK_SELL_BASIS_DISCOUNT`) | cached avg30 (EU); avg90 x 0.9 (UK) | live BB (EU); avg90 x 0.9 (UK) | lower-ROI of BB avg30 / avg90; pre-screen: max(live, avg30, avg90) | avg90 x 0.9 (hard-coded) |
| New-price fallback | no | no | no | no | no | no |
| Cost currency | EUR cents x FX 0.86 | GBP pence | as evaluateDeal | as evaluateDeal | GBP pence ex VAT | GBP pence ex VAT |
| Cost VAT | listed gross: / (1+src VAT) x 1.2 | listed as-is; reclaim 1/6 of price | as evaluateDeal | as evaluateDeal | ex VAT x 1.2, reclaim 0.2 x price | same as Qogita |
| VAT-registered flag | yes (`VAT_REGISTERED`, default true) | yes | yes | yes | yes (via `sourceCostBreakdown`) | yes |
| Shipping | 50p + 100p/kg, flat 150p | same | base 50p (bound) | base 50p (bound) | `WHOLESALE_SHIPPING_PENCE` 0 | `ZAPPIES_SHIPPING_PENCE` 0 |
| Prep | 50p (`PREP_FEE_PENCE`) | 50p | 50p | 50p | 50p (config) | 50p (config) |
| Fees | live SP-API if mode on, else 15% / 300p; other fees SP-API | same | defaults 15%/300p, or `LIVE_FEE_FLOOR` 5%/100p | SP-API ok else `LIVE_FEE_FLOOR` | live ok / basis-priced live, else 15%/300p; pre-screen `LIVE_FEE_FLOOR` | live per basis else 15%/300p |
| Output VAT | /1.2 if registered | same | same | same | same | same |

| Rule | DF evaluateDeal (EU) | DF Qogita feed | DF Zappies |
|---|---|---|---|
| ROI denominator | gross (landed + reclaim) | gross | gross |
| ROI floor | `ROI_FLOOR` 0.30; `ROI_FLOOR_<M>` | `WHOLESALE_ROI_FLOOR` 0.20 | 0.30 constant |
| Velocity | monthlySold >= 50 OR drops >= (`VELOCITY_FLOOR_RANK_DROPS` or 50) | same global values | same |
| Guards | UK: avg90/amazonAvg90 present, drop >= 25% | none | none |
| Profit/month | no | no | no |

### 2b. alchemist-v2 and Dashboard

| Rule | A2 desiredPrice | A2 wholesale pre-screen | A2 Qogita alerts (064/076) | A2 best offers (069) | DB scan | DB morning | DB best-offers tab | DB lot ROI |
|---|---|---|---|---|---|---|---|---|
| Sell basis | min(current NEW, avg30 NEW), Keepa series 1 | live SP-API BB | BB avg30 and avg90, lower ROI | BB avg30/avg90 lower; else new avg30 ("new" basis) | headline: A2 target (new-price based); also BB avg30/avg90 columns | as scan + SP-API ROI | stored server values | average actual sale price |
| New-price fallback | is the basis | no | no | yes (flagged `basis`) | headline is new-price | headline is new-price | shows `basis` | n/a |
| Cost currency | n/a (no cost) | GBP pence | GBP pence | GBP pence | GBP (FX for EUR files) | GBP | GBP | GBP |
| Cost VAT | n/a | ex x 1.2 or inc as given | ex x 1.2 | ex x 1.2 | ex x 1.2 or inc as given | per job `vat_basis` | ex x 1.2 | none |
| VAT-registered flag | hard 0.2 output VAT | hard-coded (always reclaims) | hard-coded | hard-coded | hard-coded 1.2 | hard-coded | n/a | none |
| Shipping | none | none | none | none | none | none | none | none |
| Prep | none | none | none | none | none | none | none | none |
| Fees | Keepa pct/pick-pack, defaults 15/400 | SP-API total at live BB; optimistic 7% + 100p | `products` referral_pct/100 x price + fba_pick_pack | same | same (target's fees + `roiAtPrice`) | same | stored | none |
| ROI denominator | net (net / 1.2) | gross | gross | gross | gross | gross | stored (gross) | cost (net, no VAT) |
| ROI floor | 0.20 constant | job `roi_floor` else `WHOLESALE_PRESCREEN_ROI_FLOOR` 0.20 | `QOGITA_ALERT_ROI_FLOOR` 0.20 + profit >= 200p | `BEST_OFFERS_MIN_ROI` 0.15 | UI 20% (localStorage) | scan's UI value | UI 20%, clamped >= 15 | none |
| Velocity | none | BSR <= 150000 | none | drops30 >= 3 OR monthly_sold > 0 | monthly_sold >= 50 (tick); optional drops floor | same as scan | server-side (069) | none |
| Guards | none | gating, BSR | pre-order, blocked brand, stock value >= GBP 500, drop >= 10% | pre-order, blocked, stock value, matched, sales | not-found exclusion | as scan | filters (stock inc VAT 600, profit 200p) | none |
| Profit/month | no | no | yes: unit x min(sold/10, stock) | yes (same) | no | no | shown, stored | no |

---

## 3. Differences from the canonical rules (Q37)

Q37 baseline: sell = lower of BB avg30/avg90, never the live buy box (fallback new-price avg, flagged); cost = ex VAT x 1.2 + prep + Amazon fees; ROI floor 20% default with per-source overrides; profit/month = profit/unit x min(10% of monthly sold, units bought); velocity = monthly sold, fallback rank drops 30. ADR 0004 adds measured prep about GBP 1.05.

Sell price
1. DF `evaluateDeal` (EU): uses `min(live BB, avg30)` (`deal-economics.ts:409-414`), so the live buy box sets the basis when it is below avg30; avg90 is not used. Canonical forbids the live BB and uses avg30/avg90.
2. DF `evaluateDeal` (UK source): avg90 less 10% haircut only (`deal-economics.ts:421-427`), no avg30; the haircut has no canonical counterpart.
3. DF `cachePreFilter`: cached avg30 only, as a deliberate bound (`cache-pre-filter.ts:99`).
4. DF `spApiPreScreen`: live SP-API buy box (`sp-api-pre-screen.ts:44-46`), as a deliberate optimistic bound.
5. DF Zappies: avg90 less 10% (hard-coded) only (`zappies-evaluate.ts:21, 29`); avg30 informational.
6. DF Qogita feed evaluation: avg30 and avg90 both evaluated, gate on the lower ROI, one missing = judge on the other. Close to canonical. No new-price fallback (canonical has one, flagged). Pre-screen uses `max(live BB, avg30, avg90)` (`qogita-feed.ts:184`) as a bound.
7. A2 `desiredPrice`: lower of current NEW price and avg30 NEW price (Keepa series 1, `keepa.js:94-97, 116`), not buy-box averages; no avg90; the current price can set it.
8. A2 wholesale pre-screen: live SP-API buy box only (`stage-wholesale-pricing.js:266, 314`).
9. A2 Qogita alerts: BB avg30/avg90 lower ROI, no new-price fallback. Matches the canonical basis. A2 best offers: matches, plus a new-price fallback (`basis = 'new'`) that is flagged in a column, matching the canonical fallback.
10. DB scan and morning headline `roi` is derived from A2's new-price-based `target_gb_price` (`wholesale-matcher.ts:251-254`); BB-average ROIs are separate optional columns (`roi30`, `roi90`) and the 20% filter applies to the headline, not to them.

Cost
11. VAT/cost source: DF `evaluateDeal` costs a consumer gross price swapped between VAT regimes (EUR, FX 0.86); canonical is supplier ex VAT x 1.2. All wholesale evaluators (DF 1.4/1.5, A2, DB) use ex VAT x 1.2 (or inc-VAT as given for A2/DB uploads, which has no canonical statement).
12. VAT-registered handling: DF has a `VAT_REGISTERED` flag (default true) that also changes output VAT; A2 and DB hard-code registered behaviour (net = gross / 1.2 always) (`wholesale-prescreen.js:302, 327`; `wholesale-matcher.ts:233, 247`). The canonical rule puts VAT treatment in settings.
13. Prep: only DF includes prep (50p default, `deal-economics.ts:83`); DF treats it as never reclaimed. A2 desiredPrice, A2 wholesale pre-screen, A2 Qogita alerts, A2 best offers, DB scan, morning view and DB tab include none (UI text states "before inbound shipping or prep", `main.ts:1778`). ADR measured value is about GBP 1.05 versus DF's 0.50.
14. Shipping: DF includes shipping (weight model for retail; 0 for wholesale/Zappies by default); A2 and DB include none. Canonical Q37 lists no shipping.
15. Amazon fees: DF uses SP-API live fees when the mode allows, else 15%/300p defaults, with closing fees as `otherFeesPence`. A2 `desiredPrice` defaults 15%/400p (`keepa.js:90-91`). A2 alerts, best offers and DB re-derive from stored `referral_pct`/`fba_pick_pack`, no default (null ROI). A2 pre-screen uses SP-API total fees at the live BB. Fee floors for bounds: DF `LIVE_FEE_FLOOR` 5%/100p; A2 optimistic 7%/100p. Three different default fee pairs coexist (15%/300p, 15%/400p, none).
16. Output VAT/fees: all subtract fees un-adjusted from ex-VAT proceeds (DF `deal-economics.ts:271`; A2 `wholesale-prescreen.js:328`; DB `wholesale-matcher.ts:267-268`); no evaluator reclaims VAT on fees.

ROI definition and floor
17. Denominator: gross cash cost everywhere except A2 `desiredPrice` (target = net / 1.2, net-cost basis) and DB lot ROI (cost only, net, no fees); DB reinterprets A2's target by multiplying back by 1.2 (`wholesale-matcher.ts:253`).
18. Floor values (code defaults): DF retail 0.30, DF Zappies 0.30 (constant), DF Qogita feed 0.20, A2 pre-screen 0.20, A2 alert 0.20 plus 200p profit, A2 best offers stored 0.15, DB scan/tab UI 20 (tab clamped >= 15), DB deals colour 30 (literal). Canonical: 20% default with per-source overrides. DF retail 0.30 and Zappies 0.30 would become overrides; A2 best offers 0.15 is below default.
19. Per-source overrides: DF supports `ROI_FLOOR_<MARKET>` (EU/UK source) only; others use separate env names (`WHOLESALE_ROI_FLOOR`, `WHOLESALE_PRESCREEN_ROI_FLOOR`, `QOGITA_ALERT_ROI_FLOOR`, `BEST_OFFERS_MIN_ROI`) or UI/localStorage per browser (DB). The Zappies floor is not configurable.
20. The DB scan floor is browser-local (localStorage), not shared between devices.

Velocity
21. Canonical: monthly sold, fallback rank drops 30. DF: monthlySold >= 50 OR drops >= floor (both default 50, rank-drops floor splittable, `deal-economics.ts:119-130`); applied to wholesale too. DB scan: monthly_sold >= 50 tick only (unknown fails; no drops fallback), drops floor separate and optional. A2 best offers: drops30 >= 3 OR monthly_sold > 0 (`supplier-best-offers.js:69, 87`). A2 pre-screen: BSR ceiling 150000 instead. A2 alerts: none. DF 50 is the Amazon badge floor (monthly_sold is null below 50), so `monthlySold >= 50` always passes when present.

Profit/month
22. Only A2 alerts and best offers compute it, matching Q37 (10% of monthly sold, capped by offer stock; `qogita-alerts.js:54, 156-159`). The Q37 cap is "units bought"; code caps at offer stock. DF computes none (only `perSellerMonthlyShare`, informational).

Guards
23. DF retail: recovery guards (UK), category feed filters, Amazon-on-listing as label. DF wholesale: none. A2: stock-value (GBP 500 ex VAT), blocked brand, pre-order, gating. DB tab: stock value stored ex VAT 500, displayed inc VAT 600.

Config source
24. No evaluator reads a `settings` table; all use env vars (DF, A2 server), code constants (DF Zappies, A2 `pricing.js`, DB constants) or browser localStorage (DB filters). Env var names differ per repo; there is no shared registry.

---

## 4. Unverified

1. Live env values: DF/A2 VPS `.env` were not read. `ROI_FLOOR` live may differ from 0.30; `VELOCITY_FLOOR`, `PREP_FEE_PENCE`, `VAT_REGISTERED`, `QOGITA_ALERT_ROI_FLOOR`, `WHOLESALE_ROI_FLOOR` etc. may be overridden. The spec's open question "what ROI floor does DealFinder use for EU retail deals today" is answered here only as the code default 0.30. (`DealFinder/CLAUDE.md` intro also says >=30% ROI, >=50 sales/month.)
2. DF Zappies evaluation is not called by any runtime path I found (`loadZappiesParams` has no non-test caller; `zappies-batch.ts` has none outside tests). It may be unwired pending a later issue; if so its rules are not yet live.
3. Whether A2's `products.referral_pct`/`fba_pick_pack` columns store the `keepa.js` 15 / 400 defaults when Keepa omits fees. Needs `db.js` upsert and a live check. If stored, A2 alerts, best offers and DB scan fees are partly defaults, contradicting the "never defaulted" comments.
4. Which Keepa series index 1 really is. `keepa.js:93` comments "new buy box"; A2 CLAUDE.md issue 054 says "index 1, new price". I treated it as the NEW price series, not a buy-box series; not confirmed against a Keepa fixture.
5. DB `DEFAULT_FX_RATE_EUR_TO_GBP` value and where defined (not read); DF's is 0.86 (`deal-economics.ts:74`).
6. Whether DB lot ROI `avgSalePricePence` is VAT-inclusive (`analytics.ts:100-106`; computed in `alchemist-v2/analytics.js`, not read in detail), so whether lot ROI is comparable to the others.
7. DF Qogita feed: I did not read the full runner for how `economics` for the Qogita pass handles `VAT_REGISTERED`/`PREP_FEE_PENCE` beyond `main.ts:144` (global config, no market); the per-market suffix variables do not apply there.
8. DB hold-or-sell verdict: `stock-health.js` says the dashboard owns the rules, but nothing in `Alchemist_Dashboard/src` implements it at this commit (grep found nothing). Not inventoried because it does not exist in code yet.
9. A2 `stage-import.js` use of `desiredPrice` (144, 239) and `stage-miner.js:117`: confirmed the call sites and that the target is stored as `target_gb_price`/`targetGbPrice`; the column mapping in `db.js` was not read.
10. DB morning view `passes()` full semantics beyond `wholesale-morning.ts:141-150` (e.g. how ROI vs `apiRoiPct` interact in sorting) not traced.
11. I did not trace `DealFinder/src/products-upsert`, `deal-store` or `offer-store` for any additional ROI arithmetic (grep showed "roi" in those files; assumed storage only). `deal-lifecycle.ts`, `notifier.ts` and `probe.ts` also matched "roi"; I assumed display/storage/plumbing only, apart from the cited `probe.ts:661, 955-985, 1526` uses of the shared floors.
12. `eany` (second supplier slot in `supplier-best-offers.js`, `best-offers.ts`) has no evaluator yet; not inventoried.
