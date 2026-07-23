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
- [ ] **E4. `Alchemist_Dashboard/issues/014-...` Phase 4 pilot** (HITL, business
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
- [ ] **I3b. `Alchemist_Dashboard/issues/018-inventory-shipped-vs-not-shipped-reconciliation.md`**
      (Phase 2) — Inventory-tab per-lot table over I3a's real `analytics_cache` shape;
      re-source `d-fba`/`d-waiting` Finance auto-fill to sum over lot data (`d-waiting`
      auto-fills for the first time). Blockers: I3a — do not build against a guessed
      lot shape.

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
