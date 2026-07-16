# Alchemist Suite — Verification runbook

How to tell the constellation is healthy. The PRD's verification contract separates two
kinds of health that must never be conflated: **local gates** prove *code* health in a
working copy; **live checks** prove *service* health on the machines and database that
actually run the business. A green test suite says nothing about whether the scheduler
is alive, and a live scheduler says nothing about whether your diff is safe to commit.
Run both, and know which one you're looking at.

Three tiers:

1. **Local gates** — per-repo test/typecheck/build commands. Run freely.
2. **Live checks** — read-only against the live services. Run freely; nothing here
   writes anything or spends a token.
3. **Operator-gated checks** — anything that spends Keepa tokens or hits SP-API.
   Never routine; each run needs explicit operator approval.

This is a runbook (commands + what healthy looks like), not a script framework — the
root repo stays coordination-only.

---

## Tier 1 — Local gates (code health)

Run in the owning repo before every commit. These are exactly the gates each repo's
CLAUDE.md / package.json defines (verified 2026-07-16):

| Repo | Gate | Notes |
|---|---|---|
| `alchemist-v2/` | `npm test` | `node --test test/*.test.js`. Plain JS/CommonJS — **no typechecker exists**; tests are the only automated net. |
| `DealFinder/` | `npm run test` && `npm run typecheck` | Vitest + `tsc --noEmit`. |
| `Alchemist_Dashboard/` | `npm run test` && `npm run typecheck` | Vitest + `tsc --noEmit`. Add `npm run build` (Vite) when UI output is affected. |

A green local gate proves the working copy. It does **not** prove the deployed server
runs that code — the deployed scheduler has lagged the repo by multiple commits before
(see Tier 2's version-lag check).

---

## Tier 2 — Live checks (service health, read-only)

All database checks are plain read-only SQL against the shared Supabase project
**A2ASearch (`rzxtppclwfulyxfatezr`)**. Run them via the `claude.ai Supabase` MCP
`execute_sql` tool (available in any repo session — see `DealFinder/CLAUDE.md`'s
convention note) or paste them into the Supabase SQL editor. Nothing in this tier
writes a row or spends a token.

### 2.1 Connectivity + schema presence

All nine contract tables from `CONTRACTS.md` §2 should exist:

```sql
select table_name from information_schema.tables
where table_schema = 'public'
  and table_name in ('products','commands','run_log','deals','deal_notifications',
                     'ungating_opportunities','business_snapshots','scout_log','ungate_log')
order by table_name;
```

**Healthy:** 9 rows come back. (Verified 2026-07-16: all 9 present.) If the query
itself fails, the check has answered the connectivity half.

Grants/policies (the anon surface) are contract, not health — re-verify them against
`CONTRACTS.md` §3 only when a grant change is suspected, using read-only
`information_schema.role_table_grants` / `pg_policies` queries as issue 001 did.

### 2.2 alchemist-v2 scheduler — is it alive, and what is it running?

`scheduler.js` is a long-running node-cron process on a remote server. **The host is
not documented in the repo** (operator: fill this in — ssh access, process supervisor,
and repo path on the box), so the reliable liveness check is DB-side: every scheduled
stage leaves read-only fingerprints.

```sql
select
  (select max(processed_at)::text from commands)                        as commands_last_processed,
  (select count(*) from commands where status = 'pending')              as commands_pending,
  (select max(scouted_at)::text  from scout_log)                        as scout_last_batch,
  (select max(started_at)::text  from run_log)                          as run_log_last_start,
  (select max(last_mined_at)::text from products where title is not null) as miner_last_touch,
  now()::text                                                            as db_now;
```

Interpretation (all times UTC; the miner window is 21:00–04:59 **UK-local**):

| Signal | Cadence when healthy | Healthy looks like |
|---|---|---|
| `commands_last_processed` | commands worker runs every 15 min | within ~20 min of `db_now` whenever any pending rows exist. **The strongest liveness signal.** |
| `commands_pending` | — | draining over time, not growing (worker claims 50/run, oldest-first). |
| `scout_last_batch` | scout every 30 min, but per-brand 14-day cooldown | hours-old is fine (no eligible brands is normal); many days old while ungating work is expected means look closer. |
| `run_log_last_start` | every stage, once the server runs commit `7a0e170`+ | fresh rows with canonical stage names (`mine`/`import`/`scout`/`commands`/`housekeeping`). **Until that commit is deployed this stays stale — see version lag below.** |
| `miner_last_touch` | every 15 min inside the overnight window | during/after each overnight window, thousands of enriched rows touched. The `title is not null` filter matters: bare command-queued rows default `last_mined_at = now()` on insert, so an unfiltered `max(last_mined_at)` reflects the *commands worker*, not the miner. |

**Version lag:** a live scheduler is not necessarily a *current* scheduler. Once
`run_log` writers (alchemist-v2 `7a0e170`) are deployed, `run_log` recency becomes the
primary signal and stage-level status is visible per-row (`status` =
`completed`/`completed_with_errors`/`failed`). Until then, a scheduler that is
demonstrably alive (fresh `commands_last_processed`) but writes no `run_log` rows is
running pre-`7a0e170` code — which also means it predates the `--dry-run` spend fix
(`36084f3`), so the Tier-3 fence applies with full force.

> **Answer to the standing question (2026-07-16):** yes, the scheduler *is* deployed
> and alive — `commands_last_processed` was 13 minutes fresh, scout batched at 02:30
> that morning, and 20k+ enriched rows were touched in 24 h. But it runs pre-`7a0e170`
> code: `run_log`'s only rows are 86 legacy `stage='wholesale'` rows, newest
> 2026-07-06. Re-run the query above after any server pull to re-answer.

### 2.3 DealFinder probe — PM2 on the Hostinger VPS

The probe is PM2-supervised (`ecosystem.config.cjs`, process name `dealfinder`).
Full ops detail lives in **`DealFinder/deploy/RUNBOOK.md`** — that runbook is
authoritative; the essentials, on the VPS:

```sh
pm2 status                                   # expect: dealfinder | online
pm2 logs dealfinder --lines 200 --nostream   # expect a `funnel ...` line within the last hour
```

`online` alone is not enough — the process can be up with a startup error; the hourly
`funnel` log line is the real heartbeat. DB-side proxies are weak by design
(`deals`/`deal_notifications` only move when deals are found), so prefer the VPS check.
Note the probe deliberately skips ticks 21:00–05:00 UK (overnight Keepa pause) — a
quiet overnight log is healthy, not a hang.

### 2.4 Discord — the human-visible cross-check

Where each summary lands (all alchemist-v2 webhooks fall back to
`DISCORD_WEBHOOK_URL` when the per-stage env var is unset):

| Message | When | Webhook env |
|---|---|---|
| alchemist-v2 stage summaries (mine/import/scout/commands) | per scheduled run | `DISCORD_WEBHOOK_MINER` → fallback |
| Weekly ungate digest | Monday 05:15 | `DISCORD_WEBHOOK_JANITOR` → fallback |
| Housekeeping purge note | 1st of month 03:00 (only if rows purged) | `DISCORD_WEBHOOK_JANITOR` → fallback |
| DealFinder deal notifications | as deals pass the funnel | DealFinder `DISCORD_WEBHOOK_URL` (optional — unset means deals persist as `status=new`, unsent) |

Healthy: overnight miner summaries appeared this morning; Monday brought a digest (or
a genuinely empty week); DealFinder alerts arrive when the funnel log shows passes.
Silence in Discord plus fresh DB fingerprints means a webhook problem, not a dead
scheduler — the DB checks above are the tiebreaker.

---

## Tier 3 — Operator-gated checks (token/API spend)

**Never routine. Each run needs explicit operator approval, every time.** These are
the only checks that prove the external integrations end-to-end, and all of them can
cost real money/quota:

| Check | What it proves | What it costs |
|---|---|---|
| `node index.js --stage mine --dry-run` (alchemist-v2) | candidate selection, live Keepa token balance read | **Free only where commit `36084f3`+ is running.** On older code — including the deployed server until it pulls — dry-run fires the real Keepa lookups (~350 tokens were burned this way once; CONTRACTS §5). |
| Live single-EAN backfill (queue one `commands` row via the dashboard, wait for the overnight window) | the whole queue → claim → enrich contract | ~1 Keepa token per row; slow (next scheduled run). This is the root issue 002 procedure. |
| Live `mine`/`import` run | full enrichment path incl. Keepa + Sheets | real token spend proportional to batch; shares DealFinder's token bucket (CONTRACTS §5). |
| Scout / SP-API smoke (`scheduler` triggers it, or a supervised `--stage scout`) | SP-API credentials, gating checks | SP-API rate-limit quota; no Keepa tokens. |
| DealFinder `npm run probe:once` | full funnel incl. Keepa Deals feed + SP-API | real Keepa spend; also competes with the scheduled hourly probe's budget. |

Rules of engagement:

- State the expected spend before asking approval; report actual spend after.
- Keepa spend is server-side and schedule-gated by contract (CONTRACTS §5) — a manual
  spend run is an *exception*, not a tool.
- Prefer the cheapest check that answers the question: Tier 2's read-only fingerprints
  answer "is it running?" for free; Tier 3 only answers "does the paid integration
  still work end-to-end?".

---

*Live checks in this runbook were executed and verified working 2026-07-16 (read-only,
zero spend). Keep the queries aligned with CONTRACTS.md if table/stage names change —
stage names in `run_log` are a published contract (§2).*
