# Alchemist Suite

The constellation's shared language: sourcing stock for Amazon UK FBA from supplier lists, EU/UK retail deals and a permanent product catalogue.

## Wholesale sourcing

**Stock list**:
A supplier's spreadsheet of what they can sell us, one row per product, with a barcode and a trade cost.
_Avoid_: Price list, catalogue (the catalogue is `products`), wholesale file

**Supplier line**:
One row of a stock list: barcode, supplier cost, stock available, plus whatever descriptive columns the supplier sends.
_Avoid_: Row, item, SKU

**Wholesale pre-screen**:
The free SP-API pass over a stock list that decides which supplier lines are worth a Keepa token. It is the wholesale sibling of DealFinder's pre-screen and the miner pre-screen.
_Avoid_: Triage (that is the manual per-ASIN state in KeepaCompanion), scan (the existing match against `products`)

**Shortlist**:
The supplier lines, one entry per candidate ASIN, that pass the wholesale pre-screen and are queued for Keepa.
_Avoid_: Passes, hits, deals

**Wholesale scan**:
Matching a stock list's barcodes against the existing `products` catalogue. It spends no API calls.
_Avoid_: Wholesale search (the page's name, not the operation)

## Shared resources

**SP-API window**:
The hours in which a project owns the shared SP-API pricing and fees allowance. DealFinder owns 08:00–20:00 and alchemist-v2 owns 20:00–08:00.
_Avoid_: Rotation (that word is for the Keepa token split)

**Triage**:
A manual per-ASIN decision state recorded in KeepaCompanion's `asin_tracker`.
_Avoid_: Using it for any automated screening pass
