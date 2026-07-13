# AlchemistSuite

Coordination repo for the Alchemist constellation.

The application code lives in three separate sibling repos:

- `alchemist-v2` - catalog feeder, backfill miner, buy-sheet import, command worker, ungating, scheduler.
- `DealFinder` - EU-to-UK deal probe, deal lifecycle, Discord notifications, DealFinder-owned tables.
- `Alchemist_Dashboard` - browser UI over finance, deals, wholesale search, command queueing, and status.

This root repo tracks only cross-repo contracts, PRDs, and coordination issues. The child
repos stay independent and are intentionally ignored by this repo.

## Workflow

Use the same Claude/Ralph method as the child projects:

1. Capture cross-repo intent in `issues/constellation-prd.md`.
2. Break system work into coordination issues under `issues/`.
3. Route implementation to repo-local issues in the owning project.
4. Keep one task per iteration; use TDD and each repo's local feedback loop.

## Contract Ownership

- System-level contracts live here.
- Code changes live in the owning child repo.
- If this repo conflicts with a child repo on a cross-repo contract, this repo is the contract source of truth.
- If this repo conflicts with a child repo on local implementation detail, the child repo is authoritative.

