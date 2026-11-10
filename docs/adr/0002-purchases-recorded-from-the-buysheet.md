# Purchases are recorded from the BuySheet, and each becomes a lot

Every buy, retail or wholesale, is recorded by SellerAmp's "send to sheets" on the operator's phone, and the sheet's formula SKU is the Seller SKU used in SellerFuse. We decided the BuySheet stays the single place purchases are recorded: alchemist-v2 ingests each row into a `lots` table keyed on that SKU, with a Keepa snapshot taken at ingest, and the expected-vs-actual feedback loop (winners and top-ups, post-mortems, a per-source report) is built on it. The Deals tab's "bought" button is retired; attribution to the alert that led to a buy is worked out by matching the ASIN against recent alerts.

**Considered options**
- **A purchase record created by "bought" on the Deals tab.** Rejected: the operator buys from the phone and never visits the Deals tab, and wholesale and own-find buys have no deal row. It would add admin and miss most buys.
- **Keep lots inside the daily `analytics_cache` JSON.** Rejected: the loop needs per-lot history (snapshot, expected figures, realised ROI, flags), which a daily blob makes awkward. The free-plan size limit that encouraged it no longer applies.

**Consequences.** A buy not sent to the sheet is invisible to inventory, finance and the loop. Stock at the prep centre is derived (bought - at Amazon - sold), not observed, and old remainders are flagged rather than trusted.

Detail: `issues/spec-business-loop.md`, challenge 1.
