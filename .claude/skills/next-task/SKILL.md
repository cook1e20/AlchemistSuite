---
name: next-task
description: Pick the next RUNLIST.md entry and complete it directly in this session — one issue, in the repo that owns it, then stop. Use when the user says "next task" or wants one queued issue worked. For working several in a row with coder/reviewer subagents, use /next-task-overseer.
---

# Next Task (constellation)

Work exactly one entry from `RUNLIST.md`, yourself. The queue lives here at root, but
implementation happens in the repo that owns the issue (`alchemist-v2/`, `DealFinder/`,
`Alchemist_Dashboard/`, `KeepaCompanion/` — each its own git repo — or this root repo for
root-owned issues).

## 1. Context check (do this first)

If this session already contains a completed `/next-task` iteration, or is otherwise long
with unrelated work, do NOT start. Tell the user:

> Context is carrying over from earlier work — run `/clear`, then `/next-task` again for
> a fresh iteration.

## 2. Pick the issue

Follow step 1 ("Pick the next issue") of `.claude/skills/next-task-overseer/SKILL.md` —
read it fresh. It covers RUNLIST order, blocker checks against what was actually built,
the critical-bug exception, and what to read in the owning repo.

## 3. Pre-flight

- `git -C <repo> status --porcelain` — dirty paths are someone else's in-flight work:
  never stage, edit, revert or stash them. If they overlap the issue's files, ask.
- **HITL entries:** build/test work around the gated step can proceed. The gated step
  itself (live grant change, migration apply, token spend, VPS/env change, business
  decision) needs an explicit go-ahead first.
- **Safety:** never run alchemist-v2's `mine`, `import`, `full`, `commands`, `start` or
  `scheduler` stages, nor DealFinder's `probe` — real Keepa tokens / production. No live
  DB writes, no applying migrations, no `git push`, no committing `.env` or credentials.
- **Root-owned issues** are coordination/docs only — no app source or scripts at root.

## 4. Build (in the owning repo)

Follow that repo's `/next-task` skill (`<repo>/.claude/skills/next-task/SKILL.md`)
sections 4–6: `/tdd` (or `/diagnosing-bugs` for a bug), its feedback loop from its
`CLAUDE.md`, bugs logged not fixed, issue to `issues/done/`, `CLAUDE.md` recap, and a
commit in that repo staging only this issue's paths.

## 5. Close out at root

Tick the RUNLIST entry and append a one-line result note (date + outcome or follow-up
issue filed). If a cross-repo contract changed, update `CONTRACTS.md` in the same commit.
Commit only those files.

ONLY WORK ON A SINGLE ENTRY. When done, remind the user to `/clear` before the next
`/next-task`.
