# PRD - Alchemist Suite Constellation Contracts

## Problem Statement

The Alchemist suite is now three separately-built projects that must behave as one
operating system:

- `alchemist-v2` feeds and enriches the shared `products` catalog, handles buy-sheet
  import, processes dashboard backfill commands, and runs SP-API ungating checks.
- `DealFinder` probes EU Amazon price drops, evaluates honest landed-cost ROI, writes
  deal and ungating data, and upserts useful product signal into the shared catalog.
- `Alchemist_Dashboard` is the human-facing surface over finance, deal review,
  wholesale search, queueing, and operational status.

Each project has a good local PRD and issue queue, but the contracts between them are
now the highest-risk part: shared Supabase tables, stage names, run status logging,
anon vs service-role permissions, deployment ownership, and scheduling windows. Some
integration expectations are documented in one repo but implemented or owned in
another, which makes it easy for local tests to pass while the suite fails as a
whole.

## Solution

Create a small constellation-level contract PRD that does not replace the repo PRDs.
It records the system-level promises each project makes to the others, then drives
repo-local issues for any missing or drifting contract.

The system PRD should stay deliberately thin: it owns cross-repo semantics and
verification, not feature implementation. Implementation still follows the existing
Claude/Ralph workflow in the owning repo: PRD or bug issue first, TDD, one issue per
iteration, green local feedback loops, then move completed work to `issues/done/`.

## User Stories

1. As the operator, I want the three projects to agree on which system owns each
   workflow, so that I know where to fix or extend behavior.
2. As the operator, I want shared Supabase table contracts documented in one place, so
   that schema, RLS, grants, and column semantics do not drift silently.
3. As the operator, I want the dashboard pipeline card to reflect real server runs, so
   that I can trust it without checking Discord, PM2, or SQL manually.
4. As the operator, I want `alchemist-v2` stages to write `run_log` rows consistently,
   so that every consumer sees the same operational state.
5. As the operator, I want stage names to match across CLI, scheduler, `run_log`, and
   dashboard UI, so that status and alerting do not split one stage into multiple names.
6. As the operator, I want dashboard-created EAN backfill commands to be handled by
   Alchemist without direct browser writes to `products`, so that Keepa spend remains
   scheduled and service-role only.
7. As the operator, I want the queue-to-enrichment path verified end to end, so that an
   unmatched supplier EAN visibly moves from queued to enriched after the overnight miner.
8. As the operator, I want DealFinder's `deals` and `ungating_opportunities` tables to
   remain DealFinder-owned, so that the dashboard consumes the sanctioned contract
   rather than redefining lifecycle or gating semantics.
9. As the operator, I want every browser write surface to be intentionally scoped, so
   that the anon key can only perform the dashboard actions it is meant to perform.
10. As the operator, I want all money and price units pinned by table and column, so
    that pence, cents, ROI fractions, and channel-neutral target prices do not get
    mixed.
11. As the operator, I want Keepa-token-consuming work to remain server-side and
    schedule-gated, so that dashboard actions cannot accidentally spend tokens live.
12. As the operator, I want the Alchemist overnight backfill window to coordinate with
    DealFinder's overnight pause, so that the two systems share the Keepa account
    deliberately.
13. As the operator, I want live-service checks separated from local unit checks, so
    that a green test suite is not mistaken for proof that Supabase, Keepa, SP-API, or
    PM2 are healthy.
14. As the operator, I want outstanding integration gaps to become repo-local issues,
    so that Ralph/Claude can continue working one focused task at a time.
15. As the maintainer, I want durable cross-repo learnings recorded in each repo's
    `CLAUDE.md`, so that future fresh-context iterations do not rediscover the same
    integration gotchas.

## Implementation Decisions

- **System contract home.** This document lives in the root `AlchemistSuite` coordination
  repo. It is a contract map, not a replacement for any repo's local `issues/prd.md`.
- **Repo ownership stays local.** Code and schema changes are implemented in the repo
  that owns the behavior:
  - `alchemist-v2`: `products` enrichment, `commands` consumption, `run_log`, `scout_log`,
    `ungate_log`, scheduler, Discord stage summaries.
  - `DealFinder`: deal probing, deal lifecycle, `deals`, `deal_notifications`,
    `ungating_opportunities`, products write-through from evaluated deals.
  - `Alchemist_Dashboard`: browser UI, anon write payloads, finance snapshots, deal
    review actions, wholesale matching, command insertion, status rendering.
- **Shared table contract.**
  - `products` is the permanent master keyed by EAN. Channel-neutral target price stays
    server-computed and consumer-neutral.
  - `commands` accepts only dashboard `queue_backfill_ean` rows from anon; service-role
    Alchemist workers claim and complete them.
  - `run_log` is the operational status source for Alchemist stages. Producer stage
    names must match dashboard expected names.
  - `deals`, `deal_notifications`, and `ungating_opportunities` remain DealFinder-owned.
  - `business_snapshots` remains dashboard-owned finance history.
- **Run status contract.** Alchemist stages should emit `run_log` rows for `mine`,
  `import`, `scout`, `commands`, and housekeeping where applicable. The dashboard should
  display exactly those stage names rather than aliases that are not written by the
  server.
- **Verification contract.** Local checks prove code health; live checks prove service
  health. The suite needs both:
  - local tests/typechecks/builds in each repo;
  - a read-only Supabase schema/connectivity check;
  - deployment/process checks for the long-running Alchemist scheduler and DealFinder PM2
    probe;
  - selective live smoke tests only when the operator approves external API or token
    spend.
- **Issue-routing rule.** Integration gaps found by this PRD should be logged as
  repo-local issues. A system issue may name several repos, but the work should be split
  so one Ralph iteration still owns one task.
- **Methodology preservation.** Do not bypass the existing Claude/Ralph system. Bugs are
  logged first, features go through PRD-to-issues, and implementation uses TDD with
  behavior-facing tests.

## Testing Decisions

- Good system-level tests verify public contracts, not internal helpers. Examples:
  dashboard status reduction from realistic `run_log` rows, Alchemist command handling
  through `stage-commands.run(config)`, and DealFinder deal lifecycle through public
  module interfaces.
- Cross-repo contracts should have at least one test on each side when practical:
  producer shape in the owning repo, consumer interpretation in the dashboard.
- Live Supabase checks are required for schema/RLS/grant questions, because local schema
  files have drifted before. These checks should be read-only unless a migration or smoke
  test is explicitly approved.
- Keepa/SP-API live calls are not part of routine verification. They require an operator
  decision because even dry-run paths may spend real tokens in some repos.
- The standard local gates remain:
  - `alchemist-v2`: `npm test`
  - `DealFinder`: `npm run test` and `npm run typecheck`
  - `Alchemist_Dashboard`: `npm run test`, `npm run typecheck`, and build when UI output
    is affected.

## Out of Scope

- Replacing the three repo-local PRDs.
- Creating a monorepo build system.
- Hosting the shared dashboard.
- Reworking DealFinder's local test dashboard.
- Adding new sourcing workflows such as Qogita API integration.
- Running live Keepa, SP-API, or destructive Supabase operations without explicit
  operator approval.

## Further Notes

- First repo-local follow-up: log and fix the Alchemist `run_log` producer gap, then
  align the dashboard stage key from `ungating` to the actual `scout` stage.
- Second follow-up: verify the dashboard EAN queue path all the way from anon insert to
  Alchemist command claim to overnight miner enrichment.
- Third follow-up: keep this root repo focused on coordination. Do not add app source
  files here unless the suite is deliberately converted to a monorepo later.

