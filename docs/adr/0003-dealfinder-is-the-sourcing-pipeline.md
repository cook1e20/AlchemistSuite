# DealFinder is the sourcing pipeline; alchemist-v2 is operations

The two apps grew by source (DealFinder for retail deals, alchemist-v2 for wholesale and the catalogue), so each built its own Keepa lookups, SP-API pre-screen, ROI evaluation, gating and Discord alerts, and each new source had to pick a side (the Qogita spec reversed its choice within three days). We decided to split by stage instead: every source (Keepa deals, Qogita, eany, Zappies, SourceWatch, top-ups) produces a candidate in one generic `candidates` table, and DealFinder screens, evaluates and alerts all of them. alchemist-v2 owns operations: the catalogue miner, source pulls, BuySheet, lots, inventory, finance and the feedback loop. Its own drop alerts and duplicate evaluators retire as DealFinder covers them.

**Considered options**
- **Merge the two repos.** Rejected: a big-bang change; two processes with one clear job each is enough, and the Keepa/SP-API time split then matches real work (sourcing by day, operations by night).
- **Keep the source-based split and share a library.** Rejected as the target: it removes copied code but leaves every new source with a choice of pipeline.

**Consequences.** A new source is a new writer of `candidates`, not a new contract or pipeline. The best-offers list stays in alchemist-v2 as a batch over its catalogue data, so "one pipeline" means one set of economics (ADR 0004), not one process for every evaluation.

Detail: `issues/spec-business-loop.md`, challenge 2.
