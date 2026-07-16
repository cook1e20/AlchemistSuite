type: HITL  <!-- operator must confirm who ran the load and decide the repair/requeue path -->
kind: coordination
severity: major

## What was observed (live, read-only, 2026-07-16 — during issue 003's runbook verification)

The Phase-E 700k catalog load appears to have **already been executed** against the live
`commands` queue, outside the ralph loop (`alchemist-v2/issues/022`, the bulk loader, is
not built; RUNLIST E3 lists the live load as a pending human call):

- **738,848 `pending` rows** of `type='queue_backfill_ean'`, all inserted in one burst
  2026-07-15 13:46:13 → 13:47:05 UTC (~742k rows including the ones already processed).
- Of the ~3.5k rows the worker has drained since (50 per 15-min run), **3,089 failed
  with `invalid EAN shape: <11-digit code>`** — an ~86% failure rate so far. The codes
  are 11 digits, i.e. UPC-As with the leading zero stripped (classic
  numeric-column/Excel export damage). If the rate holds across the queue, most of the
  load fails validation in `stage-commands.js`.
- At the current drain rate (50/run × 96 runs/day ≈ 4,800/day) the queue takes
  **~150 days** to drain — RUNLIST **E1** (batch 50 → ~500) is now urgent, and **E2**
  (not-found marker) must land before the resulting mining begins, exactly as the
  RUNLIST already orders them.
- Separately: `products` is at **53,615 rows** vs ~34.8k at the 2026-07-15 CONTRACTS
  verification — +~19k rows in about a day, unexplained by the commands worker (only
  ~460 bare rows exist, `source is null`). Live source split: `backfill-miner` 26,145,
  `dealfinder` 24,400, `miner` 2,120, others small. Whatever performed the bulk load
  may also have written `products` directly — worth confirming.

## What the operator needs to decide

1. **Confirm the load**: who/what inserted the 742k rows on 2026-07-15, and was the
   source file the intended 700k catalog? (Dashboard issue 014 is the Phase-E
   coordination record — record the answer there.)
2. **The 11-digit failures**: repair-and-requeue (left-pad to GTIN-13 and re-insert),
   widen `stage-commands.js` EAN validation to accept/normalise UPC-A, or accept the
   losses. Repair belongs to whichever repo owns the chosen fix (likely alchemist-v2
   for validation, or the E3 loader for normalisation).
3. **Queue hygiene**: whether to purge the doomed pending rows rather than paying
   ~150 days of worker cycles to fail them one batch at a time.

## Blocked by

Nothing technical — blocked on operator confirmation. Feeds directly into RUNLIST
E1/E2/E3 sequencing; does not change their order.

## Progress (2026-07-16)

Operator chose **purge** (decision 3) — "we need to purge, I can get them in again."
Executed live: deleted 738,848 `pending` + 3,089 `failed` (`invalid EAN shape`) rows;
the 463 pre-existing `done` rows kept as history. Verified: `commands` now contains
only those 463 done rows.

Still open before the re-load: land E1 (batch 50 → ~500) so the queue drains in days
not months, and fix the leading-zero/UPC normalisation (decision 2) so the ~86%
failure rate doesn't repeat. Decision 1 (what performed the original load, and whether
it also wrote the unexplained +19k `products` rows) remains unanswered.
