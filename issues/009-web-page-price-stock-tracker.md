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
