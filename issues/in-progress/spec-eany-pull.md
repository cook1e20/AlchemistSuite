# Spec: eany.io automated pull (grilled 2026-11-06)

Part B of the supplier-tabs idea; Part A is `spec-supplier-best-offers.md` (R54). Pulls eany.io's catalogue on a schedule instead of the manual button → email → link → download, and feeds it into the same history and best-offers pipeline as Qogita.

## Problem Statement

Getting an eany export by hand means pressing a button, waiting for an email, clicking a link and waiting for a download. The full catalogue takes 15+ minutes to prepare. So eany data is pulled rarely, there is no price history, and nothing compares it to Amazon unattended.

## Facts established 2026-11-06 (capture session in the operator's Chrome)

- **Request:** Export / download → CSV or Excel → scope Hot deals / Full catalogue / Trending / Wishlist. The page calls `backend.eany.io/api/v1/exports` (create) and `GET .../exports?scope[]=full_catalog`. The backend is cross-origin, so it authenticates with a bearer token taken from the NextAuth session (`eany.io/api/auth/session`); the extension did not expose its value.
- **Email:** from `no-reply@eany.io` to `jurassicdesignlabs@gmail.com`, subject "Your catalogue export is ready", with format, scope, row count and the link `http://eany.io/exports/<uuid>/download`. Expiry seen: 6 h (2026-10-30) and ~26 h (2026-11-06). Hot deals arrived within minutes; the full catalogue was not ready after 15+ minutes.
- **Download:** the link page fetches `eany.io/api/exports/<uuid>/download` (same origin, file in the response body, 207 KB for 1,196 rows XLSX), authorised by the httpOnly session cookie. Without a session the link 307s to `/login` (tested from the VPS).
- **Bot protection:** eany.io loads a ~210 KB script from an obfuscated path (`/1u4h/...`) behind Cloudflare. A scripted login from a datacentre IP may be challenged; a reused session cookie is less exposed.
- **File (Hot deals sample, `catalogue_export_2026-11-06_151011.xlsx`):** columns `ean, title, brand, mpn, asin, category, price, stock_quantity, moq, image, url, de_price, uk_price, fr_price, es_price, it_price`. eany supplies its own ASIN match. Full catalogue ~817k-852k rows.
- **Full catalogue email (2026-11-06):** CSV, 830,032 rows, Gmail received it 13:12:55Z, 2m41s after the Hot deals email. The link expired at "7:12 PM" (6 h; the Hot deals link ran to the next day, so the expiry depends on scope). It had expired before the file was checked (21:55Z), so the file below is the 2026-10-30 full export from Downloads.
- **Full catalogue CSV format (2026-10-30 export, 238 MB):** different from the Hot deals XLSX. It has **11 columns only**: `ean;title;brand;mpn;asin;category;price;stock_quantity;moq;image;url`, with no `de/uk/fr/es/it_price`. The delimiter is a **semicolon**. Text fields are double-quoted and **can contain embedded newlines**, so line count (851,574) is not row count; use a real CSV parser, never line splitting. The decimal point is `.`. EANs have leading zeros (`0000000000024`), so treat them as strings. Blank `asin`/`brand` are common. Some categories look wrong (a neck gaiter under "Computer Software"), so don't rely on category.
- **Cost (operator):** `price` is EUR, delivery included. The operator's comparison and sheet figure is `price x 1.2 (VAT) x EUR->GBP` (0.86 as a rule of thumb). Import duty is treated as overhead, not added.

## Decisions (grill 2026-11-06)

| # | Decision |
|---|---|
| Q1/Q7 | Fetch with a session cookie (`EANY_SESSION_COOKIE` in the VPS `.env`, set by the operator, never through an agent). The fetch step is behind an interface so a later headless-Playwright fetcher with a saved profile on the home micro server (residential IP, no cookie copying) replaces it by config. Cookie expiry is detected and posted to Discord once. |
| Q2 | Full catalogue (CSV) once a night; Hot deals during the day as a trial (Q10). |
| Q3/Q5 | Cost in GBP pence, inc VAT = `round(price_eur x 1.2 x fx x 100)`. `fx` = ECB daily EUR->GBP reference rate, fetched once a day, fallback 0.86 (setting) with a logged warning. The rate used is stored with each pull. No duty/shipping uplift. |
| Q4 | ROI uses our `products` match (fees and sales live there). eany's `asin` fills `uk_asin` on bare rows we add, saving Keepa ASIN resolution. |
| Q8 | Readiness by polling the backend's exports list with the session's bearer token; the email is not used. First step of the build is a probe of the list response; if it lacks status or id, fall back to IMAP on jurassicdesignlabs@ (Gmail app password, operator-set). |
| Q9 | History only for the first 2 weeks; drop alerts behind `EANY_ALERTS_ENABLED` (default false), to `#eany-drops` via its own webhook when switched on. |
| Q10 | Hot deals trial: every 2 h 08:00-20:00 UK for 2 weeks, store and log only. Measure per day: rows new vs the previous pull, how many pass the best-offers rules, how many the overnight full pull would have caught anyway. Operator decides keep/drop. |

## Solution

1. **Fetcher** (`eany-fetch.js`): cookie → `api/auth/session` bearer → create export (scope, CSV) → poll the exports list (timeout 90 min for the full catalogue) → stream `eany.io/api/exports/<id>/download` to a temp file. Detects login redirects / 401 as `cookie_expired`. Never logs cookie or token values. Interface: `fetchExport({scope}) -> {path, rows, exportId}`.
2. **Nightly stage** `eany-pull` (new `run_log` stage name, CONTRACTS.md section 2): run in the small hours (before the miner window ends) behind `EANY_PULL_ENABLED`. Daily gzip snapshot, 30-day prune, own SQLite history DB (same schema and pure functions as 063, keyed by EAN), FX fetch, cost conversion. Rows over a sanity cap (1.2M) are refused, as 062's invoice guard.
3. **Into Part A:** eany rows feed 068's load path (bare rows with `uk_asin` from eany's `asin`, stock rule) and 069's best-offers rebuild with `supplier = 'eany'`. The dashboard tab (Dashboard 030) enables itself once rows exist.
4. **Alerts:** 064's rules applied to the eany history, dark behind `EANY_ALERTS_ENABLED`, own webhook `DISCORD_EANY_WEBHOOK`.
5. **Hot deals trial:** a second scope on the same fetcher, its own small history, trial counters in `run_log.stats`, auto-stops after 14 days unless `EANY_HOTDEALS_ENABLED` is kept.

## Build Order

1. Fetcher + probe (operator sets the cookie). Decides Q8's path.
2. Nightly stage, history, FX.
3. Best-offers and products load for eany (needs 068/069).
4. Hot deals trial.
5. Alerts (after 2 weeks of history).

## Rejected

- A Claude routine doing each download: runs in the cloud (can't use the logged-in laptop browser), costs per run, non-deterministic.
- A Windows scheduled task on the laptop: only works while the laptop is awake and can't share the everyday Chrome profile. Acceptable stopgap only; not built.
- Scripted email+password login from the VPS now: most exposed to the bot protection. Revisit only if cookie renewal becomes a chore.
- Duty/shipping uplift on cost: duty is overhead (operator).

## Open Questions

- Session lifetime: NextAuth defaults to 30 days, rolling while used; unconfirmed for eany. The expiry alert shows the real figure.
- Whether eany's terms of service allow automated exports. Check before switching the nightly stage on.
- What `uk_price` (and the other `*_price` columns) is exactly. Not used by this spec, and they only appear in the Hot deals XLSX, not in the full CSV.
- Full catalogue preparation time. The 2026-11-06 email arrived about 3 min after the Hot deals one, but when it was requested wasn't recorded. The probe should log request-to-ready time; keep the 90 min poll timeout until measured.
