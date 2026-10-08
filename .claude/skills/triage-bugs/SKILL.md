---
name: triage-bugs
description: Triage the bug backlog in issues/ — dedupe, confirm each bug still reproduces, set honest severities, and flag ones needing a human decision. Use when the user says "triage bugs" or before a /next-task-overseer run on a queue containing bug issues.
---

# Triage Bugs

Stress-test the bug backlog so a /next-task-overseer run doesn't burn iterations on duplicates,
already-fixed bugs, or non-bugs. Most of this is interrogating the repo, not the user —
ask the user only about the genuinely ambiguous ones.

## 1. Collect

Read every file in `issues/*.md` with a `kind: bug` line. Also skim `issues/done/` and
`git log` since each bug was filed — a later commit may have fixed it incidentally.

If there are no open bug issues, say so and stop.

## 2. Verify each bug against the repo

For each bug, answer from the code (cheaply — read the suspected location, run the repro
or a targeted test if quick; don't start a debugging session):

- **Still real?** Does the described behavior still exist, or was it fixed since filing?
- **Duplicate?** Same defect as another open bug, or a symptom of one?
- **Actually a bug?** Or plausibly intended behavior / a missing feature that belongs in
  the spec flow (`/grill-with-docs` → `/to-spec`) instead?
- **Severity honest?** critical = data loss, crash, or blocks other work; major = visible
  defect with a workaround; minor = cosmetic or edge case.
- **Right label?** `auto` only if the fix is mechanical once the bug is confirmed; if it
  needs a product or design call, it's `HITL`.

## 3. Ask the user — batched, ambiguous items only

Collect every question into ONE round: "is this intended behavior?", "worth fixing before
launch or park it?", "these two look like the same bug — merge?". Do not ask about bugs
the repo already answered.

## 4. Apply the outcomes

- **Fixed or not-a-bug:** move to `issues/done/` with a one-line note at the top saying
  why it was closed without work.
- **Duplicates:** fold any extra detail into the surviving issue; move the duplicate to
  `issues/done/` with a pointer to the survivor.
- **Kept:** correct the `severity:` and `type:` lines in place; sharpen the repro if
  verification taught you something.
- **Park-for-later:** keep the file, set `severity: minor`, and note the user's call.

## 5. Report and commit

Summarize in a short table: kept (with severity), closed (with reason), merged. Commit
the queue changes with a message listing the triage decisions, so the next run starts
from the cleaned backlog.
