# Target design: the business loop and the sourcing/operations split

Where the constellation is heading, from the 2026-11-10 grill (`issues/spec-business-loop.md`, ADRs 0002-0005).
Today's design is in [`structure.md`](structure.md). Dashed lines are not built yet.

## 1. The capital cycle

The loop the whole suite serves. Each step names who owns it; the dashed steps are the gaps the grill closes.

```mermaid
flowchart LR
    F["Find<br/>sources -> candidates<br/>(DealFinder)"]
    B["Buy<br/>SAS check, send to BuySheet<br/>(operator)"]
    L["Lot created<br/>+ Keepa snapshot, attribution<br/>(alchemist-v2)"]
    T["In transit<br/>bought - at Amazon - sold<br/>(alchemist-v2)"]
    A["At Amazon<br/>hold-or-sell, reprice advice<br/>(Inventory tab)"]
    S["Sold<br/>realised ROI, Finances API + £1 prep<br/>(alchemist-v2)"]
    R["Review<br/>winners, post-mortems, sources<br/>(Review tab)"]

    F --> B
    B --> L
    L -.-> T
    T --> A
    A --> S
    S -.-> R
    R -. "top-up: a new candidate" .-> F
    R -. "post-mortem: improve analysis" .-> F
    S -- "capital back" --> B
```

## 2. Lot states

```mermaid
stateDiagram-v2
    [*] --> InTransit: BuySheet row ingested
    InTransit --> AtAmazon: units appear in Amazon inventory or inbound
    InTransit --> Flagged: over 30 days with units unaccounted
    Flagged --> AtAmazon: found
    Flagged --> WrittenOff: operator confirms lost or returned (not yet specified)
    AtAmazon --> Selling: first sale
    Selling --> Winner: pace at or above expected
    Selling --> Marginal: realised ROI under half predicted, under 10%, or over 50% unsold at 60 days
    Winner --> SoldOut
    Selling --> SoldOut
    Marginal --> SoldOut
    SoldOut --> [*]
    note right of Winner: still at least 20% at the source, so suggest a top-up
    note right of Marginal: post-mortem on the Review tab
```

## 3. Sourcing and operations

Every source writes candidates; DealFinder evaluates all of them with the shared economics and settings.
alchemist-v2 runs operations. Discord gets only urgent, perishable actions (ADR 0005).

```mermaid
flowchart LR
    Sources["sources<br/>Keepa deals · Qogita · eany<br/>supplier emails · SourceWatch · top-ups"]
    C[(candidates)]
    DF["DealFinder: sourcing, by day<br/>match ASIN, free pre-screen, Keepa,<br/>evaluate, gating"]
    BS[BuySheet]
    A2["alchemist-v2: operations, by night<br/>miner, lots, in transit, realised ROI,<br/>winners, post-mortems, best offers"]
    EC[["shared economics<br/>+ settings table"]]
    DC[Discord: urgent only]
    DB["Dashboard<br/>Deals · Inventory · Wholesale · Review<br/>Watches · Finance · Settings"]

    Sources -- candidates --> C
    C --> DF
    DF -- "deals, drops, price-back, top-ups" --> DC
    DF -- deals --> DB
    BS --> A2
    A2 -- "lots, verdicts, review, best offers" --> DB
    A2 -. "winners become top-ups and watches" .-> Sources
    EC --> DF
    EC --> A2
    DB -- "settings edits" --> EC
```
