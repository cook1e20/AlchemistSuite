# Constellation run list

Ordered queue for working the open issues across the constellation, one per fresh
session. Usage: `/next-task` from this root directory works the **topmost unchecked,
unblocked entry**, in the repo that owns it; `/clear` between iterations. Tick the box
(and add a one-line result note) when the issue lands.

Priorities set 2026-07-15 (constellation review). Reorder freely — this file is the
queue, not a contract. `severity: critical` bugs in any repo jump the queue regardless
of this order.

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
- [ ] **E3. `alchemist-v2/issues/022-bulk-catalog-loader.md`** (HITL) — Phase 2 script;
      build is safe, the live 700k load is the human call. Blockers: E2 should land
      before the *mining* that follows the load.
- [ ] **E4. `Alchemist_Dashboard/issues/014-...` Phase 4 pilot** (HITL, business
      decision) — pause DealFinder, 2–3 day pilot, measure hit rate, then decide.
      Blockers: E1–E3, and the A2 dry-run fix.

## Phase F — build last

- [ ] **F1. `Alchemist_Dashboard/issues/009-housekeeping-retirement.md`** (HITL) —
      retire the old matcher, `reference/old-refactor/`, `project-memory/`,
      `alchemist-server-side/`. Blockers: C3.
- [ ] **F2. `alchemist-v2/issues/024-sp-api-analytics-stage.md`** (HITL) — scheduled
      SP-API `analytics_cache` snapshot stage. Blockers: A1; grill the scope first.
- [ ] **F3. `Alchemist_Dashboard/issues/008-inventory-tab.md`** (HITL) — reads what F2
      writes; explicitly "built last". Blockers: F2 (verified writing live data).

## Standing notes

- Deferred, not in this queue: `Alchemist_Dashboard/issues/deferred/` (hosting, Qogita
  API).
- Each child repo is its own git repo — implementation commits land there; runlist
  ticks commit here.
- Deploy verified 2026-07-16: the server runs `36084f3`+ (first canonical `run_log`
  row observed 08:00:00Z) — `--dry-run` is spend-free live, and `run_log` recency is
  now the scheduler-liveness check (VERIFICATION.md §2.2). C2's "needs A3's answer"
  gate is satisfied.
- Root issue 005 (2026-07-16, HITL): a 742k-row bulk load into `commands` happened
  live on 2026-07-15; operator chose purge (executed same day — queue now empty).
  Re-load waits on E1 + UPC leading-zero normalisation.
- DealFinder issue 032 promoted into the queue as A5 on 2026-07-16 (operator call) and
  committed in that repo (`29b40c7`); landed same day (`49c1906`). Its investigation
  spawned DealFinder issue 033 (screen-budget ordering / drop 25–29% dark band, HITL,
  major) — DealFinder's only open issue, not yet slotted in this queue; operator to
  place it. The 032 fix was deployed to the VPS 2026-07-16 ~12:50Z (pushed to GitHub,
  pulled + PM2 restart by operator; probe tick confirmed live 12:54Z). Watch: if no
  Discord hit lands by ~2026-07-23, reopen against issue 033's ordering options.
