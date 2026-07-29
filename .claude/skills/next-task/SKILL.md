---
name: next-task
description: Pick and complete the next issue from the constellation RUNLIST.md (one interactive ralph iteration, executed in whichever child repo owns the issue). Use when the user says "next task" or wants to work the next queued issue with fresh context.
---

# Next Task (constellation)

Work exactly one issue from the constellation run list, inside the current session.
This is the root-level variant of the child repos' `/next-task`: the queue lives in
`RUNLIST.md` here, but implementation happens in the repo that owns the issue
(`alchemist-v2/`, `DealFinder/`, `Alchemist_Dashboard/` — each its own git repo — or
this root repo for root-owned issues).

## 1. Context check (do this first)

If this session already contains a completed `/next-task` iteration, or is otherwise
long with unrelated work, do NOT start the task. Instead tell the user:

> Context is carrying over from earlier work — run `/clear`, then `/next-task` again for
> a fresh iteration.

Fresh context per task is the point of the ralph loop; only proceed in a long session if
the user explicitly says to.

## 2. Gather context

Run/read these fresh — do not rely on stale context:

- `RUNLIST.md` — the ordered queue. The next task is the **topmost unchecked entry
  whose blockers have landed**.
- The chosen issue file itself, in full.
- The owning repo's `CLAUDE.md` and (if present) `ralph/prompt.md` — its conventions
  and loop govern the implementation.
- `git log -n 5 --format="%H%n%ad%n%B---" --date=short` **in the owning repo** —
  recent work and notes left for this iteration.
- Root `CONTRACTS.md` if the issue touches any shared table, anon grant, stage name,
  or money unit — cross-repo contracts are owned there.

Blocker check: don't just look at whether a blocking issue's file moved to `done/` —
check whether the blocker's *stated reason* still holds against what actually got built
(see alchemist-v2 `CLAUDE.md`; RUNLIST entry D1 is a live example of a stale blocker).

Exception to queue order: a `severity: critical` bug in any repo's `issues/` jumps the
queue.

## 3. Run scope

RUN SCOPE: interactive supervised run — AFK and HITL entries are both workable. For a
HITL entry, surface the human-gated step (live grant change, token spend, business
decision) to the user and get an explicit go-ahead **before** executing that step;
build/test work around it can proceed normally.

Standing safety rule: never run alchemist-v2's `mine` or `import` stages as a "check" —
`--dry-run` still spends real Keepa tokens until `alchemist-v2/issues/020` lands
(CONTRACTS.md §5).

## 4. Execute (in the owning repo)

- **Child-repo issue:** `cd` into that repo and follow its `ralph/prompt.md` exactly —
  implement with `/tdd`, run its stated feedback loop (`npm test`, plus
  `npm run typecheck` where the repo has one), commit **in that repo** with key
  decisions / files changed / blockers, move the issue to its `issues/done/`, and do
  the RECAP step (durable learnings into that repo's `CLAUDE.md`).
- **Root-owned issue** (this repo's `issues/*.md`): coordination/docs only — no app
  source or scripts belong at root. Complete the doc work, move the issue to
  `issues/done/`, commit here.

## 5. Close out

- Tick the entry in `RUNLIST.md` and append a one-line result note (date + outcome or
  follow-up issue filed); commit the runlist change in this root repo.
- If the iteration changed a cross-repo contract (table shape, grant, stage name,
  unit), update `CONTRACTS.md` in the same root commit or log a root issue for it.

ONLY WORK ON A SINGLE TASK. When done, remind the user to `/clear` before the next
`/next-task`.
