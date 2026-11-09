# SysML v2 model of the constellation

A start on modelling the Alchemist Suite in SysML v2, beginning with the operator's hand-drawn
sequence diagrams of the DealFinder probe and the Qogita drop scan (2026-11-09).

| File | What it is |
|---|---|
| [`sequences.md`](sequences.md) | The sequence views as Mermaid. Renders on GitHub; the quickest thing to edit and review. |
| [`alchemist-suite.sysml`](alchemist-suite.sysml) | The model in SysML v2 textual notation: parts, items, requirements, the deal lifecycle and the two interactions. |

## How the drawings fit SysML v2

The drawings are **sequence diagrams**. In SysML v2 a sequence diagram is a *view* of an
**interaction**: an `occurrence def` whose lifelines are `part` usages, each with ordered
`event occurrence`s, and whose arrows are `message ... of <item> from <event> to <event>`.

SysML v2 separates the model from its views. The same `part def DealFinder` that is a lifeline here is
also a block in the structure view and the subject of requirements. The constellation's existing docs
map onto the model like this:

| SysML v2 element | Constellation source |
|---|---|
| `part def` + connections (structure / interconnection view) | README repo list, CONTRACTS.md section 1 ownership |
| `item def` (what flows on messages) | table and payload shapes, CONTRACTS.md section 2 |
| `requirement` + `satisfy` | SP-API window (ADR 0001), Keepa split (section 5), ROI floors in the specs |
| `state def` (state machine view) | `deals` status lifecycle |
| `occurrence def` with messages (sequence view) | the specs' Solution sections, these drawings |
| `use case` (not started) | user stories in `issues/constellation-prd.md` |

## Review of the hand drawings

Both drawings have the right shape: one system calls out to Keepa, Amazon and Supabase, then alerts
Discord and writes to the DB. The corrections, all reflected in `sequences.md`:

**DealFinder**
1. The middle lifeline is **DealFinder**, a separate repo and PM2 process, not alchemist-v2.
2. The products cache check comes straight after the Keepa deals feed and before Amazon, so known
   products skip work. It reads the `products` catalogue rather than "matches".
3. The Amazon step is the free SP-API pricing and fees pre-screen. It only runs 08:00-20:00 UK, and a
   confident reject never reaches Keepa. Gating is a separate SP-API check *after* the deal is
   evaluated, and it labels the card rather than filtering it.
4. The second Keepa call is the UK `/product` lookup (buy-box averages, velocity), not "filtered list".
5. Missing: the `evaluateDeal` ROI step, the 21:00-05:00 overnight pause, the `deal_notifications`
   dedupe read before posting, and the operator's buy/dismiss back through the Dashboard.
6. The DB write happens alongside the alert, not only at the end; `deals` is the record the
   Dashboard reads.

**Qogita**
1. The scan as built is **alchemist-v2** (062-065), hourly at :07.
2. A Qogita catalogue request is asynchronous and cached for up to an hour: if the filename has not
   changed there is nothing to do.
3. Missing lifeline: **SQLite on the VPS**, which holds the price history the drop is measured
   against (today vs the 30-day average). Without it there is no "drop".
4. The instant alert does **not** call Keepa. It estimates ROI from what is already in `products`.
   Unmatched GTINs are queued for the overnight miner (max 200/day) and the matched ones go to a
   19:50 SP-API pre-screen job. The live Keepa check you drew is the *planned* DealFinder feed
   (067, view 3 in `sequences.md`).
5. The candidates are written to `qogita_drop_candidates` *before* the alert; the alert only goes
   out if the drop clears the floors (lower ROI >= 20%, profit >= £2/unit).
6. Amazon is drawn but never used. It is used, at night (065) and in the planned feed (067).

## Editing together

- **Now:** edit `sequences.md` in a branch or PR. Mermaid is plain text, so diffs and review comments
  work; GitHub and claude.ai render it.
- **For the full model:** open `alchemist-suite.sysml` in SysIDE (VS Code extension, free editor
  features), SysON (open-source web modeller that draws diagrams from the model), or the SysML v2
  Pilot Implementation in Jupyter. The `.sysml` file is the source of truth; diagrams are views
  generated from it.
- Keep the two in step by hand until a tool generates the views. When a spec changes a flow, update
  the interaction in the `.sysml` file and the matching Mermaid block in the same commit.

## Caveats

- Written from CONTRACTS.md, RUNLIST.md and the specs. The DealFinder and alchemist-v2 code was not
  read; steps marked *(check)* in `sequences.md` need confirming there.
- The `.sysml` file has not been run through a SysML v2 parser yet.
