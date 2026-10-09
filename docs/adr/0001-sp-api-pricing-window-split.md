# SP-API pricing and fees calls are split by time window, not throttled

DealFinder and alchemist-v2 share one seller account, so they probably share the competitivePrice and getMyFeesEstimates allowances (0.5 req/s each). DealFinder's pre-screen saturates both during its run. On a 429 it falls through to Keepa, which costs it tokens and cycle time but never causes a false reject.

We decided that DealFinder owns those two operations 08:00–20:00 and alchemist-v2 owns them 20:00–08:00. This matches the existing Keepa token rotation, when DealFinder is paused. alchemist-v2's wholesale pre-screen therefore prices supplier lines only at night. During the day it uses only the catalog lookup, which DealFinder never calls.

**Considered options**
- **Sharing the allowance by throttling**, e.g. alchemist-v2 at 25% of the rate during the day with a 429 circuit breaker. Rejected for v1: it still slows DealFinder, and it makes clashes probabilistic rather than impossible.
- **Separate LWA apps**, which would give separate allowances. Not yet confirmed whether the two projects already use different apps. If they do, a daytime pricing lane becomes cheap and this ADR can be superseded.

**Consequences.** Wholesale pre-screen results for prices, fees and the Keepa shortlist arrive around 20:30, not straight away. Any new SP-API pricing consumer must pick a window rather than share one.
