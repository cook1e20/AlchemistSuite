# Constellation run list

Ordered queue for working the open issues across the constellation, one per fresh
session. Usage: `/next-task` from this root directory works the **topmost unchecked,
unblocked entry**, in the repo that owns it; `/clear` between iterations. Tick the box
(and add a one-line result note) when the issue lands.

Priorities set 2026-07-15 (constellation review). Reorder freely — this file is the
queue, not a contract. `severity: critical` bugs in any repo jump the queue regardless
of this order.

## Run order (reset 2026-09-25) — work from here

Rebuilt 2026-09-25 from a review of all five repos (root, alchemist-v2, DealFinder,
Alchemist_Dashboard, KeepaCompanion), every open issue, and a live read of the shared
DB. **This section is the queue.** Phases A–L below are history; their still-open
entries are folded in here and marked `[→ Rn]` where they stand.

Live state at the reset: DB **472 MB of the 500 MB free cap** (read-only mode on breach);
`products` 1,151,126 rows / 304 MB; `deals` 454k / 128 MB; `gating_status` 305 verdicts,
`asin_tracker` 67 rows (so the Gate column is live); `run_log` shows `mine`, `scout`,
`commands` running, no `wholesale-sync`.

### Now — risk and hygiene

- [ ] **R1. Decide the DB-size path** (HITL, operator, **urgent**) —
      `alchemist-v2/issues/038-products-growth-and-bulk-load-cohort.md` (was L3).
      Pro plan vs retire the not-found bulk cohort vs cap DealFinder's
      `products-upsert` intake (~4.9k rows/day, the real growth source). At current
      intake (~1.1 MB/day into `products`, per 038) the 28 MB of headroom lasts
      roughly 3–4 weeks — less if `deals` grows faster than its 30-day retention trims. Blockers: none.
      *2026-10-07: DB was 552 MB (over cap, not yet read-only). Operator decision: stay on
      free for 1–2 months while the model proves cashflow, then Pro. Done live: deleted
      331,532 expired no-outcome `deals` rows (purge rule at 7 days), `VACUUM FULL deals`
      → DB 435 MB (deals 167 → 49 MB). **Open (operator):** set `EXPIRED_RETENTION_DAYS=7` in
      DealFinder's VPS `.env` + `pm2 restart dealfinder`, or deals regrows ~100 MB in 3 weeks.
      Still available if needed: drop the ~260k not-found/no-ASIN `products` rows (~45–70 MB)
      and `VACUUM FULL products` (~25–30 MB bloat; needs headroom for a temp copy).*
- [x] **R2. Commit the in-flight gating work** (HITL, housekeeping) — git is behind
      the live system in four places. Check no other session is mid-edit first.
      - root: Phase K RUNLIST section, `CONTRACTS.md` §1–3, `README.md`,
        `.gitignore`, `issues/007` (all from 2026-09-19).
      - alchemist-v2: `migrations/2026-09-19-create-gating-status.sql`, `supabase/`
        (the `gating-check` function), `test/gating-check-logic.test.mjs`,
        `package.json`, `issues/038`.
      - Alchemist_Dashboard: `src/gating*.ts`, `src/main.ts`, `index.html`, and
        migration `20260925120000_gating_status_anon_read.sql` — **already applied
        live** (policy `anon read gating_status` exists), so the repo lags the DB.
      - KeepaCompanion: **no commits at all** on `master`; the whole repo is
        untracked. Needs an initial commit (and a remote, if wanted).
      Blockers: none.
      *2026-10-06: done on operator go-ahead, all suites green first. alchemist-v2 gating
      work was already in c8a76d5; issue 038 committed (2b77e64). Alchemist_Dashboard was
      already clean (43fa6fe/e4abaa9 + migration tracked). KeepaCompanion initial commit
      45a8787 (36/36, typecheck clean, secret scan clean; no remote). Root: this commit.*
- [ ] **R3. Tick K2 after confirming** (HITL, 2-minute check) — `gating_status` has
      305 completed verdicts (latest 2026-09-24), so the secrets are set and the
      function runs. Operator confirms the KeepaCompanion columns render on the live
      Product Finder, then tick K2. Blockers: none.

### Next — token savings

- [ ] **R4. DealFinder 041: shadow → enforce** (HITL, operator) —
      `DealFinder/issues/041-sp-api-roi-pre-screen-in-funnel.md`. Code complete; the
      only open box is the operator switch after ≥24h of shadow with zero false
      rejects, then raising `FEED_PAGE_CAP`. Record both in the issue, move it to
      `done/`. Blockers: none (shadow began 2026-09-24).
      *2026-09-28: enforce live since 09-25 (passes ~0.5/day → 3–5/day); operator
      raised `FEED_PAGE_CAP=6`, `SP_API_PRESCREEN_MAX_ASINS=3200`. Remaining: review
      funnel log after ~a day at 6 pages (see issue), then close. Parked follow-ups:
      UK→UK "price recovery" source market (needs its own sell-basis model, not a
      config flip), `uk_fba_offer_count` null on every pass (competition blind),
      purchases not being marked bought (1 ever recorded).*
- [ ] **R5. `alchemist-v2/issues/039-store-sales-rank-drops30-on-products.md`** (AFK,
      small) — was L1. Nullable column + one upsert field; data already parsed.
      Start early: R10 needs a full mine cycle of this data. Blockers: none.
      *2026-10-05: code landed (alchemist-v2 34c3227, reviewed/approved) — also fixed
      miner + import dropping the field before upsert. **Open (HITL): apply migration
      `2026-10-05-add-products-uk-sales-rank-drops30.sql` live BEFORE deploying, then
      deploy, then one overnight read-only check.** CONTRACTS.md §2 entry added.*
      *2026-10-07: migration confirmed live; code deployed (VPS alchemist-v2 6f32a15, was
      467b137 — 21+ commits behind, incl. the 038 eanList fix). Remaining: overnight check.*
- [ ] **R6. `alchemist-v2/issues/040-sp-api-pre-screen-before-keepa-mine.md`** (AFK) —
      was L2. Phase 1 (EAN with no UK ASIN → no token) first; Phase 2 only on
      measured evidence. Blockers: none.
      *2026-10-06 blocked: Phase 1 is built and review-fixed (dark, `MINER_SP_PRESCREEN_MODE`
      default off) but sits uncommitted in alchemist-v2 since 2026-10-05 21:18. The overseer
      won't adopt another session's dirty work: operator confirms it's finished, then land it.*
      *2026-10-06: tests run on operator request — 379/379 green. Commit not made (outside
      what was asked; the commit was blocked by a permission check). Operator: say "commit R6"
      to land it, then set `MINER_SP_PRESCREEN_MODE=shadow` on the server.*
      *2026-10-07: committed (alchemist-v2 6f32a15), pushed, deployed by operator (dark).
      Operator: set `MINER_SP_PRESCREEN_MODE=shadow`, restart, review a night's stats.*
- [ ] **R7. Close out the E4 pilot** (HITL, operator) — was E4, last touched
      2026-07-27. Confirm the 12-hour rotation env vars went live on the VPS in
      both repos, record the final hit rate, and tick E4 with the standing
      decision. `Alchemist_Dashboard/issues/014` closes with it. Blockers: none.
      *2026-10-07: rotation env confirmed live on the VPS in both repos (miner 20–08,
      DealFinder pause 20–08). Remaining: record the final hit rate, close.*

### Then — decisions and features

- [ ] **R8. Arbisource export gating** (HITL) — was K3, root `issues/006`. Now
      unblocked: `gating_status` has data and the dashboard reads it anon (R2).
      Remaining question: filter the export on `gating_status`, and what to do with
      ASINs that have no row. Blockers: R2.
- [ ] **R9. `DealFinder/issues/047-velocity-floor-shared-across-signals.md`** (HITL,
      investigation) — was L5. Read issue 005's floor-tuning outcome first.
      Blockers: none; its optional `products` write needs R5.
      *2026-10-06: investigated (DealFinder 3e4fe26) — 005 never tuned the floor; the 50 is
      the untuned PRD default and the rank-drops branch passes 79/229k. Recommends a
      separate `VELOCITY_FLOOR_RANK_DROPS` defaulting to 50. Awaiting operator decision.*
- [ ] **R10. `alchemist-v2/issues/041-slim-records-for-low-velocity-products.md`**
      (HITL) — was L4. Operator picks the rank-drops threshold and the re-check
      interval. Blockers: R5 plus one mine cycle of data, and R1 (on Pro this
      shrinks to the re-check-interval half).
- [ ] **R11. `alchemist-v2/issues/028-requeue-does-not-clear-not-found-marker.md`**
      (HITL, product call) — should a deliberate dashboard re-queue override the
      90-day not-found marker? Cheap once decided. Blockers: none.
- [ ] **R12. Qogita auto-sync flip** (HITL, operator) —
      `Alchemist_Dashboard/issues/015` Phase 6 (G6's deferred flip). Pre-flip:
      add `wholesale-sync` to the dashboard's `KNOWN_STAGES`
      (`src/pipeline-status.ts`; `analytics` is missing there too). Hold if R1 lands
      on "stay free" — each sync grows the DB. Blockers: R1.

- [ ] **R16. `DealFinder/issues/048-uk-to-uk-price-recovery-source-market.md`** (HITL) —
      UK→UK price-recovery scanner (UK buy, sell basis = 90-day buy-box average − 10%).
      Operator asked 2026-10-06 (Prime Day); agreed a slower, sliced build.
      *2026-10-06: slices 1–3 of 4 landed (DealFinder 08aae31, 7f24b01, a841977; slices 2–3
      reviewed, 456/456). UK now runs in shadow if `UK_SOURCE_MODE=shadow` + `uk` in
      MARKETPLACES, but never notifies in any mode yet. Slice 4 left: UK Discord format,
      products-upsert, dashboard £, CONTRACTS.md §4 units. Then HITL: live UK feed
      recording to confirm avg[3][18], ≥3 days shadow, operator economics decisions.*
      *2026-10-07: slice 4 landed (DealFinder 385d63c, reviewed APPROVE, 503/503): UK notify
      (on only), dashboard £, recovery-guard pre-gate, `PRICE_BAND_*_UK`, shipping config
      validation; CONTRACTS.md §4 amended. Build complete on branch `free-first-funnel`
      (pushed); VPS runs `main`. **Next (operator):** merge to main + deploy with
      `UK_SOURCE_MODE=shadow` and `uk` in MARKETPLACES (suggest `FEED_PAGE_CAP_UK=2`); one live
      UK feed check of avg[3][18]; ≥3 days shadow review; economics calls; DealFinder 049
      (per-market notify baseline / dismiss scope) before `on`.*

- [ ] **R17. Clothing/footwear exclusion trial** (HITL, review ~2026-10-14) — operator call
      2026-10-07: sized items passed on a variation family's shared sales rank, plus return
      risk. `EXCLUDE_CATEGORIES_<M>` (83 de / 75 fr / 62 it / 71 es / 83 uk leaf nodes) live on
      the VPS since 17:54 UTC; variation-child label in Discord + `variationPasses` funnel
      count deployed (DealFinder 8706ca9). Review: passes/notifications per day vs 10-07,
      residual apparel, non-apparel winners filling the gap; then keep/revert and decide
      DealFinder issue 050 (reject unproven variation velocity). Blockers: a week of data.
      *2026-10-08: first runs — zero apparel among EU passes; but 5 of 7 passes at 18:14
      were variation children that were good buys (shavers, headsets, watch, luggage), which
      argues against 050's reject rule. Same day: miner cron fixed to Europe/London
      (alchemist-v2 f81375a, deployed) — it had run 21:00–08:45 UK, colliding with
      DealFinder 08:00–09:00 and idling 20:00–21:00.*

- [ ] **R18. Turn UK Discord alerts on** (HITL, operator) — `UK_SOURCE_MODE=on` in
      DealFinder's VPS `.env`, then restart. Operator call 2026-10-08 (don't wait the full 3
      days of shadow; first shadow pass, Glorious GMMK 3 Pro keyboard £69.99 → basis £151.56,
      38% ROI, looked right). Accepted risk: DealFinder 049 (shared per-ASIN notify
      baseline). Optional `ROI_FLOOR_UK` (per-market override exists) if 30% proves too
      strict — ~90 shadow pre-screen rejects sat at 1–29%.
- [ ] **R19. KeepaCompanion 002 + 003** (HITL) — Google search button per Product Finder
      row (EAN-first query, stamps Searched), then Google in a reused popup docked beside
      Keepa (can't be iframed). Blockers: none (003 after 002).
- [ ] **R20. `alchemist-v2/issues/043-realised-net-roi-per-lot.md`** (HITL, grill first) —
      realised net ROI per lot from the SP-API Finances API (fees, refunds, VAT), then a
      dashboard "how am I getting on" view. Today's lot ROI is gross and analytics hasn't
      run live since 2026-07-21. Blockers: BuySheet SKUs on real purchases; after 042.

### Anytime — cheap AFK filler

- [x] **R13. `alchemist-v2/issues/035-bug-architecture-md-missing-analytics-wholesale-tables.md`**
      (AFK, docs) — also add `gating_status` while in there. Blockers: none.
      *2026-10-05: landed (alchemist-v2 51bd874, cf817be) — added `analytics_cache`,
      `wholesale_sync_requests`, `gating_status`, `asin_tracker`. ARCHITECTURE.md's
      Module map is also stale (stage list) — noted in the commit, not filed.*
- [ ] **R14. `alchemist-v2/issues/037-lot-order-history-incremental-cache.md`** (AFK) —
      analytics run time grows with lot age; not urgent until lots age.
      Blockers: none.
      *2026-10-05: landed (alchemist-v2 22111c9) — per-lot monotonic watermark + overlap
      dedupe; reviewed 2 rounds (fixed a reproduced double count and Pending-order
      undercount). CONTRACTS.md §2 fields added. Follow-ups: alchemist-v2 issue 042.
      Deploy is ordinary (no migration); first run after deploy full-scans every lot once.*
- [ ] **R15. Close root `issues/005`** (HITL, operator) — only open thread is
      "who ran the 2026-07-15 load"; accept as unknown and move to `done/`.
      Blockers: none.

## Phase A — keystone bugs and safety (all AFK)

- [x] **A1. `alchemist-v2/issues/017-bug-run-log-not-written.md`** (bug, major) —
      no stage writes `run_log`; the dashboard pipeline card renders nothing real.
      Unblocks Dashboard 012 and root 002. Blockers: none.
      *2026-07-15: landed (alchemist-v2 `7a0e170`) — new `run-log.js` `withRunLog`
      wraps every stage in BOTH dispatchers (scheduler.js is the real production
      path, not index.js); canonical names incl. `housekeeping`, `full` = child rows
      only, `failed` status on throw, dry-run writes nothing; 94/94 tests. Live rows
      appear once the server pulls the commit (A3/C2 verify).*
- [x] **A2. `alchemist-v2/issues/020-bug-dry-run-spends-keepa-tokens.md`** (bug, major) —
      `--dry-run` fires real Keepa calls in `mine`/`import` (already burned ~350 tokens
      once). Land before any live-verification session tempts a casual stage run.
      Blockers: none.
      *2026-07-16: landed (alchemist-v2 `36084f3`) — dry-run now stops before the first
      paid Keepa call in both stages (mine: after candidate selection; import: after
      sheet validation, which also skips SP-API). No spend-but-don't-write mode added.
      96/96 tests, proven red first. Safe to dry-run as a check once the server pulls
      the commit — until then the deployed code still spends.*
- [x] **A3. root `issues/003-live-service-check-runbook.md`** — `VERIFICATION.md`
      runbook; also answers the open "is `scheduler.js` actually deployed anywhere?"
      question that gates Dashboard 007/root 002. Blockers: none.
      *2026-07-16: landed — VERIFICATION.md written, all Tier-2 checks executed live
      (read-only). Scheduler question ANSWERED: deployed and alive (commands worker
      13 min fresh) but running pre-`7a0e170`/`36084f3` code — run_log still legacy-only,
      live dry-run still spends. Host undocumented (operator TODO in §2.2). Side
      discovery → root issue 005: 738k pending bulk-loaded commands (2026-07-15),
      ~86% failing on stripped-leading-zero UPCs; makes E1/E2 urgent, needs operator
      confirmation before Phase E proceeds.*
- [x] **A4. `Alchemist_Dashboard/issues/012-pipeline-stage-key-alignment.md`** —
      card must match the real producer stage names (`scout` not `ungating`, add
      `commands`). Blockers: A1 (needs the landed producer names as fact).
      *2026-07-16: landed (Alchemist_Dashboard `8e0a820`, on its existing
      `wholesale-700k-backfill-plan` branch) — `KNOWN_STAGES` is now exactly the
      five canonical producer names incl. `scout` + `commands` + `housekeeping`;
      `ungating`/legacy `wholesale` fall through the `known:false` drift alarm.
      98/98 tests, typecheck green. C2's pipeline-card leg is unblocked.*

- [x] **A5. `DealFinder/issues/032-bug-zero-passes-since-funnel-widening.md`** (bug,
      major) — zero funnel passes / Discord hits since the 07-11 widening (028–031)
      despite 10x evaluation volume; `monthlySold` ~99% n/a so velocity runs on
      `salesRankDrops30` alone. Prioritised 2026-07-16 (operator call): every day
      unfixed is a day of zero deal hits plus Keepa spend on a degenerate pool.
      Blockers: none. (Committed in DealFinder as `29b40c7`.)
      *2026-07-16: landed (DealFinder `49c1906`) — root cause: 029 cache pre-filter's
      flat-150p shipping overtaxed light items ~9 ROI pts vs the live weight-based
      rate, rejecting real winners (proven against the 07-10 PopSockets pass:
      est 25.5% vs live 34.1%); fixed to charge basePence (optimistic bound).
      `monthlySold` n/a is genuine Keepa coverage (Amazon "50+ bought" badge floor —
      min observed 50, never below). Budget-starvation/ordering defect logged as
      DealFinder issue 033 (HITL). Fix inert until the VPS pulls the commit —
      operator deploy needed (PM2, DealFinder ops runbook).*

## Phase B — docs hygiene (AFK, cheap, any order)

- [x] **B1. `alchemist-v2/issues/018-bug-claude-md-rls-note-stale.md`** (bug, minor) —
      "RLS is disabled" line actively misleads fresh sessions. Blockers: none.
      *2026-07-16: landed (alchemist-v2 `b6aa0ee`) — CLAUDE.md and ARCHITECTURE.md
      (same stale sentence) now state RLS is on everywhere, service_role bypasses,
      anon needs grant + policy, pointing at CONTRACTS.md §2/§3 for per-table state.
      Side spot → alchemist-v2 issue 025 (minor): ARCHITECTURE.md still lists
      `commands` as dropped / omits it from the live table list.*
- [x] **B2. root `issues/004-claude-md-constellation-sections.md`** — Constellation
      section in each repo's CLAUDE.md + root README pointer. Blockers: none
      (CONTRACTS.md exists).
      *2026-07-16: landed — Constellation section added to all three repos' CLAUDE.md
      (alchemist-v2 `f65b3fc`, DealFinder `4cbf715`, Alchemist_Dashboard `9e8c6f9` on
      its existing `wholesale-700k-backfill-plan` branch) + root README "Start here"
      block. Pointers + one-liners only, no contract text duplicated; all three test
      gates green.*

## Phase C — live verification (HITL — operator in the loop)

- [x] **C1. `alchemist-v2/issues/019-bug-ungate-log-anon-grants-overbroad.md`**
      (bug, minor) — one live `REVOKE` on `ungate_log`, then read-only re-verify.
      Blockers: none.
      *2026-07-16: landed (alchemist-v2 `8f9ba1d`) — `revoke all on public.ungate_log
      from anon, authenticated;` applied live with operator go-ahead; re-verified
      read-only (zero anon/authenticated grants remain, service_role untouched).
      `scout_log` confirmed clean. No CONTRACTS.md change (§3 already said no anon
      access). Root cause noted in alchemist-v2 CLAUDE.md: Supabase default privileges
      give every new public table full anon grants — service-role-only tables need an
      explicit revoke at creation.*
- [x] **C2. root `issues/002-e2e-queue-verification.md`** — the live queue → claim →
      enrich → pipeline-card pass. Closing this also satisfies Dashboard 007's last
      open criterion — treat C2/C3 as one session. Blockers: A1, A4 (card leg only;
      queue legs can run early). Needs A3's answer on scheduler deployment.
      *2026-07-16 in progress: queue→claim legs verified live (EAN 3017620422003
      queued 14:07:44Z anon, claimed+done 14:15:00Z, bare row per contract, card
      shows the Commands run). Two legs remain: card's `mine` row (first one lands
      tonight ≥21:15 UK — deploy postdated last night's window) and enrichment —
      which CANNOT happen "next window": queued EANs sort last behind a 54k-row
      miner treadmill (~6 nights). Logged alchemist-v2 026 (monthly_sold
      completeness treadmill, major) + 027 (queued EANs enrich last, major) +
      023 data note, commit `660439b`. Recommend slotting 027 before closing C2.*
      *Same day, operator "agree fix": alchemist-v2 027 LANDED (`2e8a88a`, 101/101) —
      bare inserts now write `last_mined_at NULL` (never-attempted) and the miner
      enriches never-attempted rows first, ahead of the deal tie-break (needed:
      `has_current_deal` is a sticky true on 94.7% of rows → DealFinder issue 034
      logged, `7641153`). CONTRACTS.md §2 updated. To finish C2/C3: operator deploys
      `2e8a88a` before ~20:00 UTC + one-row null of the test row's timestamp, then
      next-morning read-only check (enriched row + mine on card).*
      *2026-07-17: **done** — deploy + null confirmed by observation: the miner
      attempted the queued EAN in the FIRST run of the window (21:02:18Z touch; 027
      works), but Keepa skipped it (no UK match for the French-market GTIN, or
      validation fail — indistinguishable read-only; visibility gap = alchemist-v2 023).
      Same run enriched 1,153 rows; first canonical `mine` run_log rows landed and are
      anon-visible (card leg met). Operator accepted criterion 3's attempted-touch arm
      over a 1-token probe / second EAN round. Issue moved to `issues/done/`.*
- [x] **C3. `Alchemist_Dashboard/issues/007-wholesale-server-paired.md`** — only the
      enrichment-half criterion remains; record the C2 observation and move to done.
      Blockers: C2.
      *2026-07-17: done — C2 observation recorded in the issue (scheduler confirmed
      deployed, queued EAN attempted first-in-window, `classifyEanFreshness` renders
      the correct "Queued" state for a skipped EAN; the visible Queued→Enriched flip
      awaits alchemist-v2 023 or a Keepa-matchable EAN). Moved to `issues/done/` on
      the `wholesale-700k-backfill-plan` branch.*

## Phase D — quick feature win

- [x] **D1. `Alchemist_Dashboard/issues/005-ungating-opportunities.md`** — read-only
      section on the Deals tab. Its stated blocker (anon SELECT grant on
      `ungating_opportunities`) is **already satisfied live** per CONTRACTS.md §3
      (verified 2026-07-15) — startable now despite the HITL label.
      *2026-07-17: landed (Alchemist_Dashboard `7d0ef4c`, on its existing
      `wholesale-700k-backfill-plan` branch) — pure `ungating.ts` + read-only Deals-tab
      card; the table's only dashboard reference is one GET. Anon surface re-verified
      as-anon (SELECT only; 10,887 live rows). Live check caught the `+00` timestamp
      gotcha on `last_seen` pre-ship — normalised at the shaping edge; gotcha
      generalised in that repo's CLAUDE.md (applies to every timestamptz via REST,
      invisible to Vitest/node). 107/107 tests, typecheck+build green. No HITL step
      remained (grant shipped in DealFinder's 2026-07-02 create migration). Note:
      newest `last_seen` is 2026-07-10 — parking resumes when the funnel flows again
      (DealFinder 032 deploy watch / 033).*

## Phase E — 700k catalog backfill (Dashboard issue 014 is the coordination record)

- [x] **E1. `alchemist-v2/issues/021-commands-batch-limit-raise.md`** (AFK) — Phase 1,
      worker drain 50 → ~500. Blockers: none.
      *2026-07-17: landed (alchemist-v2 `26c6f23`) — BATCH_LIMIT 500 (48k/day), per-row
      loop kept (isolation is a criterion; ~500 round-trips well under a minute per
      run). Criterion 3 exposed and fixed two latent defects: a false-returning
      `upsertBareProduct` was still marked done, and one thrown row killed the whole
      remaining batch. 3 new tests red-first, 104/104. Deploy-gated as usual;
      CONTRACTS.md §2 batch wording updated in this commit.*
- [x] **E2. `alchemist-v2/issues/023-not-found-marker.md`** (AFK) — Phase 3 brought
      forward: dead EANs must leave the candidate pool before any bulk mining.
      Blockers: none.
      *2026-07-17: landed (alchemist-v2 `2957789`) — `uk_not_found_at` column applied
      LIVE (additive/nullable, migration `add_products_uk_not_found_at`; safe ahead of
      deploy, and required before it). Genuine Keepa not-found → 90-day park, lowest-
      priority re-entry; validation failures keep the 30-day touch; enrichment clears
      the marker; dead tail also excluded at the DB fetch. 112/112 tests (8 new,
      red first). CONTRACTS.md §2 updated in this commit. Effect deploy-gated as
      usual. Follow-up: alchemist-v2 issue 028 (HITL) — dashboard re-queue of a
      marked EAN is a silent 90-day no-op; operator to place it in this queue.*
- [x] **E3. `alchemist-v2/issues/022-bulk-catalog-loader.md`** (HITL) — Phase 2 script;
      build is safe, the live 700k load is the human call. Blockers: E2 should land
      before the *mining* that follows the load.
      *2026-07-17: landed (alchemist-v2 `bf75749`) — `bulk-load-catalog.js`: dry-run by
      default, `--execute` to write; repairs the 11-digit stripped-zero UPCs behind the
      07-15 load's ~86% failure rate (root 005's fix); insert-only, can never modify an
      existing row; bulk rows stamped `last_mined_at` = load time (NOT null) so
      user-queued EANs keep 027's front-of-queue slot. 35 new tests red-first, 147/147;
      dry-run verified live read-only. The live 700k load was NOT run — operator's
      call (E4); invocation recorded in the issue. No deploy needed (direct CLI, no
      Keepa). CONTRACTS.md §2 writers list updated in this commit.*
      *Same day, operator go-ahead: **live load executed** — 742,470 rows inserted,
      0 failed, 1,787 pre-existing untouched; `products` now 810,306 (verified live).
      Two real-file defects fixed red-first pre-write (OOM → streaming; MySQL-style
      `\"` escapes swallowing 438k rows), alchemist-v2 `d6cf8f7`+`b3e53c5`+`c8fb127`,
      all pushed. Root 005's re-load is thereby done. Follow-up: alchemist-v2 029
      (miner candidate fetch pages ~790k rows/run — land before/early in E4).*
- [x] **E3b. `alchemist-v2/issues/029-bug-miner-candidate-fetch-unbounded-at-700k.md`**
      (bug, major, AFK) — slotted 2026-07-17 (operator call, per E3's follow-up note):
      post-load the miner paged the full ~790k-row pool (~790 REST calls) every 15-min
      run; must land before the E4 pilot repeats that ~96×/day.
      *2026-07-17: landed (alchemist-v2 `ab4086a`, pushed) — `getBackfillCandidates`
      takes a `maxRows` cap; miner passes 5× the run's token budget (~2 pages for a
      300-token run). Safe for 027's null-first priority via the DB's nullsFirst
      order; 023 exclusion unchanged; 5 new tests red-first, 159/159. Deploy-gated —
      server should pull before the pilot starts.*
- [x] **E4a. `alchemist-v2/issues/026-bug-miner-monthly-sold-completeness-treadmill.md`**
      (bug, major, AFK) — slotted 2026-07-17 (operator chose "prep, then full pilot"):
      ~30,445 enriched-but-`monthly_sold`-null rows sort ahead of the 742k bulk cohort
      and re-mine on a ~3-day cycle; landing this saves ~30k pilot tokens and lets the
      pilot measure the catalog, not the old pool. Blockers: none.
      *2026-07-20: landed (alchemist-v2 `939ea0f`) — dropped `monthly_sold` from
      `hasCompleteUkSignal` entirely (DealFinder issue 032: its absence is genuine,
      permanent Keepa coverage for ~94% of the catalog, not a fillable gap); a
      complete-but-`monthly_sold`-null row now respects the 30-day staleness horizon
      instead of being an unconditional tier-0 candidate forever. `db.js`'s
      `getBackfillCandidates` OR filter updated to match (dropped its own
      `monthly_sold.is.null` clause) so the bounded fetch window (issue 029) isn't
      spent on rows the in-memory selector now discards. 2 new tests red-first,
      161/161. Criterion 2 (live tier-0 pool count drop) is deploy-gated — needs the
      server to pull this commit before it's observable; not measured this session.*
- [x] **E4b. `alchemist-v2/issues/030-miner-window-env-tunable.md`** (AFK) — filed +
      slotted 2026-07-17: env-tunable miner cron window (defaults reproduce the §5
      overnight split; `start === end` = all-day) so the pilot doesn't hand-edit
      scheduler.js on the server. Blockers: none.
      *2026-07-20: landed (alchemist-v2 `6e09d79`) — new `miner-schedule.js`'s pure
      `minerCronExpressions(startHour, endHour)` (end-exclusive, matching DealFinder's
      `OVERNIGHT_PAUSE_*_HOUR`); `config.js` plumbs `MINER_WINDOW_START_HOUR`/`_END_HOUR`
      (defaults 21/5); `scheduler.js` derives its miner cron(s) from it instead of two
      hardcoded expressions — defaults reproduce today's split exactly. 8 new tests
      red-first, 169/169. CONTRACTS.md §5 updated same commit as this tick. Deploy-gated
      as usual; server needs this commit before the pilot can flip to all-day via env
      var alone. E4 now needs only the operator's deploy + go-ahead (all of E1-E3, E3b,
      E4a, E4b are landed).
- [→ R7] **E4. `Alchemist_Dashboard/issues/014-...` Phase 4 pilot** (HITL, business
      decision) — pause DealFinder, 2–3 day pilot, measure hit rate, then decide.
      Blockers: E1–E3, E4a, E4b, and the A2 dry-run fix.
      *2026-07-17 prep decision (operator): full pilot after E4a/E4b land + operator
      deploys tip and PM2-stops DealFinder. Baseline + runbook recorded in issue 014
      Phase 4 status: 742,933 bare rows live; ~63k old rows ahead of the cohort;
      `uk_not_found_at` on 0 rows so E1/E2/E3b are NOT yet deployed (server on
      `2e8a88a`); DealFinder has 0 hits since the 032 fix, so the pause costs no
      observed deal flow but suspends the ~07-23 watch until the pilot ends.*
      *2026-07-20: **pilot started** — operator deployed alchemist-v2 tip (`6e09d79`+),
      set the miner window all-day, restarted the scheduler, PM2-stopped DealFinder.
      Verified live: first all-day `mine` run 15:00:00 UTC (daytime, confirms the new
      window is active), completed, 0 errors. Baseline: `products` 845,390 total, 461
      `uk_not_found_at`-marked. DealFinder's stop is operator-confirmed only (no VPS
      access this session). Measurement (sample ≥5,000 EANs from
      `catalogue_export_2026-07-13_155814.csv` against live row state) due
      ~2026-07-22/23 — full detail in the issue's new "Pilot started" section.*
      *2026-07-23: measurement done (Alchemist_Dashboard `1e2c2ff`) — exact full-
      population read via the Supabase REST API (read-only, service-role key): 83,082
      EANs attempted since pilot start out of 847,274 total rows (~2.8 elapsed days),
      **70.3% hit rate** (58,430 hits; 12.0% genuine not-found, 17.7% validation-fail).
      Cross-checked against a 5,500-EAN sample from the root catalogue CSV (consistent).
      At the ~29.9k/day pace, the remaining ~764k rows would take ~25.6 more days.
      **Operator decision: continue the pilot, reassess Monday 2026-07-27.** Not ticked
      done yet — pilot still running, no go/no-go finalised.*
      *2026-07-27 (Monday reassessment): live re-check found hit rate declining —
      59.5% cumulative (214,395/850,510 attempted), ~52.7% marginal over the last 4
      days, down from 70.3%. Side finding: `products`' row growth since 07-23 traced
      to a real bug (alchemist-v2 issue 038, logged not fixed — miner writes Keepa's
      `eanList[0]` instead of the queried EAN, producing phantom duplicate rows and
      leaving the original candidate stuck un-marked). **Operator decision: switch to
      a 12-hour miner/DealFinder rotation** (miner 20:00–08:00 UK, DealFinder
      08:00–20:00 UK) rather than fully stopping or continuing the full pause — both
      repos' existing env-tunable windows (alchemist-v2 030, DealFinder 031) already
      support this with no code changes. Operator TODO on the VPS (not done this
      session, no VPS access): set `MINER_WINDOW_START_HOUR=20`/`_END_HOUR=8` in
      alchemist-v2, `OVERNIGHT_PAUSE_START_HOUR=20`/`_END_HOUR=8` in DealFinder,
      `pm2 start` DealFinder + restart both. Still not ticked done — pilot continues
      under the new rotation; next reassessment once a few rotation days have run.*

## Phase G — Qogita catalog sync (`Alchemist_Dashboard/issues/015-qogita-catalog-sync.md`
is the coordination record)

- [x] **G1. alchemist-v2 Phase 1 — Qogita API client** (`qogita-api.js`: login, async
      catalog-download submit, webhook-envelope parsing; tested against stubbed HTTP).
      Blockers: none. Per-repo issue not yet filed — file from issue 015 Phase 1 when
      started.
      *2026-07-20: landed (alchemist-v2 `467b137`, filed as issue 032) — `getToken`
      (cached bearer, 50min TTL), `requestCatalogDownload` (typed
      `QogitaWebhookNotRegisteredError` on `400 no_webhook_subscriber`),
      `parseWebhookEnvelope` (pure, both event types). `config.js` gained
      `qogitaEmail`/`qogitaPassword`/`qogitaApiBase`, optional, outside the required-vars
      gate. 14 new tests red-first (incl. the repo's first direct `loadConfig()` test),
      183/183; no real Qogita network call made. Next: Alchemist_Dashboard issue 015
      Phase 2 (request table + webhook receiver).
- [x] **G2. Alchemist_Dashboard Phase 2 — request table + webhook receiver** (new
      `wholesale_sync_requests` table; first Supabase Edge Function in this codebase,
      `qogita-catalog-webhook`). HITL: operator must register the deployed function's
      URL with Qogita's own webhook subscription UI before Phase 4 can run — mechanism
      isn't documented anywhere in code. Blockers: none, can build alongside G1.
      *2026-07-20: build landed (Alchemist_Dashboard `dc2c901`, filed as issue 016) —
      migration `20260720130000` applied live (anon SELECT+INSERT only, verified as
      the anon role; a non-`pending`/non-null-`catalog_request_id` insert is RLS-
      rejected; no new `get_advisors` findings) and `qogita-catalog-webhook` deployed
      live (`verify_jwt:false`, its own `?token=` auth). 122/122 tests (15 new),
      typecheck green. CONTRACTS.md §1/§2/§3 updated same commit (root). **Left open**
      (issue 016 stays unresolved on this): no MCP tool sets Edge Function secrets, so
      `QOGITA_WEBHOOK_TOKEN` is unset and the deployed function fails closed; operator
      still needs to generate+set that secret and register the function URL (recorded
      in issue 015) with Qogita's account UI before Phase 3/4 can do anything real.*
      *2026-07-20, same day: **auth model was wrong, not just unset.** Operator supplied
      Qogita's real webhook docs mid-session — there is no account-UI registration step
      (it's `POST /public/webhooks/`, alchemist-v2 `852c3f1`'s new `createWebhookEndpoint`
      + `register-qogita-webhook.js`), and delivery auth is Qogita's own HMAC
      (`X-Qogita-Signature`, verified against a one-time `signingSecret`), not a
      self-invented `?token=`. Also caught: `parseWebhookEnvelope` checked `event` but
      the real field is `type` — every genuine delivery would have silently failed to
      parse even after auth passed. Corrected + redeployed live same session
      (Alchemist_Dashboard `923cbb0`): 126/126 dashboard tests, 185/185 alchemist-v2
      tests, typecheck green. **Still open, unchanged in kind:** operator runs
      `register-qogita-webhook.js` (own terminal, secret never through an agent
      transcript) and sets `QOGITA_WEBHOOK_SIGNING_SECRET`.*
      *2026-07-20, same day: operator ran the registration + set the secret. Verified
      live via `GET /public/webhooks/` (one endpoint, correct url/eventTypes,
      enabled). Triggering Qogita's own `POST /public/webhooks/test-event` caught a
      **second real bug**: the HMAC fix used `node:crypto`, which passed all tests
      (Node has it) but crashed every real invocation with a `500` — Supabase's Deno
      Edge Runtime doesn't reliably support `node:crypto`. Fixed with the global Web
      Crypto API (`crypto.subtle`, a true Deno built-in, global in Node since v19) and
      redeployed (Alchemist_Dashboard `2969b2e`); a direct `curl` confirmed a clean
      `403` on a bad signature (no crash). **Not independently observed:** a genuine
      signed delivery returning `200` — this session's Supabase-logs tool showed
      multi-minute-stale results throughout and never surfaced any test-event
      invocation, including ones proven delivered by the 500 itself; deferred to
      Phase 4's real pilot. Issue 016 moved to `issues/done/`.
- [x] **G3. alchemist-v2 Phase 3 — `wholesale-sync` stage** (submit + ingest legs;
      streams Qogita's CSV straight into Supabase Storage, no new catalog-data table —
      owner explicitly ruled that out 2026-07-20). Dispatched manually via `index.js`
      only, not cron'd yet. Blockers: G1, G2.
      *2026-07-20: landed (alchemist-v2 `a65f1de`, filed as issue 033) — submit leg
      claims oldest `pending` request, calls `requestCatalogDownload`, marks
      `requested`/`failed` (never stuck pending, incl. an operator-facing message on
      `QogitaWebhookNotRegisteredError`); ingest leg claims oldest `ready` request,
      streams `download_url` via new `qogitaApi.streamCatalogDownload` straight into
      new `db.uploadWholesaleCatalog` (storage-js accepts a Node readable natively —
      no buffering, issue 022's OOM lesson doesn't recur), marks `done`/`failed`.
      Manual dispatch only (`--stage wholesale-sync`), not part of `full`, not cron'd
      (Phase 6). Required a Storage bucket Phase 2 hadn't created —
      `wholesale-catalogs` (private) applied live via Supabase MCP before any code
      ran against it. 23 new tests red-first, 208/208. CONTRACTS.md updated same
      commit as this tick: §1 ownership, §2 run_log canonical stage list
      (+`wholesale-sync`, dashboard `KNOWN_STAGES` deliberately deferred to Phase 5 —
      not cron'd yet, no drift risk), §2 `wholesale_sync_requests` lifecycle + new
      Storage-ownership note. Next: G4 pilot (HITL, hand-insert one request against
      the live Qogita account + registered webhook).*
- [x] **G4. Pilot** (HITL, operator) — one real request → real webhook → real Storage
      file, run by hand. Blockers: G3.
      *2026-07-20, first attempt: submit → webhook → ready all verified real end-to-end
      (request id 3, `d20fdac2-ad86-43e2-b6eb-b9146cc7b657`, ~3m14s round trip,
      13:26:48Z → 13:30:00Z, real `download_url`). Two real bugs caught + fixed en
      route: (1) `wholesale_sync_requests` was missing a `service_role` grant entirely
      (Alchemist_Dashboard `225614c`, live migration applied) — the stage couldn't read
      or write the table at all until this landed; (2) Qogita's own docs on "empty body
      = full catalog" were wrong, real endpoint needs `{"payload": {}}` (alchemist-v2
      `41ee5d0`). **Blocked at ingest on first attempt**: real catalog CSV is ~85MB;
      this Supabase project is on the Free plan, which hard-caps Storage's global
      file-size limit at 50MB with no per-bucket override possible.*
      *2026-07-20, same day — **done**: operator chose gzip over a Supabase Pro
      upgrade (keeps Wholesale Search's "just like a manual upload" design, no
      recurring cost). alchemist-v2's ingest leg now streams through
      `zlib.createGzip()` before Storage (`41ee5d0`→`1f854bd`); a fresh real round trip
      went all the way to `done` — 85MB raw compressed to 20,578,440 bytes (~76%
      smaller), well under the cap. Real catalog: 333,511 rows, GBP decimal pricing
      (conversion note for later ingestion work). Also noted: two near-identical
      full-catalog requests ~30 min apart returned the same underlying file per
      Qogita's own `completed_at` — may indicate Qogita caches/reuses a recent
      snapshot rather than regenerating per request, worth knowing before any future
      high-frequency polling. Full trace in
      `Alchemist_Dashboard/issues/015-qogita-catalog-sync.md` Phase 4
      (Alchemist_Dashboard `2b1987c`). Job 1 (Qogita → `products` for the miner, plus
      rolling-average/price-drop alerting) discussed and deliberately parked as a
      separate follow-up — it edges close to the automated Qogita polling this
      constellation removed once already (`alchemist-v2/issues/done/003`), so it
      needs its own scoped issue/`/grill-me` rather than folding into 015. Not filed
      yet; operator to place it when ready.*
- [x] **G5. Alchemist_Dashboard Phase 5 — UI** ("Qogita Sync" mode on Wholesale Search,
      reuses the existing upload-parse pipeline unmodified). Blockers: G4 (build UI on a
      proven round trip, not a guessed shape).
      *2026-07-20: landed (Alchemist_Dashboard `8aa6df1`) — mode toggle on Wholesale
      Search; `wsSyncQogitaCatalog` inserts a pending `wholesale_sync_requests` row,
      polls to done/failed, fetches+decompresses `latest.csv.gz` from Storage, feeds
      it through a newly-shared `parseWorkbookBuffer` (pulled out of `wsHandleFile` so
      manual upload and Qogita Sync use the identical parser). New migration
      `20260720150000` (applied live): the bucket had zero `storage.objects` policies,
      so anon reads were denied — added a policy scoped to the one known object
      (`bucket_id`+`name`), verified live via a plain anon-key `curl` against the real
      G4 file (200, byte-for-byte match). 130/130 tests (4 new), typecheck+build
      green. CONTRACTS.md §2/§3 updated same commit. **Not verified**: a real
      button-click round trip — Phase 6/G6 (cron) hasn't landed, so a live click sits
      at `pending` until an operator runs the `wholesale-sync` stage by hand; browser
      click-through also unavailable this session (Chrome extension not connected).
      E4's operator decision (pause DealFinder for the 700k pilot) was raised this
      session and deferred by the operator — not yet started, still next in Phase E.*
- [x] **G6. Automate** (HITL to flip on) — cron-dispatch the stage +
      `WHOLESALE_SYNC_ENABLED` kill switch. Blockers: G5.
      *2026-07-20: landed (alchemist-v2 `9292af0`, issue 034) — worked ahead of E4 in
      queue order: E4's blockers are all formally landed but its only remaining action
      (the pilot hit-rate measurement) needs the pilot's own 2-3 day clock to elapse
      (started today, due ~07-22/23) — nothing buildable or decidable there today, so
      picked the next genuinely workable entry instead. `scheduler.js` gained a cron
      entry (`2,17,32,47 * * * *`, offset from `commands` so the two don't collide on
      one test-lookup key) that always registers but no-ops until
      `WHOLESALE_SYNC_ENABLED=true` (default false) — same rollback shape as the miner
      window (E4b/030). 6 new tests red-first, 212/212. CONTRACTS.md updated same
      commit: corrected a stale note assuming Phase 5/G5 would update
      Alchemist_Dashboard's `KNOWN_STAGES` (it didn't) and flagged that as a pre-flip
      checklist item — flipping the switch live today would produce `known:false`
      drift-alarm rows on the pipeline card, not a proper stage entry. Flip itself is
      still an operator call, deferred pending that dashboard update + the E4 pilot's
      own decision.*

## Phase F — build last

- [x] **F1. `Alchemist_Dashboard/issues/009-housekeeping-retirement.md`** (HITL) —
      retire the old matcher, `reference/old-refactor/`, `project-memory/`,
      `alchemist-server-side/`. Blockers: C3.
      *2026-07-21: done (Alchemist_Dashboard `4f7e156`+`2aed16f`; external matcher
      retired in its own TableSearch repo, `8ef88ce`, not pushed) — E4's pilot clock
      hadn't elapsed yet (same situation G6 hit on 2026-07-20), so worked the next
      genuinely workable entry instead. TableSearch matcher's Phase 1 (upload/map/
      match/filter/export) had full parity; one real gap found and ported (a "UK
      current price" column the dashboard fetched but never displayed/exported).
      Phase 2 ("Brand search," direct browser→Keepa) explicitly declined — this
      repo's own PRD already rules that out; the sanctioned equivalent is the
      existing commands-table backfill queue. Token-pacing lessons from the old
      refactor's `scan-eans.js` captured in CLAUDE.md, confirmed superseded by
      alchemist-v2's live-balance `getTokenStatus`/`TokenBudget` approach — nothing
      left to port. Deletions were the HITL step; operator approved via
      AskUserQuestion before they ran. 130/130 tests, typecheck + build clean.*
- [x] **F2. `alchemist-v2/issues/024-sp-api-analytics-stage.md`** (HITL) — scheduled
      SP-API `analytics_cache` snapshot stage. Blockers: A1; grill the scope first.
      *2026-07-21: landed (alchemist-v2 `4f9aec7`) — E4's pilot clock hadn't elapsed
      yet (started 2026-07-20, measurement due ~07-22/23), so worked the next
      genuinely workable entry instead, same reasoning F1 used. The written issue's
      scope was substantially off: a live grill with the operator found the real ask
      is a Finance-page capital-invested check (BuySheet cost basis x live FBA units),
      not the Inventory-tab FBA/orders/disbursement dump as written — settled to
      API-only partial stock value (no 3PL/prep-centre estimate: SP-API can't see it,
      and a DB-inferred ledger would drift with no self-correction), BuySheet stays
      import-only (no new status column), manual/on-request dispatch (no cron),
      single wide `analytics_cache` row per run. `analytics_cache` applied live via
      Supabase MCP (service_role + anon-SELECT grants verified live, no new advisor
      findings). 234/234 tests (22 new). CONTRACTS.md §1/§2/§3 updated same commit.
      Not yet verified: real SP-API/BuySheet response shapes, since no live SP-API
      credentials were exercised this session — flagged as the open step in the
      issue. Dashboard-side read (which tab, Finance vs Inventory) is
      Alchemist_Dashboard's own follow-up, not built here.*
- [x] **F3. `Alchemist_Dashboard/issues/008-inventory-tab.md`** (HITL) — reads what F2
      writes; explicitly "built last". Blockers: F2 (verified writing live data).
      *2026-07-21: landed (Alchemist_Dashboard `2738f37`) — F2's blocker was stale on
      inspection (its "verified against live data" criterion wasn't actually true
      yet); ran the live SP-API/BuySheet verification first (alchemist-v2 `9e64cc8`),
      catching two local-env credential gaps and confirming a real SP-API auth
      failure — very likely the same root cause as alchemist-v2 issue 031 (scout
      auto-ungate), flagged there for the operator. Scope grill matched CONTRACTS.md's
      flagged Finance-vs-Inventory ambiguity — operator chose both: a "Live check"
      line on Finance (the capital-invested ask) plus the full stock/orders/
      disbursement breakdown on Inventory (the originally-stubbed scope). 138/138
      tests, typecheck+build clean. CONTRACTS.md `analytics_cache` readers note
      updated same commit (root). Not verified via browser click-through (Chrome
      extension unavailable this session) — verified via a live anon-key curl against
      the real `analytics_cache` row instead. Side finding: `run_log`/
      `ungating_opportunities`/`analytics_cache` timestamps all now arrive from REST
      already-ISO with a colon offset, contradicting the 2026-07-16 "every timestamptz
      column arrives space-separated/colonless" note — corrected in
      Alchemist_Dashboard's CLAUDE.md.*
- [x] **F4. `alchemist-v2/issues/031-bug-scout-auto-ungate-silently-broken.md`**
      (bug, major, HITL) — slotted 2026-07-21 (operator call, prompted by F3's side
      finding): scout's auto-ungate has produced zero successes since ~2026-07-17,
      root_log silently reporting clean. Blockers: none — the HITL diagnosis half
      is now substantially done (F3 confirmed live SP-API auth was broken with
      `invalid_client` and the operator refreshed `LWA_CLIENT_SECRET`/
      `SP_API_REFRESH_TOKEN`, the same credential path `checkRestriction` uses).
      Remaining work: land the AFK visibility fix (stop swallowing the exception
      blind in `checkSample`/`maybeAttemptAutoUngate`, count it in `stats.errors`,
      write a `ungate_log` row for the failed attempt) so a future break like this
      surfaces immediately instead of silently, then confirm live once the server
      redeploys and runs scout with the refreshed credentials.
      *2026-07-21: landed (alchemist-v2 `b18bcec`) — AFK visibility fix built:
      `maybeAttemptAutoUngate` catches the thrown restriction-check error itself
      (moved from `checkSample`'s bare swallow, now removed), counts it in
      `stats.errors` (drives `withRunLog`'s `completed_with_errors`), and writes
      an `ungate_log` row (`result: 'error'`, `reason_code: err.message` — no
      schema change, no CHECK constraint on `result`). 1 new test, red first,
      235/235. Issue moved to `issues/done/` per this repo's established
      deploy-gated-close pattern; criterion 3 (live confirmation on a real scout
      run once the server pulls this commit with the refreshed SP-API
      credentials) is the one open item, not observable this session (no server
      access).*

## Phase H — DealFinder polish (worked ahead of E4, same pilot-clock-not-elapsed reasoning as F1-F4)

- [x] **H1. `DealFinder/issues/034-bug-has-current-deal-never-cleared.md`** (bug, minor,
      AFK) — slotted 2026-07-21 (operator call, via AskUserQuestion): `has_current_deal`
      was write-only-true since launch, never cleared, reaching 94.7%+ stuck-true.
      Blockers: none.
      *2026-07-21: landed (DealFinder `d419811`) — semantics: true only while the ASIN
      has a new/notified deals row on some market. Two clearing paths added (dismissed/
      expired ASIN resurfacing in-feed; post-expireDeals ASIN-wide re-check via
      reduceAsinState, so a live sibling market isn't clobbered). Live backfill applied
      matching the new predicate: 100,435 -> 12,780 true rows, zero remaining stale.
      8 new tests red-first, 253/253. CONTRACTS.md Sec 2 updated same session.*

## Phase I — new AFK work (queued 2026-07-21, found scanning child repos for unslotted issues)

- [x] **I1. `alchemist-v2/issues/025-bug-architecture-md-commands-table-stale.md`**
      (bug, minor, AFK) — ARCHITECTURE.md's "Shared Supabase" section omits `commands`
      from the live table list and implies it's still dropped; docs-only fix.
      Blockers: none.
      *2026-07-21: landed (alchemist-v2 `cf9cf64`) — E4's pilot clock (due ~07-22/23)
      still hadn't elapsed, so worked the next unblocked entry. `commands` added to the
      live table list; dropped-tables sentence now notes it was recreated, not still
      gone. Docs-only, 239/239 tests. Side finding logged, not fixed: the same section
      is also missing `analytics_cache` (F2, 2026-07-21) and `wholesale_sync_requests`
      (G2, 2026-07-20) — filed alchemist-v2 issue 035 for the follow-up.*
- [x] **I2. `Alchemist_Dashboard/issues/017-finance-tab-autofill-from-analytics-cache.md`**
      (AFK) — Finance tab's FBA/Amazon balance boxes should prefill from the latest
      `analytics_cache` row (already anon-SELECT, already fetched) instead of requiring
      manual entry each time; stays editable, auto-fill never overwrites a typed value.
      Blockers: none — `analytics_cache` is live and populated (F2/F3 landed
      2026-07-21).
      *2026-07-21: landed (Alchemist_Dashboard `120f951`) — E4's pilot clock (due
      ~07-22/23) still hadn't elapsed, so worked the next unblocked entry, same
      reasoning as G6/F1-F4/H1/I1. New `trySeedBalanceInputs`, gated on both
      `business_snapshots` and `analytics_cache` having resolved so whichever load
      wins the race never seeds `d-fba`/`d-amazon` before the other (preferred)
      source has had its say; new pure `pickBalanceFieldSeed` (4 new tests
      red-first) picks analytics over snapshot per-field. Auto-filled fields get a
      "snapshot Nh ago" label that clears on manual edit. One-line PRD addition
      (story 6a). 143/143 tests, typecheck+build clean. Not verified via browser
      click-through (Chrome extension unavailable this session).*
- [x] **I3. `Alchemist_Dashboard/issues/018-inventory-shipped-vs-not-shipped-reconciliation.md`**
      (HITL, needs `/grill-me` first) — filed 2026-07-21: owner's description of the
      desired `d-fba`/`d-waiting` auto-fill (pull Amazon inventory, cross-reference a
      spreadsheet, split shipped vs not-shipped, auto-total) doesn't match what I2
      built or anything else in this codebase. Scope unknown (which spreadsheet, what
      "shipped" means, whether it replaces or supplements I2's fields) — do not build
      from the issue's Context section alone. Blockers: none, but do the grill session
      before any implementation. Operator wants this picked up tomorrow (2026-07-22).
      *2026-07-23: grill session held (E4's pilot decision is parked until Monday
      2026-07-27, so this was the next workable entry). Real scope is much bigger than
      a two-box auto-fill: BuySheet gains a real Amazon Seller SKU per purchase batch
      going forward (legacy shared-SKU rows stay blended, not retrofitted); SP-API
      already reports per-SKU quantities so "shipped" = any nonzero bucket for that SKU
      (sold-out lots disambiguated via Orders-history presence); cost matching is
      direct by SKU, no FIFO; sold-qty inferred as purchased minus live Amazon
      quantity, self-correcting for returns; ROI's sale price must come from real
      Orders/Finance history, not `products.uk_current_price` (flagged as the biggest
      remaining unknown); no new Supabase table. Split into a two-repo phased feature
      like Qogita's G1–G6: **alchemist-v2 issue 036** (Phase 1, data side — BuySheet SKU
      parsing + per-lot SP-API matching + `analytics_cache` lot field) now blocks this
      issue's Phase 2 (Inventory-tab lot table; `d-fba`/`d-waiting` re-sourced to sum
      over lot data, `d-waiting` auto-filling for the first time). Not built this
      iteration — the grill session was the single task. Split into I3a/I3b below.*
- [x] **I3a. `alchemist-v2/issues/036-buysheet-per-lot-sku-tracking.md`** (HITL, AFK-
      buildable) — Phase 1 of I3's grilled scope: BuySheet SKU-column parsing, per-lot
      SP-API matching (shipped/waiting, sold-qty inference, mismatch flag), real
      Orders/Finance-sourced sale price, new `analytics_cache` lot field. Build can
      proceed against stubbed SP-API responses; real verification needs the operator to
      start assigning real Seller SKUs to new BuySheet purchases (their own action).
      Blockers: none structurally.
      *2026-07-23: landed (alchemist-v2 `ef06dee`) — E4's pilot decision is parked until
      Monday 2026-07-27, so this was the next workable entry. Built the full pipeline
      against stubbed SP-API responses: `sheets.js` reads new SKU/Purchase Date BuySheet
      columns (legacy rows untouched); `analytics.js` gained `buildLots`,
      `indexInventoryBySku` (reuses the existing `inventorySummaries` fetch, no extra
      SP-API call), `shapeAvgSalePrice`, `shapeLot`/`shapeLots`; `sp-api.js` gained
      `getOrdersCreatedAfter`/`getOrderItems`/`getOrderItemsForSku` (Orders API's
      order-level GET has no line items — `SellerSKU` only exists on the separate Order
      Items endpoint, a real gotcha recorded in alchemist-v2 CLAUDE.md). Mismatch rule
      confirmed with the operator before building: `qtyAtAmazon > qtyPurchased` only, the
      issue's own candidate. `analytics_cache.lot_inventory` (jsonb, nullable) applied
      LIVE via Supabase MCP, verified. 34 new tests red-first, 263/263. CONTRACTS.md §2
      updated same commit with the full shape. **Not verified live** — no real BuySheet
      SKU exists yet (operator's own action) and no real SP-API Orders call was made;
      first real verification awaits that plus a live `--stage analytics` run. Unblocks
      I3b (Alchemist_Dashboard issue 018 Phase 2).*
- [x] **I3b. `Alchemist_Dashboard/issues/018-inventory-shipped-vs-not-shipped-reconciliation.md`**
      (Phase 2) — Inventory-tab per-lot table over I3a's real `analytics_cache` shape;
      re-source `d-fba`/`d-waiting` Finance auto-fill to sum over lot data (`d-waiting`
      auto-fills for the first time). Blockers: I3a — do not build against a guessed
      lot shape.
      *2026-07-27: landed (Alchemist_Dashboard `42e62ba`) — E4's rotation just started
      (operator TODO on the VPS, not yet done, needs rotation days to elapse before the
      next reassessment), so this was the next genuinely workable entry. Built against
      I3a's real, live `analytics_cache.lot_inventory` shape: new per-lot Inventory-tab
      table (SKU, ASIN, qty purchased/at-Amazon, shipped/waiting + mismatch badges,
      cost/unit, actual-cost ROI); Finance `d-fba`/`d-waiting` re-sourced to
      `sumLotFbaValuePence`/`sumLotWaitingValuePence` (SKU-tracked lots only — a
      deliberate coverage narrowing vs the old ASIN-blended `fba_stock.totalValuePence`,
      the criterion-10-specified tradeoff, documented in that repo's CLAUDE.md so it's
      not mistaken for a bug later); `d-waiting` gains issue-017-style auto-fill for the
      first time. 12 new tests red-first, 155/155, typecheck+build clean.
      CONTRACTS.md §2 updated same commit as this tick. Not verified via browser
      click-through (Chrome extension unavailable this session) — no real BuySheet
      SKU/lot data exists yet either, so empty-state paths are what a live check would
      show today regardless. Issue moved to `issues/done/`.*

## Phase J — new AFK work (queued 2026-07-27, found during the E4 Monday reassessment)

- [x] **J1. `alchemist-v2/issues/038-bug-miner-eanlist-mismatch-phantom-rows.md`** (bug,
      major, AFK) — slotted 2026-07-27: E4's rotation just started (operator VPS TODO
      not yet done, needs rotation days to elapse before the next reassessment), so this
      was the next genuinely workable entry, same reasoning as E3b/E4a/H1/I1/I2. Miner
      upserted on Keepa's `eanList[0]` instead of the queried row's own `ean`, creating
      phantom duplicate rows and leaving the real candidate stuck un-marked forever.
      Blockers: none.
      *2026-07-27: landed (alchemist-v2 `0c16de5`) — `stage-miner.js` now upserts
      against `row.ean` always; 1 new test red-first, 267/267. Live backfill repair
      (operator go-ahead, "repair live now"): 4,671 of 5,071 live duplicate `uk_asin`
      groups matched the exact bug signature and were merged+deduped via a live Supabase
      SQL transaction (verified safe first — zero groups where a non-phantom row held
      both real signal and a newer timestamp); `products` 850,510 -> 845,861 (4,713 rows
      removed). Remaining 400 groups are a pre-existing, unrelated wholesale-catalog
      barcode-duplication quirk, left untouched. No CONTRACTS.md change (local
      implementation detail, not a contract).*

## Phase K — Keepa Companion (new repo, queued 2026-09-19)

- [x] **K1. `KeepaCompanion/issues/done/001-finder-columns-vertical-slice.md`** (HITL) —
      new fourth repo: Chrome extension adding Track / Searched / Gate columns to the
      Keepa Product Finder, plus `asin_tracker` (this repo) and alchemist-v2's
      `gating-check` edge function + `gating_status` cache. Blockers: none.
      *2026-09-19: built. Columns are real ag-Grid column defs injected by proxying
      `agGrid.Grid`'s constructor (Keepa keeps `gridOptions` in module scope — no
      global handle), and `api.setColumnDefs` is wrapped so Keepa's own column
      reconfigures re-append ours. Verified in a harness reproducing Keepa's exact load
      pattern: columns inject, survive a full column-set replacement without
      duplicating, toggle/stamp/clear correct and per-ASIN. 36 tests here + 19 in
      alchemist-v2 (284/284 there), typecheck green. `asin_tracker` and `gating_status`
      created live; anon contract verified against the real key (upsert ok, bad status
      rejected by CHECK, `gating_status` permission denied, DELETE 401). CONTRACTS.md
      §1/§2/§3 amended — including the first sanctioned synchronous browser→server
      SP-API path, and a plain statement of why `ungate_log` cannot serve as a gating
      cache. Coordination record: root `issues/007`.*

- [→ R3] **K2. Operator: enable the Gate column** (HITL, operator-only) — set the
      `gating-check` secrets (`LWA_APP_ID`, `LWA_CLIENT_SECRET`, `SP_API_REFRESH_TOKEN`,
      `SP_API_MERCHANT_ID` from alchemist-v2's server `.env`, plus a chosen
      `KC_SHARED_SECRET`), put the same shared secret in the extension options, load the
      unpacked `dist/`, and confirm the three columns against the live Product Finder.
      Until this is done the function fails closed (HTTP 500) and Gate stays blank.
      Blockers: none — the secrets simply are not in the build environment.
      Detail: root `issues/007`.

- [→ R8] **K3. Re-read `issues/006` against `gating_status`** (HITL) — 006 asked how to
      expose gating ground truth to the browser; its option 2 (service-role edge
      function) is now built, with a purpose-built cache behind it. The open part is
      narrower: should the Arbisource export read `gating_status`, and what does it do
      about ASINs with no row yet? Blocked by K2 (the table stays empty until the
      function can run).

## Phase L — Keepa token and `products` size (queued 2026-09-25)

Context: DB at 472 MB of the 500 MB free cap (live 2026-09-25). Only 16,680 of 890,691
enriched `products` rows carry `monthly_sold` (all >= 50 — it is Amazon's badge), so
velocity needs `salesRankDrops30` as a fallback, which `products` does not store yet.

- [→ R5] **L1. `alchemist-v2/issues/039-store-sales-rank-drops30-on-products.md`** (AFK) —
      add nullable `products.uk_sales_rank_drops30`, written by `upsertProduct`. Already
      parsed by `keepa.js`, currently discarded; no extra tokens. Blockers: none.
- [→ R6] **L2. `alchemist-v2/issues/040-sp-api-pre-screen-before-keepa-mine.md`** (AFK) —
      free SP-API check ahead of the miner's Keepa lookups. Phase 1: EAN with no UK ASIN
      → `markNotFound`, no token (~12% of pilot spend). Phase 2 (buy box / fees) only
      if a sample shows it catches enough of the 17.7% validation-fails. Not an ROI
      gate — the miner has no buy cost. Blockers: none.
- [→ R1] **L3. `alchemist-v2/issues/038-products-growth-and-bulk-load-cohort.md`** (HITL,
      operator decision) — Pro plan vs retire the bulk-load cohort vs cap DealFinder's
      `products-upsert` intake (~4.9k rows/day, the real growth source). Blockers: none.
- [→ R10] **L4. `alchemist-v2/issues/041-slim-records-for-low-velocity-products.md`** (HITL)
      — below-bar rows keep a narrow record and a 90–180 day re-check instead of the
      full row and 30-day re-mine. Operator picks the rank-drops threshold (calibrated
      from L1 data) and the interval. Blockers: L1 (plus one mine cycle of data), L3.
- [→ R9] **L5. `DealFinder/issues/047-velocity-floor-shared-across-signals.md`** (HITL,
      investigation) — one `VELOCITY_FLOOR` of 50 applies to both `monthlySold` and
      `salesRankDrops30`; only 79 of 229k deals clear 50 on rank drops. Check issue 005
      first; reuse L4's threshold. Optional `products` write blocked by L1.

- Deferred, not in this queue: `Alchemist_Dashboard/issues/deferred/010-dashboard-hosting.md`.
  The Qogita API idea (former deferred/012) is superseded and now queued as Phase G,
  coordination record `Alchemist_Dashboard/issues/015-qogita-catalog-sync.md`.
- Each child repo is its own git repo — implementation commits land there; runlist
  ticks commit here.
- Deploy verified 2026-07-16: the server runs `36084f3`+ (first canonical `run_log`
  row observed 08:00:00Z) — `--dry-run` is spend-free live, and `run_log` recency is
  now the scheduler-liveness check (VERIFICATION.md §2.2). C2's "needs A3's answer"
  gate is satisfied.
- Root issue 005 (2026-07-16, HITL): a 742k-row bulk load into `commands` happened
  live on 2026-07-15; operator chose purge (executed same day — queue now empty).
  Re-load waits on E1 + UPC leading-zero normalisation.
- alchemist-v2 issue 031 (2026-07-20, bug, major, HITL): live weekend DB check found
  scout's auto-ungate has been silently broken since ~2026-07-17 19:00 UTC — 5,681
  attempted, 0 succeeded, 0 `ungate_log` writes over 3 days, `run_log` reporting clean
  `errors: 0` throughout (an unguarded exception is swallowed 3 frames above the log
  call). AFK visibility fix + HITL root-cause diagnosis (likely SP-API credential
  issue). Slotted 2026-07-21 as **F4** — root cause confirmed live during F3, credentials
  refreshed; AFK visibility fix still unbuilt. Same check confirmed
  E1/E2/E3b are live and working as designed (`uk_not_found_at` populating, candidate
  fetch bounded, 0 failed run_log rows all weekend) and updated E4's baseline (products
  now 841,050; the `monthly_sold` treadmill issue 026 grew to ~45.5k rows, reinforcing
  its E4a priority).
- DealFinder issue 032 promoted into the queue as A5 on 2026-07-16 (operator call) and
  committed in that repo (`29b40c7`); landed same day (`49c1906`). Its investigation
  spawned DealFinder issue 033 (screen-budget ordering / drop 25–29% dark band, HITL,
  major) — DealFinder's only open issue, not yet slotted in this queue; operator to
  place it. The 032 fix was deployed to the VPS 2026-07-16 ~12:50Z (pushed to GitHub,
  pulled + PM2 restart by operator; probe tick confirmed live 12:54Z). Watch: if no
  Discord hit lands by ~2026-07-23, reopen against issue 033's ordering options.
