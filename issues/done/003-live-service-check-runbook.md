type: AFK  <!-- writing the runbook is AFK; actually executing live checks is the operator's call -->

## Parent PRD

`issues/constellation-prd.md`

## What to build

A `VERIFICATION.md` runbook at the AlchemistSuite root that separates the two kinds of
health the PRD's "Verification contract" distinguishes — so a green local test suite is
never mistaken for proof that live services are healthy.

- **Local gates (code health), per repo:**
  - `alchemist-v2`: `npm test`
  - `DealFinder`: `npm run test` and `npm run typecheck`
  - `Alchemist_Dashboard`: `npm run test`, `npm run typecheck`, and build when UI output
    is affected.
- **Live checks (service health), read-only by default:**
  - Supabase connectivity + schema check: confirm the shared tables from `CONTRACTS.md`
    exist with expected key columns and grants (read-only queries only).
  - Process checks: the long-running alchemist-v2 `scheduler.js` on the server, and
    DealFinder's PM2 probe — how to check each is alive and when it last ran
    (`run_log` recency, PM2 status).
  - Discord: where each stage's summary lands, as a human-visible cross-check.
- **Operator-gated checks:** Keepa and SP-API live smoke tests are never routine — even
  dry-run paths may spend tokens. The runbook states they require explicit operator
  approval per run, and lists what each would prove.

Keep it a runbook (commands + what healthy looks like), not a script framework — this
root repo stays coordination-only per the PRD's third follow-up note.

## Acceptance criteria

- [ ] `VERIFICATION.md` exists at the root with the three tiers above and copy-pasteable
      commands for each check.
- [ ] Every live check in the default path is read-only; token-spending checks are
      clearly fenced behind operator approval.
- [ ] Each repo's local gate is stated exactly as its CLAUDE.md/package.json defines it
      (verified, not assumed).
- [ ] No app source files or scripts are added to this root repo.

## Blocked by

None - can start immediately (pairs naturally with `issues/001-constellation-contract-map.md`,
but does not require it).

## User stories addressed

- User story 13

## Resolution (2026-07-16)

`VERIFICATION.md` written at root with the three tiers; every Tier-2 query was executed
read-only against the live project while writing it (zero spend), so the commands are
verified, not assumed. Local gates confirmed against each repo's package.json/CLAUDE.md
(alchemist-v2 has no typecheck by design; dashboard adds `npm run build` for UI output).

**The standing scheduler question is answered: deployed and alive, but lagging.**
`commands.processed_at` was 13 min fresh, scout batched at 02:30 UTC, 20k+ enriched
rows touched in 24h — yet `run_log` has only 86 legacy `stage='wholesale'` rows (newest
2026-07-06), so the server runs pre-`7a0e170` code and therefore also pre-`36084f3`:
live dry-runs still spend Keepa tokens until it pulls. The scheduler host is not
documented anywhere in alchemist-v2 — flagged in VERIFICATION.md §2.2 for the operator
to fill in.

Side discovery logged as root `issues/005-bulk-load-queue-observed.md`: 738,848 pending
`queue_backfill_ean` commands bulk-inserted 2026-07-15 (Phase-E-shaped, but E3 isn't
built), ~86% of drained rows failing on 11-digit leading-zero-stripped UPCs, and an
unexplained +19k `products` rows. CONTRACTS.md corrected in the same commit (run_log
current state; miner writes `source='backfill-miner'`, not `'miner'`).
