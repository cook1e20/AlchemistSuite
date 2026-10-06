type: HITL  <!-- the operator must set the edge function's SP-API secrets; nothing else is blocking -->
kind: coordination
severity: minor

## Parent PRD

`issues/constellation-prd.md`

## What changed

A fourth repo joined the constellation — **`KeepaCompanion`**, a Chrome extension that
adds three per-ASIN columns to the Keepa Product Finder (Track / Searched / Gate). Built
2026-09-19. The cross-repo surface it introduced is recorded in CONTRACTS.md §1, §2 and
§3; this issue records the *decisions*, since two of them touch contract rules that were
previously absolute.

### 1. A new synchronous browser→server path (CONTRACTS.md §3)

§3's rule was flat: the browser "never triggers Keepa or SP-API work directly — it
queues a `commands` row and waits for the server". The Gate column cannot work that way
— `stage-commands` runs every 15 minutes, and a grid column that answers a quarter of an
hour later is not a column anyone uses.

The rule's *purpose* — no SP-API credentials in the browser, no unbounded spend from a
click — is kept intact by the `gating-check` edge function instead:

- the function holds the SP-API credentials and runs with the service role;
- it serves the `gating_status` cache first and only calls SP-API for aged-out entries;
- a request is capped at 50 ASINs;
- it is gated on a shared secret (`KC_SHARED_SECRET`) *on top of* the anon JWT.

§3 now states this as the one sanctioned exception, with the shape any future such path
must copy. The `commands` queue remains the path for anything unbounded or long-running.

### 2. `gating_status` is a new table, deliberately not `ungate_log`

Reusing `ungate_log` was the obvious move and is wrong. It is an ungating-*attempt* log:
a clean check writes no row (so absence is ambiguous), genuine restrictions and SP-API
errors both record as `result: 'failed'`, and its `marketplace` column records the EU
marketplace a *deal* came from — live values are `de`/`es`/`it`/`fr` with no `uk` rows,
even though `checkRestriction()` has always queried UK. Its PK is `asin` alone, so
restriction checks written there would clobber the cooldown data
`getRecentUngateAttempts()` depends on. Full detail in CONTRACTS.md §2.

**This partly answers `issues/006`.** That issue asks how to expose gating ground truth
to the browser and offers three options; option 2 — "keep `ungate_log` service-role-only
and have an Edge Function filter server-side" — is now built and deployed as
`gating-check`, with a purpose-built cache behind it. 006's remaining question is
narrower than it was: it is no longer "what is ground truth and how do we expose it",
but "should the Arbisource export reuse `gating_status`, and what does it do about ASINs
with no row yet". Re-read 006 against this before working it.

### 3. `asin_tracker` adds to the anon write surface

First anon-writable table owned by a repo other than the dashboard. Single-user triage
data; the `status` CHECK constraint, not the RLS policy, is what bounds the values. No
DELETE grant — clearing a status is an UPDATE to null. Verified live against the real
anon key on 2026-09-19: upsert succeeds, an out-of-range status is rejected, DELETE
returns 401, and `gating_status` returns `permission denied`.

## What the operator needs to do

1. **Set the `gating-check` secrets** — `LWA_APP_ID`, `LWA_CLIENT_SECRET`,
   `SP_API_REFRESH_TOKEN`, `SP_API_MERCHANT_ID` (the values already in alchemist-v2's
   `.env` on the server), plus a freshly chosen `KC_SHARED_SECRET`. Until then the
   function fails closed (HTTP 500, no data) and the Gate column stays blank.
2. **Put the same `KC_SHARED_SECRET`** into the extension's options page.
3. **Load the unpacked extension** and confirm the three columns against the live
   Product Finder. The mechanism is verified in a harness, but only the real page
   proves the Keepa-specific assumptions.

## Watch items

- The extension pins two Keepa assumptions: the finder grid is **ag-Grid Enterprise
  21.1.0** on element `#grid-asin-finder`, and row data carries `asin`. A Keepa rewrite
  of `grid.js` is the most likely way this breaks — it fails visibly (columns simply
  absent), not silently.
- SP-API Listings Restrictions is **5 req/sec**. Gating is requested per rendered row,
  debounced and batched 20 at a time. If the Gate column is ever driven from something
  page-wide rather than viewport-wide, re-check that budget first — and note
  alchemist-v2's standing lesson that a documented rate is worth confirming against the
  real `x-amzn-RateLimit-Limit` header.

## Blocked by

Nothing. Step 1 above is operator-only because the SP-API secrets are not in this
environment.

## User stories addressed

- User story 8 (ungating data ownership) — advances it; see the `issues/006` note above.
