---
name: log-bug
description: Log a bug as an issue file in issues/ without derailing the current task. Use when the user spots a bug that shouldn't be fixed right now — "log a bug", "log this", "found a bug, put it in the queue".
---

# Log Bug

Capture a bug as a normal issue file at the back of the queue, then return to whatever
was in progress. Do NOT fix the bug, do NOT start investigating beyond what's needed to
write a useful issue.

## 1. Gather the minimum

From the user's description (and anything already in context), establish:

- What happens vs what should happen
- How to reproduce it (steps, input, or the code path involved)
- Suspected location, if apparent — a guess is fine, "unknown" is fine

If a field is genuinely unknown, write "unknown" rather than interrogating the user.
One clarifying question maximum, and only if the report is too vague to ever act on.

## 2. Dedupe check

Skim `issues/*.md` for an existing issue covering the same defect (check `issues/done/`
too — it may already be fixed). If a duplicate exists, add any new detail to that file
instead of creating a new one, and tell the user.

## 3. Write the issue file

Create `issues/NNN-bug-<slug>.md` at the next available number:

<bug-template>
type: auto  <!-- auto unless the fix needs a human decision (product/design call) — then HITL -->
kind: bug
severity: minor  <!-- critical: data loss, crash, or blocks other work | major: visible defect, workaround exists | minor: cosmetic or edge case -->

## Bug

**Spotted while:** what was being worked on, or "reported by user"
**Repro:** steps or failing input
**Expected vs actual:** ...
**Suspected location:** path/to/file.ts, or "unknown"

## Acceptance criteria

- [ ] Failing test reproducing the bug
- [ ] Fix passes `npm run test` and `npm run typecheck`

## Blocked by

None - can start immediately
</bug-template>

Be honest about severity — `severity: critical` jumps to the front of the queue on the
next `/next-task`; almost nothing spotted in passing is critical. When in doubt,
`minor`.

## 4. Return to the task

Confirm the filename to the user in one line and resume the interrupted work. Do not
commit as part of this skill — the file rides along with the next commit (or the user
commits the queue themselves).
