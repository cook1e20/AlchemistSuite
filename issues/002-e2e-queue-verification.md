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

- [ ] A real unmatched EAN was queued via the dashboard UI using the anon key (no direct
      browser write to `products`).
- [ ] The `commands` row transitioned pending → claimed/completed by the service-role
      worker, and a bare `products` row appeared with signal columns untouched.
- [ ] After the next overnight window, the same row shows fresh Keepa signal and
      `last_mined_at` set (or a deliberate "attempted" touch if Keepa had no UK listing).
- [ ] The dashboard pipeline card showed the `commands` and `mine` stage runs from
      `run_log`.
- [ ] Observed timeline recorded in this file; every discrepancy logged as a repo-local
      issue in the owning repo.

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
