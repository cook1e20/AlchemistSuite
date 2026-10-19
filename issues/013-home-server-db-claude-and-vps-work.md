type: HITL
kind: coordination

## Parent PRD

`issues/constellation-prd.md`. Backlog idea, not yet scoped. Grill it before it gets an owning
repo or a build slot.

## Idea (operator, 2026-10-19)

Buy a micro PC/server for home, with three jobs:

1. **Run Claude remote sessions** (Claude Code with remote control) on an always-on box.
2. **Host the shared DB**, replacing the Supabase free plan (500 MB cap) instead of moving to Pro.
3. **Maybe take on some of the VPS work** (alchemist-v2, DealFinder, currently on the VPS at
   31.97.117.157).

Context: on 2026-10-19 the DB was cut from 536 MB to 419 MB (alchemist-v2 038), which leaves roughly
2-3 months of headroom at ~1.1 MB/day. That window is the soft deadline for job 2.

## What the DB move must preserve

The constellation uses more of Supabase than Postgres:

- **PostgREST + RLS:** Alchemist_Dashboard and KeepaCompanion call the DB from the browser with the
  anon key; CONTRACTS.md section 3 is the full anon grant/policy surface. Server code uses service_role.
- **Edge Functions:** `gating-check` (alchemist-v2, SP-API credentials) and `qogita-catalog-webhook`
  (dashboard, called by Qogita from the internet).
- **Storage:** `wholesale-catalogs` bucket (`latest.csv.gz`, anon-readable via a `storage.objects` policy).
- **Reachability:** the VPS, the operator's browser, Qogita's webhooks and the dashboard host must all
  reach it, so a home box needs a public endpoint (tunnel or port-forward) with TLS.

Likely route: self-hosted Supabase (Docker stack) so no app code changes; only URLs and keys move.

## Questions for the grill

- Hardware: CPU/RAM/disk (Postgres plus the Supabase stack plus Claude sessions), and UPS.
- Exposure: Cloudflare Tunnel vs port-forward; domain and TLS; what happens to alerts when home
  internet drops.
- Backups: schedule, offsite copy, a restore test before cut-over.
- Cut-over: dump/restore of `products` (~1M rows) and the rest, how long DealFinder and the miner
  pause, rollback path, and every place the Supabase URL/keys live (VPS `.env` files, dashboard and
  KeepaCompanion localStorage/options, edge function secrets, Qogita webhook registration).
- VPS work: which stages move home (the 24/7 alerting ones may be better left on the VPS), and
  whether the VPS stays at all.
- Claude remote sessions: which repos and credentials live on the box, and how it's secured.
- Keepa and SP-API: rate limits are per account, not per IP, so moving stages shouldn't change
  allowances; confirm.

## Blocked by

Grill first. Hardware purchase (operator).
