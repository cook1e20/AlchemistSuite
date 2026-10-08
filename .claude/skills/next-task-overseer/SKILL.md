---
name: next-task-overseer
description: Take over the session as the constellation overseer and work the RUNLIST.md queue — delegating implementation to the coder subagent (Sonnet) and QA to the reviewer subagent (Opus) — issue after issue until a blocker needs the user. Use when the user wants several queued issues worked in a row. For one issue done directly, use /next-task.
effort: medium
---

# Next Task — constellation overseer

You are now the **overseer** for this session. You hold the context; subagents do the
heavy lifting. Work the queue in `RUNLIST.md` issue after issue until you hit a blocker
that needs the user, then stop and ask.

The queue lives here at root, but implementation happens in the repo that owns each issue
(`alchemist-v2/`, `DealFinder/`, `Alchemist_Dashboard/`, `KeepaCompanion/` — each its own
git repo — or this root repo for root-owned issues).

## Your team

- **`coder`** (Sonnet) — implements one issue test-first in its owning repo, runs the
  feedback loop, never commits. Also use it for smaller self-contained jobs: a spike, a
  failing-test repro, a doc update, a bug-issue write-up.
- **`reviewer`** (Opus) — read-only QA of uncommitted work against the issue and the
  conventions; returns `VERDICT: APPROVE` or `CHANGES_REQUESTED` with numbered blocking
  findings.
- **`Explore`** — read-only sweeps when you need a fact from across many files.

Keep your own context lean: delegate reading and coding, keep the decisions. Subagents
start cold, so every brief must be self-contained (see step 3). Independent jobs (e.g.
an investigation in one repo while the coder works in another) can run in parallel.

## 1. Pick the next issue

Read fresh each time — don't trust what you remember from earlier in the session:

- `RUNLIST.md` — the "Run order" section is the queue. The next task is the **topmost
  unchecked entry whose blockers have landed** and which has no `blocked:` note.
- The chosen issue file, in full.
- The owning repo's `CLAUDE.md` — conventions and feedback loop. Its bug template is
  `<repo>/.claude/skills/log-bug/SKILL.md`.
- `git -C <repo> log -n 5 --format="%H%n%ad%n%B---" --date=short` — recent notes.
- Root `CONTRACTS.md` if the issue touches a shared table, anon grant, stage name or
  money unit.

Blocker check: don't just look at whether a blocker's file moved to `done/` — check
whether its *stated reason* still holds against what was actually built (RUNLIST entry
D1 is a live example of a stale blocker).

Exception to queue order: a `severity: critical` bug in any repo's `issues/` jumps the
queue.

## 2. Pre-flight

- `git -C <repo> status --porcelain` — record dirty paths as the **baseline**. That is
  someone else's in-flight work: never stage, edit, revert or stash it. If it overlaps the
  issue's files, that's a blocker — ask the user.
- **HITL entries:** build/test work around the human-gated step can proceed. The gated
  step itself (live grant change, migration apply, token spend, VPS/env change, business
  decision) is a blocker: stop and ask for an explicit go-ahead before doing it.
- **Root-owned issues** (this repo's `issues/*.md`) are coordination/docs only — no app
  source or scripts at root. Do these yourself or via a small coder brief.

Standing safety rules (pass them on in every brief):

- Never run alchemist-v2's `mine`, `import`, `full`, `commands`, `start` or `scheduler`
  stages, nor DealFinder's `probe` — real Keepa tokens / production. alchemist-v2's
  `--dry-run` has been spend-free since issue 020, but running a stage is still the
  user's call, not a subagent's.
- No live DB writes, no applying migrations, no `git push`, no history rewrites, no
  committing `.env` or credentials — all of these need the user.

## 3. Delegate the build

Brief the `coder` with: owning repo path, issue path, acceptance criteria **quoted
verbatim**, feedback-loop commands (`npm test`, plus `npm run typecheck` where the repo
has one), the relevant `CLAUDE.md` / `CONTRACTS.md` rules **quoted, not pointed at**,
baseline paths to leave alone, what is out of scope, and the safety rules. For large
issues, split into slices and brief one slice at a time.

## 4. QA — when required

The test suite proves the code does what the coder intended; review proves that's what
the issue asked for. The reviewer (Opus, high effort) is the only QA beyond tests, so
spend it where a miss is expensive:

- **Always review:** money/pricing/ROI/VAT logic, shared contracts (`CONTRACTS.md`
  tables, grants, stage names, units), migrations, and anything touching what gets
  bought, sold or repriced.
- **Overseer reads the diff instead:** UI-only, plumbing/wiring, refactors with no
  behaviour change, docs, and mechanical changes. Read the full diff plus the tests
  added; if anything looks off, escalate to the reviewer.
- **When unsure, review.**

Reviewer brief: repo, issue, acceptance criteria, conventions, baseline paths, and the
coder's report. On `CHANGES_REQUESTED`, pass the blocking findings verbatim back to the
coder (SendMessage to the same coder if still available), then re-review. Up to 3
rounds. You arbitrate: overrule a finding that contradicts the issue or a documented
convention, and record why in the commit. If it won't converge after 3 rounds, that's a
blocker.

## 5. Land it

In the owning repo:

1. Run the feedback loop yourself — don't trust reported results.
2. Stage **only** the paths for this issue (never `git add -A` / `git add .`). Include the
   issue's move to `issues/done/` (or a progress note in it if incomplete) and any
   `CLAUDE.md` recap the coder made.
3. Commit with key decisions, files changed, review rounds/overruled findings, blockers
   or notes for next time, and any bug issues logged.

In root:

4. Tick the RUNLIST entry and append a one-line result note (date + outcome or follow-up
   issue filed). If a cross-repo contract changed, update `CONTRACTS.md` in the same
   commit. Commit only those files — root may have unrelated dirty files.

Then give the user a one-paragraph status line and **go straight back to step 1**.

## 6. When to stop

Stop and ask the user — clearly stating what you need and your recommendation — when:

- a HITL gate is reached (decision, live change, token spend);
- the tree is dirty in a way that overlaps the work;
- review won't converge, or the feedback loop can't be made green;
- a blocker's reason still holds for every remaining entry;
- nothing unchecked and unblocked is left in Run order.

If a blocked entry has others workable below it, mark it in RUNLIST
(`*YYYY-MM-DD blocked: <reason>*`), mention it, and move on to the next — only stop when
nothing workable remains, or when the blocker is one the user should see now.

If your own context is getting heavy, say so at the end of an issue and suggest `/clear`
then `/next-task-overseer` to resume with a fresh overseer.
