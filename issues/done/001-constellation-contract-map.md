type: AFK  <!-- documentation + read-only live Supabase checks only -->

## Parent PRD

`issues/constellation-prd.md`

## What to build

A root-level `CONTRACTS.md` in this coordination repo: the single contract map the PRD's
"Implementation Decisions" section describes. It records the system-level promises each
project makes to the others — it does not implement anything and does not replace any
repo-local PRD.

Sections, per the parent PRD:

- **Workflow ownership.** Which repo owns each workflow (`alchemist-v2`: products
  enrichment, `commands` consumption, `run_log`/`scout_log`/`ungate_log`, scheduler,
  Discord stage summaries; `DealFinder`: deal probing/lifecycle, `deals`,
  `deal_notifications`, `ungating_opportunities`, products write-through;
  `Alchemist_Dashboard`: browser UI, anon write payloads, `business_snapshots`, deal
  review actions, wholesale matching, command insertion, status rendering).
- **Shared table contract.** For each shared table: owner, writers (anon vs
  service-role), readers, key columns and their semantics. Verify the actual schema,
  RLS state, and grants against the live Supabase (read-only, via Supabase MCP) — local
  schema files have drifted before (`alchemist-v2/CLAUDE.md`, `setup-db.js` note).
- **Anon write surface.** The exact set of anon-key write operations the dashboard is
  permitted (per PRD: only `commands` inserts of `queue_backfill_ean`, plus
  dashboard-owned finance/deal-action writes). Cross-check against
  `Alchemist_Dashboard/issues/done/011-anon-write-surface-misscoped.md`.
- **Money/price units.** Pin units per table and column: integer pence/cents vs ROI
  fractions vs channel-neutral target price (max landed cost at 20% ROI floor,
  no channel costs baked in).
- **Keepa account coordination.** Document the deliberate sharing: DealFinder's
  overnight pause (`DealFinder/issues/done/031-overnight-pause.md`) and alchemist-v2's
  21:00–04:59 every-15-min miner window sized by live `getTokenStatus()`; the rule that
  Keepa-token spend is server-side and schedule-gated only.

## Acceptance criteria

- [x] `CONTRACTS.md` exists at the AlchemistSuite root covering all five sections above.
- [x] Every shared-table entry was verified against the live Supabase schema (read-only),
      not just local schema files; discrepancies found are logged as repo-local issues in
      the owning repo rather than silently corrected in the doc.
- [x] The doc states explicitly that it owns cross-repo semantics only and links to each
      repo's local `issues/prd.md` for implementation detail.
- [x] No app source files are added to this root repo.

## Resolution (2026-07-15)

`CONTRACTS.md` written and verified read-only against live A2ASearch
(`rzxtppclwfulyxfatezr`): schema (columns/PKs), RLS state, table- and column-level
grants, and full policy expressions for every shared table. Three discrepancies found
and logged as repo-local issues, not corrected in the doc:

1. `alchemist-v2/issues/018-bug-claude-md-rls-note-stale.md` — CLAUDE.md's "RLS is
   disabled" is stale; RLS is live on all 10 tables.
2. `alchemist-v2/issues/019-bug-ungate-log-anon-grants-overbroad.md` — `ungate_log`
   grants anon/authenticated full table privileges (incl. TRUNCATE) with RLS-on/zero
   policies; latent, not currently exploitable.
3. `Alchemist_Dashboard/issues/013-bug-anon-read-surface-gaps.md` — `products` has an
   anon read policy but no anon SELECT grant; `run_log` has no anon access at all. Both
   masked locally by the service key.

Also pinned in the doc: canonical `run_log` stage names (`mine`, `import`, `scout`,
`commands`, `housekeeping`) as the published contract, ahead of alchemist-v2 issue 017 /
dashboard issue 012 implementing them.

## Blocked by

None - can start immediately

## User stories addressed

- User story 1
- User story 2
- User story 8
- User story 9
- User story 10
- User story 11
- User story 12
