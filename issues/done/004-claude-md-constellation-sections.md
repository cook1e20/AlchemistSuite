type: AFK

## Parent PRD

`issues/constellation-prd.md`

## What to build

A short, consistent "Constellation" section in each repo's `CLAUDE.md` (`alchemist-v2`,
`DealFinder`, `Alchemist_Dashboard`) plus a pointer in this root repo's `README.md`, so
future fresh-context iterations in any repo discover the cross-repo contracts instead of
rediscovering integration gotchas.

Each section should be brief and point outward, not duplicate:

- Link to the root `CONTRACTS.md` (from `issues/001-constellation-contract-map.md`) and
  `issues/constellation-prd.md`.
- One-line statement of what this repo owns and what it must not touch (e.g. dashboard:
  never write `products` directly from the browser; DealFinder: `deals` /
  `ungating_opportunities` lifecycle is yours alone; alchemist-v2: `run_log` producer
  names are a published contract the dashboard renders verbatim).
- The durable cross-repo gotchas already learned (stage-name drift `ungating` vs
  `scout`, anon vs service-role write surfaces, shared Keepa token account and the
  overnight window split, pence/units pinning) — one line each, linking to the
  contract doc for detail.

alchemist-v2's `CLAUDE.md` already carries rich local conventions — add the
constellation section alongside them without rewriting or trimming what's there.

## Acceptance criteria

- [ ] All three repos' `CLAUDE.md` files have a Constellation section linking to the
      root `CONTRACTS.md` and stating that repo's ownership boundary.
- [ ] Root `README.md` points newcomers at `CONTRACTS.md`, the constellation PRD, and
      the three repos.
- [ ] No contract content is duplicated verbatim across the four files — pointers plus
      one-liners only, so there is a single place to update.
- [ ] Each repo's local test gate still passes (docs-only change, but run it anyway per
      each repo's conventions).

## Blocked by

- Blocked by `issues/001-constellation-contract-map.md` (the sections point at
  `CONTRACTS.md`, which must exist first).

## User stories addressed

- User story 15
