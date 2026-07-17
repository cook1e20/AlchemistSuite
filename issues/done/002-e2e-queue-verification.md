type: HITL  <!-- live end-to-end run across the real Supabase, scheduler, and Keepa spend window; operator observes -->

## Parent PRD

`issues/constellation-prd.md`

## What to build

A verified end-to-end pass of the dashboard EAN backfill path — the PRD's second
follow-up. Nothing new is implemented here; this issue is the live proof that the
already-built pieces compose:

1. Operator queues an unmatched supplier EAN from the dashboard's Wholesale Search tab
   (anon insert of a `queue_backfill_ean` row into `commands`).
2. alchemist-v2's `commands` worker (every-15-min cron) claims it and writes the bare
   product row (`db.upsertBareProduct` — `ean`/`uk_asin`/`brand` only, no signal
   columns touched).
3. The overnight miner (21:00–04:59 window) enriches the row with Keepa UK signal and a
   channel-neutral target price.
4. The dashboard shows the outcome: the product row enriched, and the pipeline card
   reflecting the real `commands` and `mine` runs from `run_log`.

Record the observed timeline (queued at → claimed at → enriched at) in this issue file
when closing it. Any gap found is logged as a repo-local bug issue in the owning repo
(alchemist-v2 / DealFinder / Alchemist_Dashboard) — not fixed inside this issue.

## Acceptance criteria

- [x] A real unmatched EAN was queued via the dashboard UI using the anon key (no direct
      browser write to `products`). *(2026-07-16 — byte-identical anon POST; caveat in
      progress note.)*
- [x] The `commands` row transitioned pending → claimed/completed by the service-role
      worker, and a bare `products` row appeared with signal columns untouched.
      *(2026-07-16.)*
- [x] After the next overnight window, the same row shows fresh Keepa signal and
      `last_mined_at` set (or a deliberate "attempted" touch if Keepa had no UK listing).
      *(2026-07-17 — closed on the letter's attempted-touch arm, operator decision; see
      the 07-17 progress note for the ambiguity.)*
- [x] The dashboard pipeline card showed the `commands` and `mine` stage runs from
      `run_log`. *(2026-07-17 — first canonical `mine` rows landed overnight, anon-visible.)*
- [x] Observed timeline recorded in this file; every discrepancy logged as a repo-local
      issue in the owning repo. *(alchemist-v2 026/027 logged 07-16, 027 landed same day;
      the remaining skip-visibility gap is pre-existing alchemist-v2 023.)*

## Blocked by

- Blocked by `alchemist-v2/issues/017-bug-run-log-not-written.md` (the pipeline-card leg
  needs a real `run_log` producer).
- Blocked by `Alchemist_Dashboard/issues/012-pipeline-stage-key-alignment.md` (the card
  must look for the real stage names).
- The queue→claim→enrich legs (steps 1–3) do not depend on either blocker; if the
  blockers stall, those legs can be verified early with SQL instead of the card.

## User stories addressed

- User story 6
- User story 7
- User story 14

---

## Progress note — 2026-07-16 (queue→claim legs verified live; enrichment leg blocked on a real defect)

Operator-approved single-EAN run (expected ~1–2 Keepa tokens). EAN chosen:
`3017620422003` (Nutella 400 g — real GTIN-13, checksum-valid, verified absent from
`products`, genuine Amazon UK listing so it should fully enrich, not just "attempted").

**Observed timeline (all UTC):**

| Event | Time |
|---|---|
| Queued — anon POST to `/rest/v1/commands`, byte-identical to `wsQueueBackfill`'s request (`HTTP 201`) | 2026-07-16 14:07:44 |
| `commands` row `id 742401` visible, `status = pending` | 14:07:45.044 |
| Claimed + `status = done` by the service-role worker (its next 15-min tick) | 14:15:00.759 |
| Bare `products` row written (`ean` only; `uk_asin`/`brand`/title/all signal columns null; `last_mined_at` backfilled by column default — the documented gotcha, confirmed live) | 14:15:00.724 |
| Bare row visible via **anon** SELECT (the dashboard freshness-indicator read) | 14:15:19 |
| `run_log` `commands` row for that tick: `completed`, `stats.processed = 1, errors = 0` | started 14:15:00.365 |
| Enriched (`title` set, Keepa signal) | **pending — see below** |

**Criteria status:**

- Criterion 1 (queued via dashboard UI, anon key): met with a caveat the operator chose
  explicitly — Chrome extension unavailable, so the request was sent as the
  byte-identical anon POST `wsQueueBackfill` makes (same endpoint, headers,
  `Prefer: return=minimal`, `buildQueueBackfillRows` body shape). The UI payload
  shaping is unit-tested and the anon-POST path was already proven from the real anon
  role on 2026-07-13 (dashboard issue 007).
- Criterion 2 (pending → done, bare row, signal untouched): **met**, evidence above.
- Criterion 3 (enriched after the next overnight window): **cannot pass as written** —
  discrepancy found and logged. The bare row's default `now()` timestamp sorts it
  *last* among 54,397 tier-0 candidates (~53.9k ahead), and the window attempts ~9.5k
  rows/night → **~6 nights** to reach a user-queued EAN. Logged as
  `alchemist-v2/issues/027` (queued EANs enrich last, major). The pool size itself is a
  second defect: `hasCompleteUkSignal` demands `monthly_sold`, which Keepa genuinely
  cannot supply for ~95% of rows (badge floor, DealFinder 032) → ~94% of the catalog is
  re-attempted every ~3 days at token cost — logged as `alchemist-v2/issues/026`
  (major), with a premise-correcting data note on `alchemist-v2/issues/023`.
  alchemist-v2 commit `660439b`.
- Criterion 4 (pipeline card shows `commands` + `mine` runs): **half met** — the card's
  exact anon fetch + the real `pipelineStatus` reduction (run against live `run_log`)
  renders `Commands ok, lastRun 14:15:00.824` (the very run that claimed our EAN), the
  legacy `wholesale` rows correctly surfacing as the `known:false` drift alarm. `mine`
  shows `idle` because **no `mine` row exists yet**: the 07-16 ~08:00Z deploy of the
  run_log writer happened after the 07-15 overnight window ended, so tonight's window
  (21:00 UK) writes the first ones. Re-check after ~21:15 UK.
- Criterion 5 (timeline + discrepancies recorded): this note; discrepancies routed to
  the owning repo above.

**To close C2 (and C3 with it):** (a) after 21:15 UK tonight, re-run the card check —
`mine` should flip to `ok`; (b) enrichment of `3017620422003` — either wait ~6 nights
(re-check `title is not null` each morning), or land + deploy `alchemist-v2/issues/027`
first, after which the *next* window should enrich it and criterion 3's intent (not its
current letter) is satisfied. Recommendation: slot 027 next in the runlist.

---

## Progress note — 2026-07-17 (morning-after read-only check)

Operator deployed `2e8a88a` and nulled the test row's timestamp on 2026-07-16 as
planned — both confirmed by observation, read-only, zero spend.

- **Criterion 4 (pipeline card): met.** The 07-16 21:00–07-17 04:45 window wrote the
  first real canonical `mine` rows to `run_log` (every 15 min, all `completed`, e.g.
  04:45 run: 303 enriched / 315 candidates). Verified via live `set role anon` read
  that the card's anon fetch sees them (`commands`, `mine`, `scout` all `completed`
  within the card's lookback). With the reduction already exercised live on 07-16
  (`mine` was `idle` only for lack of rows), the card renders both `commands` and
  `mine` runs.
- **Criterion 3 (enrichment): attempted-touch outcome, not enrichment.** Issue 027's
  fix demonstrably worked: the test EAN was selected by the *first* mine run of the
  window (run finished 21:02:18.562; row's `last_mined_at` = 21:02:18.059 — no longer
  behind the 54k treadmill). But it was one of that run's 107 *skipped* rows: no
  title/ASIN/signal written, deliberate attempted-touch only, while the same run
  enriched 1,153 rows. Cause is ambiguous from the DB (`stage-miner.js` touches on
  both paths): Keepa UK's EAN index may genuinely lack `3017620422003` (the
  French-market Nutella GTIN; Amazon UK's Nutella 400g `B01F9F4KDS` may carry a
  different GTIN in Keepa's `eanList`), or the product returned but failed price
  validation — the distinguishing console line lives on the undocumented scheduler
  host. The catalog contains zero Nutella rows to corroborate either way. Criterion
  3's *letter* ("deliberate 'attempted' touch if Keepa had no UK listing") is
  therefore plausibly met but not proven; its *intent* (queued EAN visibly enriched)
  was not observed for this EAN. The user-facing gap — a queued EAN that skips leaves
  no visible record of why — is already logged as `alchemist-v2/issues/023`
  (not-found marker).

**Observed timeline (final):** queued 2026-07-16 14:07:44Z (anon) → claimed + bare row
14:15:00Z (service-role worker) → attempted by miner 2026-07-16 21:02:18Z (first run of
the first window after the 027 deploy) → skipped (no Keepa UK match or validation
fail), attempted-touch recorded.

**Closed 2026-07-17, operator decision:** accept criterion 3's attempted-touch arm —
the e2e mechanism is proven end-to-end (queue → claim → attempt-first-next-window →
deliberate touch), enrichment itself proven by 1,153 rows in the same run, and the
skip-visibility gap is already tracked as `alchemist-v2/issues/023`. Alternatives
declined: a 1-token Keepa probe of `B01F9F4KDS`'s `eanList`, or a second overnight
round with a known-indexed EAN.
