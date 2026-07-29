type: HITL  <!-- needs an operator decision on whether to expose gating ground-truth to anon, a cross-repo contract change -->
kind: coordination
severity: minor

## Parent PRD

`issues/constellation-prd.md`

## What was observed

Alchemist_Dashboard's "Export ASINs for Arbisource" button (`exportArbisourceASINs`,
`Alchemist_Dashboard/src/main.ts:772`) was written back when `products` only held ASINs
that had already passed a gating check — every row was implicitly "sellable." That
assumption is stale now: `products` also gets bare rows from the dashboard's own
backfill-queue command, the bulk 700k-catalog loader, and DealFinder's write-through —
none of which run a restrictions check before writing `uk_asin`. The button's only
filter today is `uk_asin IS NOT NULL`, so it now exports gated ASINs mixed in with
sellable ones.

Investigated where "is this ASIN currently ungated/sellable" actually lives:

- No column on `products` itself (`is_ungated`/`gating_status`/etc.) — confirmed dead
  end. DealFinder's `products-upsert.ts` says this is deliberate: "gating stays read
  live from `ungate_log`, no denormalized column exists."
- `ungate_log` (asin PK, upserted per-ASIN — current state, not an append log —
  `result: 'approved'|'failed'|'no_link'|'error'`) is the real ground truth, and it's
  written from **three** places, more than expected going in:
  - alchemist-v2's `scout` stage (auto-ungate attempts, including the visibility fix in
    alchemist-v2 issue 031/`b18bcec` that now writes a row even on a caught error)
  - alchemist-v2's `import` stage (BuySheet SP-API restrictions check before
    `upsertProduct`)
  - DealFinder's `probe` stage (`logUngateAttempts`)
  So gating checks *are* being logged already at multiple stages — the gap is that the
  dashboard can't read any of it, not that the logging is missing.
- `ungate_log` is **service_role only** — anon has zero access (CONTRACTS.md §3;
  alchemist-v2 issue 019/`8f9ba1d` explicitly revoked a legacy over-broad anon grant on
  purpose).
- `ungating_opportunities` (the one gating-adjacent table the dashboard already reads,
  `src/ungating.ts`) only ever gets rows added when DealFinder finds something newly
  gated — nothing prunes a row once it's resolved, so neither its presence nor its
  absence reliably means "still gated."

## What the operator needs to decide

This is a cross-repo contract question (touches CONTRACTS.md §3's anon grant surface,
and `ungate_log` is written by all three repos), not a local Alchemist_Dashboard fix —
hence filed at root rather than as a dashboard issue.

1. Should `ungate_log` (or a derived view of it) get a **narrow** anon SELECT grant +
   RLS policy so the dashboard can filter the Arbisource export on real gating ground
   truth? If so, what shape — the raw table, or a view exposing just
   `(asin, result, attempted_at)` latest-per-asin?
2. Alternative: keep `ungate_log` service-role-only and instead have the export call a
   small Edge Function (service-role) that filters server-side and returns just the
   CSV rows — no new anon grant needed, but a new Edge Function to build/deploy (one
   precedent already exists in Alchemist_Dashboard, `qogita-catalog-webhook`).
3. Either way, decide the exact "sellable" predicate: most recent
   `ungate_log.result = 'approved'` per ASIN? And what about ASINs with **no**
   `ungate_log` row at all (never checked) — include, exclude, or flag separately in
   the export?

## Blocked by

Nothing technical. Blocked on the operator's decision above before any repo starts
building. A client-side proxy filter (e.g. exclude anything present in
`ungating_opportunities`) was considered during investigation and rejected as
unreliable for the reasons above — not worth building even as a stopgap.

## User stories addressed

- User story 8 (ungating data ownership) — related context, not a direct match; this
  issue is about export correctness downstream of that data, not new ungating
  detection.
