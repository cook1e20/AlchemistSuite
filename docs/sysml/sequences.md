# Sequence views: DealFinder probe and Qogita drops

Text versions of the operator's hand-drawn sequence diagrams (2026-11-09), corrected against
`CONTRACTS.md` and the specs in `issues/`. GitHub renders the Mermaid blocks, so edit the text and
review the change in a PR like any other doc. The formal model behind them is
[`alchemist-suite.sysml`](alchemist-suite.sysml); see [README](README.md) for how the two relate.

Written from the coordination docs only. The DealFinder and alchemist-v2 code was not read, so steps
marked *(check)* need confirming in the owning repo.

Arrow key: `->>` call or message, `-->>` reply, `-)` async post (fire and forget).

## 1. DealFinder hourly probe (EU -> UK retail deals)

```mermaid
sequenceDiagram
    autonumber
    actor Op as Operator
    participant DC as Discord
    participant DB as Dashboard
    participant DF as DealFinder (PM2, VPS)
    participant K as Keepa
    participant SP as Amazon SP-API
    participant SB as Supabase

    loop every hour
        alt 21:00-05:00 UK (Keepa overnight pause, owned by alchemist-v2's miner)
            DF->>DF: skip tick
        else day
            DF->>K: deals feed (EU price drops)
            K-->>DF: deals
            DF->>SB: products cache pre-filter (match ASIN/EAN)
            SB-->>DF: known products + stored UK signal
            opt 08:00-20:00 UK (DealFinder's SP-API window, ADR 0001)
                DF->>SP: competitive pricing + fees estimate (free)
                SP-->>DF: prices, fees
                DF->>DF: pre-screen: drop confident rejects (no Keepa spend)
            end
            DF->>K: UK /product for survivors (buybox=1 on stage 2)
            K-->>DF: avg30/avg90, sales rank drops, monthly sold, offers
            DF->>DF: evaluateDeal (landed-cost ROI)
            DF->>SP: gating + offers batch (Amazon on listing) (check)
            SP-->>DF: labels (not filters)
            DF->>SB: read deal_notifications (dedupe)
            SB-->>DF: last notified price
            DF->>SB: upsert deals, ungating_opportunities, products write-through
            DF-)DC: deal card (winners only)
            DF->>SB: record deal_notifications, status -> notified
        end
    end
    DC-)Op: alert
    Op->>DB: buy / dismiss
    DB->>SB: deals.status -> bought / dismissed (anon, column-scoped)
```

## 2. Qogita drops, as built (alchemist-v2 062-065, 069)

```mermaid
sequenceDiagram
    autonumber
    actor Op as Operator
    participant DC as Discord #wholesale
    participant A as alchemist-v2 (scheduler, VPS)
    participant Q as Qogita API
    participant SQ as SQLite (VPS)
    participant SB as Supabase
    participant K as Keepa
    participant SP as Amazon SP-API

    loop hourly at :07 (QOGITA_DROPS_ENABLED)
        A->>Q: request catalogue download (invoice-only account)
        Q-->>A: file ready (new build, or cached up to ~1 h)
        alt same filename as last pull
            A->>A: stop, nothing new
        else new file
            A->>Q: download CSV (streamed, never buffered)
            Q-->>A: ~250k rows
            A->>SQ: append price_changes, update price_summary
            A->>SB: read qogita_blocked_brands
            SB-->>A: blocked brands
            A->>A: detect drops (>=10% under avg30, stock value >= £500, not pre-order, brand not blocked)
            A->>SB: match GTINs in products
            SB-->>A: stored buy-box averages, fees inputs
            A->>A: estimate ROI 30/90 from stored data (no live Keepa or SP-API call)
            A->>SB: upsert qogita_drop_candidates (matched and unmatched)
            opt QOGITA_ALERTS_ENABLED and lower ROI >= 20% and profit >= £2/unit
                A-)DC: drop card
            end
            A->>SB: rebuild supplier_best_offers (BEST_OFFERS_ENABLED)
        end
    end

    Note over A,SP: 19:50 UK - night confirmation (065)
    A->>SB: matched candidates -> one wholesale_prescreen job
    A->>SP: pricing + fees (20:00-08:00 UK window only)
    SP-->>A: prices, fees
    A-)DC: job summary
    A->>SB: unmatched (max 200/day) -> Keepa backfill queue
    Note over A,K: 21:00-05:00 UK - miner window
    A->>K: /product for queued GTINs
    K-->>A: UK signal
    A->>SB: enrich products (posted next day)
    DC-)Op: alerts
```

## 3. Qogita drops as a DealFinder feed (planned, DealFinder 067, dark)

`issues/in-progress/spec-qogita-dealfinder-feed.md`. This is the step the hand drawing puts on "Alchemist": the live
Keepa check of a drop. It belongs to DealFinder, in its day window, reading what alchemist-v2 wrote.

```mermaid
sequenceDiagram
    autonumber
    participant DC as Discord #wholesale
    participant DF as DealFinder
    participant SB as Supabase
    participant SP as Amazon SP-API
    participant K as Keepa

    loop each tick, 08:00-20:00 UK (QOGITA_FEED_ENABLED)
        DF->>SB: read qogita_drop_candidates not yet evaluated
        SB-->>DF: candidates (biggest drops first)
        loop per candidate
            opt no uk_asin
                DF->>SP: catalogue lookup by GTIN
                SP-->>DF: ASIN (none = skip, logged)
            end
            DF->>SP: pricing + fees (free pre-screen, sell = max(live BB, stored averages))
            SP-->>DF: confident reject stops here
            DF->>K: UK /product, buybox=1 (max 200/day)
            K-->>DF: BB avg30/avg90, velocity, offers
            DF->>SB: writeBuyBoxAverages to products
            DF->>DF: evaluateWholesale (cost ex VAT x1.2, lower of ROI30/ROI90 >= 20%)
            DF->>SP: gating + Amazon on listing (labels)
            opt passes, not posted today (or dropped a further 10%)
                DF-)DC: DealFinder card, footer "DealFinder · Qogita"
            end
        end
    end
```
