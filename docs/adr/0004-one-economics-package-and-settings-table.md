# One economics package and one settings table

Fees, VAT, sell basis, ROI floors and prep cost were coded separately in DealFinder, alchemist-v2 and the Dashboard, and had drifted (a 15% stored floor vs 20% shown, buy-box vs new-price basis, £0.50 vs a measured ~£1.05 prep). We decided on a shared TypeScript package, used by all three, holding the canonical rules (sell = lower of buy-box avg30/avg90, never the live buy box; cost = ex VAT x 1.2 + prep + Amazon fees; 20% default floor with per-source overrides), and a Supabase `settings` table, edited from a Dashboard Settings page, for every tunable value. The browser shows server-computed numbers wherever possible.

**Considered options**
- **One service computes all economics** (e.g. an Edge Function the browser calls). Rejected: batch jobs over thousands of rows would pay a network hop per item.
- **Copies kept in step by agreement tests.** Rejected: the drift happened despite reviews; one implementation is cheaper than policing three.
- **`.env` values per repo.** Rejected: a change needs a deploy per repo and the values diverge.

Detail: `issues/spec-business-loop.md`, challenge 3.
