type: HITL
kind: coordination

## Parent PRD

`issues/constellation-prd.md`. Backlog idea, not yet scoped. Grill it (`/grill-me`) before
it gets a RUNLIST slot or an owning repo.

## Idea (operator, 2026-10-09)

Other sellers use page-watch sites (Visualping, Distill, PageCrawl-style tools). You paste
a product URL, click the price or the "out of stock" element on the rendered page, and the
service re-fetches the page on a schedule (every few hours, or daily) and alerts when that
element changes. We want the same thing inside the constellation.

## Why it might earn its place

- **Source side:** this is what matters most. Keepa and SP-API already watch Amazon. Nothing
  here watches the non-Amazon retailers and suppliers a buy could come from (clearance
  pages, restocks, supplier price drops).
- **Restocks:** an "out of stock → in stock" alert on a known-good ASIN's source page is a
  buy signal DealFinder can't produce. The Keepa deals feed only sees Amazon-sold drops.
- **Alerts:** these would land in the same Discord channel as the existing ones.

## Open questions (for the grill)

1. **Which sites?** Retail and supplier sites only, or Amazon pages too? Amazon is already
   covered more cheaply and reliably by Keepa tracking or SP-API, so scraping Amazon is
   probably a non-goal.
2. **Element picking:** do we build a click-to-select UI (render the page, store a CSS
   selector / XPath), or start simpler with the price from the page's JSON-LD or
   `og:price` metadata plus manual selector entry?
3. **Fetching:** plain HTTP vs a headless browser. Many retailers render the price in
   JavaScript or block bots. Where would Playwright/Chromium run (the VPS has spare RAM, at
   47% used), and how many watches can it carry?
4. **Cadence and politeness:** how often to check each watch (daily, every few hours,
   configurable). Do we respect robots.txt and each site's terms? Does a single IP get
   blocked?
5. **Link to the constellation:** a watch could tie to an ASIN/EAN so a source price
   change re-runs the ROI model (`deal-economics`) and alerts only when it clears the floor.
   That's a big step up from "price changed".
6. **Storage:** at most a few new tables (watches, latest value, change log), counted
   against the free-plan DB cap (RUNLIST R1).
7. **Owner:** which repo owns it? Options are a new sibling repo, alchemist-v2 as a new
   stage, or DealFinder. The UI to add a watch could be the dashboard or KeepaCompanion
   (the extension is already on the page, so it could "click to track" from there).

## Not yet decided

Everything above. No build until the grill settles scope and owner.

## Grill round 1 (2026-10-13)

Operator answers:

1. **Sites:** retailers and suppliers only. Amazon pages are a non-goal (Keepa and SP-API cover them).
2. **Element picking:** follow what the established tools do (see research below).
3. **Fetching:** plain HTTP preferred, open to a browser where research says it's needed.
4. **Cadence:** daily or twice daily.
5. **Tie-in:** yes. A watch links to an ASIN/EAN and a source change re-runs the ROI model.
6. **Storage:** a few tables in the shared Supabase, counted against the free-plan cap.
7. **Owner/UI:** a new Chrome extension rather than growing KeepaCompanion.

Research (how the existing tools solve 2 and 3):

- **changedetection.io** (open source): its restock/price mode fetches with plain HTTP and reads the
  page's structured product data first (JSON-LD, microdata, OpenGraph: price + availability), with
  a stock-keyword text scan as fallback. A Playwright/Chrome fetcher is an opt-in per watch for
  pages that render the price in JavaScript.
- **Distill.io**: click-to-select element picker (stored as CSS/XPath, regex refinable). Two run
  modes: cloud monitors (their servers, 24/7) and local monitors (the user's own browser via the
  extension, needs the browser open, gets past logins and most bot checks).
- Structured-data coverage is uneven: Product schema is common on mid/large retailers (needed for
  Google Shopping), much rarer on small sites and trade/supplier portals.

Proposed shape (for round 2):

- **Extension = add a watch.** On the retailer page: auto-detect price/stock from structured data;
  if none, click the price/stock element to store a selector. Link the watch to an ASIN/EAN.
- **Checker on the VPS = run watches.** Twice daily, plain HTTP, structured data first, then the
  stored selector. A watch that fails plain HTTP (JS-rendered or blocked) is flagged `needs_browser`
  and checked with headless Chromium; at twice-daily cadence that costs little.
- **Alert:** restock always; price drop only when the ROI against the linked product's cached UK
  sell price clears the floor. Same Discord channel.

Open for round 2: watch volume, supplier pages behind a trade login, alert rule, repo layout.

## Grill round 2 (2026-10-13) — scope settled

1. **Volume:** hundreds at first, possibly thousands. Twice daily that is at most a few thousand
   plain-HTTP fetches a day, which the VPS handles easily. Headless Chromium stays a per-watch
   fallback, never the default, so cost scales with the JS-rendered/blocked minority only.
   The change log needs a retention rule from day one (DB cap).
2. **Logins:** none in phase 1. Every watch must be fetchable from the VPS without credentials.
   Logged-in supplier pages (extension-local checks) are a later phase, if ever.
3. **Alert rule:** one rule. Alert when a watch moves INTO "in stock AND ROI ≥ floor" (ROI from
   the source price against the linked product's cached UK sell price). Fires on that
   transition, not on every check that stays true. No plain "price changed" alerts.
4. **Owner:** a new sibling repo (working name `SourceWatch`) holding both the Chrome extension
   (add a watch: auto-detect from structured data, else click to pick a selector; link ASIN/EAN)
   and the VPS checker (PM2 process). Shares the Alchemist Supabase project; its tables go into
   CONTRACTS.md when specced.

Next: `/to-spec` → `/to-tickets` in the new repo (RUNLIST R41).
