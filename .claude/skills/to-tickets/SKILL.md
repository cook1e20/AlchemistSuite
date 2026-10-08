---
name: to-tickets
description: Break a spec, plan, or the current conversation into tracer-bullet tickets, each declaring its blocking edges and auto/HITL type, written as one local markdown file per ticket in issues/. Run after /to-spec, in the same session.
disable-model-invocation: true
---

# To Tickets

Break a spec, plan, or conversation into a set of **tickets**: tracer-bullet vertical slices, each declaring the tickets that **block** it. `/next-task` (one per fresh context) and `/next-task-overseer` (several in a row via subagents) work them.

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes a spec path (e.g. `issues/spec.md`) as an argument, read it in full.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Ticket titles and descriptions should use the vocabulary in `GLOSSARY.md` (if it exists), and respect ADRs in `docs/adr/` in the area you're touching.

Look for opportunities to prefactor the code to make the implementation easier. "Make the change easy, then make the easy change."

### 3. Draft vertical slices

Break the work into **tracer bullet** tickets.

<vertical-slice-rules>

- Each slice cuts a narrow but COMPLETE path through every layer (schema, API, UI, tests): vertical, NOT a horizontal slice of one layer
- A completed slice is demoable or verifiable on its own
- Each slice is sized to fit in a single fresh context window
- Any prefactoring should be done first

</vertical-slice-rules>

Give each ticket its **blocking edges**: the other tickets that must complete before it can start. A ticket with no blockers can start immediately.

Give each ticket a **type**: `auto` (can be built and committed with no human input) or `HITL` (needs a human: a design call, a review, or a manual step such as creating a third-party account or setting Vercel env vars). Prefer auto. Anything that only a human can do outside the codebase is HITL, and is a good candidate for `/wizard`.

**Wide refactors are the exception to vertical slicing.** A **wide refactor** is one mechanical change (rename a column, retype a shared symbol) whose **blast radius** fans across the whole codebase, so a single edit breaks thousands of call sites at once and no vertical slice can land green. Don't force it into a tracer bullet; sequence it as **expand–contract**. First expand: add the new form beside the old so nothing breaks. Then migrate the call sites over in batches sized by blast radius (per package, per directory), each batch its own ticket blocked by the expand, keeping tests green batch to batch because the old form still exists. Finally contract: delete the old form once no caller remains, in a ticket blocked by every migrate batch.

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each ticket, show:

- **Title**: short descriptive name
- **Type**: auto / HITL
- **Blocked by**: which other tickets (if any) must complete first
- **What it delivers**: the end-to-end behaviour this ticket makes work

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the blocking edges correct: does each ticket only depend on tickets that genuinely gate it?
- Are the right tickets marked auto and HITL?
- Should any tickets be merged or split further?

Iterate until the user approves the breakdown.

### 5. Write the ticket files

Write one file per ticket at `issues/NNN-<slug>.md`, numbering from the next free number (check `issues/` and `issues/done/`), in dependency order (blockers first) so each "Blocked by" can name real filenames. One ticket per file, never a combined file. Do NOT create GitHub issues.

Do NOT modify the spec file.

<ticket-template>
type: auto  <!-- auto (no human input needed) or HITL (has a human-gated step) -->

## Spec

`issues/spec.md` (or whichever spec was used; omit if there was none)

## What to build

The end-to-end behaviour this ticket makes work, from the user's perspective, not a layer-by-layer implementation list.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2

## Blocked by

- `issues/NNN-<slug>.md`, or "None - can start immediately"
</ticket-template>

Avoid specific file paths or code snippets in ticket bodies: they go stale fast. Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it and note briefly that it came from a prototype.

### 6. Hand off

Tell the user the tickets are written, then the next step: `/clear`, then `/next-task` (one ticket per fresh context) or `/next-task-overseer` (works the queue until it needs you).
