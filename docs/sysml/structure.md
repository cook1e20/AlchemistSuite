# Structure views: context, interconnection, inventory

Text versions of the operator's hand-drawn system diagram (2026-11-10), split into three views so each
stays readable. Built from `CONTRACTS.md` and `RUNLIST.md`, not the child repos' code. Same model as
[`alchemist-suite.sysml`](alchemist-suite.sysml); the sequence views are in [`sequences.md`](sequences.md).

Drawing rules: arrows point from writer to reader; every arrow says what flows; one level per view.

## The goal these views serve

**Track the business, and offer as many pre-filtered buy deals as possible, so the inventory keeps rolling.**

| Part of the goal | What delivers it |
|---|---|
| Track the business | Dashboard Finance tab (`business_snapshots`), Inventory tab (`analytics_cache`) |
| Pre-filtered buy deals | DealFinder (EU/UK retail deals), Qogita drops (alchemist-v2, DealFinder feed planned), supplier best offers (Wholesale tab), wholesale pre-screen |
| Keep the inventory rolling | Inventory tab per-lot table; hold-or-sell verdicts (R51, in progress) |

## 1. Context view: the suite and the outside world

The whole suite is one box. Everything outside it is something it talks to.

```mermaid
flowchart LR
    Op([Operator])
    subgraph Suite[Alchemist Suite]
        S[DealFinder · alchemist-v2 · Dashboard · KeepaCompanion · Supabase]
    end
    K[Keepa]
    SP[Amazon SP-API]
    Q[Qogita API]
    E[eany.io<br/>planned]
    Z[Supplier emails<br/>Zappies, planned]
    GS[Google Sheets<br/>BuySheet]
    DC[Discord]

    K -- "deals feed, product signal" --> Suite
    SP -- "pricing, fees, gating, inventory, orders" --> Suite
    Q -- "catalogue CSV, hourly" --> Suite
    E -. "supplier stock list" .-> Suite
    Z -. "supplier offers" .-> Suite
    GS -- "purchases: cost, qty, SKU, date" --> Suite
    Suite -- "deal cards, drop alerts, stage summaries" --> DC
    DC -- alerts --> Op
    Op -- "buy/dismiss, finance entries, blocked brands, EAN queue" --> Suite
    Suite -- "Finance, Deals, Inventory, Wholesale tabs" --> Op
    Op -- "records purchases" --> GS
```

## 2. Interconnection view: inside the suite

Supabase is the hub: the apps almost never talk to each other directly, they meet in tables. Drawn as two
diagrams, writes then reads, because one diagram with both is the tangle the hand drawing ran into.
Table colour = owning repo (CONTRACTS.md section 2): blue DealFinder, green alchemist-v2, amber Dashboard,
grey KeepaCompanion. Discord and external APIs are in view 1.

### 2a. Who writes what

```mermaid
flowchart LR
    DF[DealFinder]
    A2[alchemist-v2]
    KC[KeepaCompanion]
    Fin[Dashboard<br/>Finance tab]
    Dl[Dashboard<br/>Deals tab]
    Wh[Dashboard<br/>Wholesale tab]

    deals[(deals)]
    dn[(deal_notifications)]
    uo[(ungating_opportunities)]
    products[(products)]
    ac[(analytics_cache)]
    qdc[(qogita_drop_candidates)]
    sbo[(supplier_best_offers)]
    gs[(gating_status)]
    rl[(run_log)]
    bs[(business_snapshots)]
    qbb[(qogita_blocked_brands)]
    cmd[(commands)]
    at[(asin_tracker)]

    DF -- "deals found" --> deals
    DF -- "dedupe" --> dn
    DF -- "gated but good" --> uo
    DF -- "signal write-through" --> products
    A2 -- "Keepa signal, imports" --> products
    A2 -- "daily 04:30" --> ac
    A2 -- "hourly drops" --> qdc
    A2 -- "rebuilt each pull" --> sbo
    A2 -- "gating checks" --> gs
    A2 -- "stage runs" --> rl
    Dl -- "buy / dismiss" --> deals
    Fin -- "manual snapshots" --> bs
    Wh -- "block brand" --> qbb
    Wh -- "queue EAN backfill" --> cmd
    KC -- "triage" --> at

    classDef df fill:#dbeafe,stroke:#1d4ed8,color:#111
    classDef a2 fill:#dcfce7,stroke:#15803d,color:#111
    classDef db fill:#fef3c7,stroke:#b45309,color:#111
    classDef kc fill:#e5e7eb,stroke:#4b5563,color:#111
    class deals,dn,uo df
    class products,ac,qdc,sbo,gs,rl a2
    class bs,qbb,cmd db
    class at kc
```

### 2b. Who reads what

```mermaid
flowchart LR
    deals[(deals)]
    uo[(ungating_opportunities)]
    products[(products)]
    ac[(analytics_cache)]
    qdc[(qogita_drop_candidates)]
    sbo[(supplier_best_offers)]
    gs[(gating_status)]
    rl[(run_log)]
    bs[(business_snapshots)]
    qbb[(qogita_blocked_brands)]
    cmd[(commands)]

    DF[DealFinder]
    A2[alchemist-v2]
    Fin[Dashboard<br/>Finance tab]
    Dl[Dashboard<br/>Deals tab]
    Inv[Dashboard<br/>Inventory tab]
    Wh[Dashboard<br/>Wholesale tab]
    St[Dashboard<br/>Status]

    products -- "cache pre-filter" --> DF
    qdc -. "Qogita feed, planned 067" .-> DF
    cmd -- "queued EANs" --> A2
    qbb -- "blocked brands" --> A2
    deals --> Dl
    uo --> Dl
    bs --> Fin
    ac -- "live check, FBA values" --> Fin
    ac -- "stock, lots, stock health" --> Inv
    sbo --> Wh
    products -- "EAN match" --> Wh
    gs --> Wh
    rl --> St

    classDef df fill:#dbeafe,stroke:#1d4ed8,color:#111
    classDef a2 fill:#dcfce7,stroke:#15803d,color:#111
    classDef db fill:#fef3c7,stroke:#b45309,color:#111
    class deals,uo df
    class products,ac,qdc,sbo,gs,rl a2
    class bs,qbb,cmd db
```

## 3. Inventory: how the Inventory tab is fed

There is no separate inventory manager. The Inventory tab reads `analytics_cache`, written once a day by
alchemist-v2's `analytics` stage.

```mermaid
flowchart LR
    Op([Operator])
    GS[Google Sheets<br/>BuySheet]
    subgraph SP[Amazon SP-API]
        inv[inventory summaries]
        ord[orders + order items]
        lst[listings report]
        off[offers batch]
    end
    K[Keepa<br/>buy box, Amazon share]
    AN[alchemist-v2<br/>analytics stage<br/>daily 04:30 UK]
    subgraph AC[analytics_cache]
        fba[fba_stock<br/>per ASIN, BuySheet blended cost]
        lot[lot_inventory<br/>per Seller SKU lot]
        sh[stock_health<br/>hold-or-sell inputs]
    end
    Inv[Dashboard Inventory tab]
    Fin[Dashboard Finance tab]

    Op -- "records each purchase" --> GS
    GS -- "cost, qty, SKU, purchase date" --> AN
    inv -- "units in every bucket" --> AN
    ord -- "sales per SKU" --> AN
    lst -- "my price, open date" --> AN
    off -- "buy box now, lowest FBA" --> AN
    K -- "BB avg30/avg90, Amazon share" --> AN
    AN --> fba
    AN --> lot
    AN --> sh
    fba -- "ASIN summary" --> Inv
    lot -- "per-lot table" --> Inv
    sh -. "verdicts: Sell now / Hold / Reprice / Healthy<br/>Dashboard 026, not built" .-> Inv
    lot -- "FBA and waiting-to-ship values" --> Fin
    fba -- "live check" --> Fin
```

Status per RUNLIST R51 (last note 2026-10-30): the `stock_health` column is applied live; the operator
still has to set `SP_API_SELLER_ID` and deploy alchemist-v2, then Dashboard 026 builds the verdict table.
Stock at a 3PL or prep centre before it ships to Amazon is invisible to SP-API and is not estimated.

## Differences from the hand drawing

- **"Inventory mgr" is not an app.** It is the alchemist-v2 `analytics` stage. "Sheets" is the BuySheet.
- **The Inventory tab does not write anything.** It only reads `analytics_cache`. The Finance tab is
  the only one that writes your own numbers (`business_snapshots`).
- **Alchemist is missing most of its links:** Qogita, Keepa (overnight miner and inventory), SP-API
  (night pre-screen, gating, inventory, orders), Google Sheets and Discord.
- **Email** goes to DealFinder (Zappies, not built). **eany.io** goes to alchemist-v2 (R55, not built).
- **Keepa's two boxes** are right: the deals feed (DealFinder) and product data (both apps).
- The Dashboard's Wholesale tab reads `supplier_best_offers` and `products`, and writes the EAN queue
  and blocked brands.
