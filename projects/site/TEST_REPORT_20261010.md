# LAOO_SITE acceptance evidence — 2026-10-10

Environment: Center API `5080`, Flutter Web `8080`, SQL Server `DBTDLaooService`.
Fixture: `SI_20261010_DEMO` in company `DEMO`; no `TDPMProject` changes.

## Database and sample data

- Applied SITE bootstrap, schema, and action migrations through `tools/scripts/run-migrations.ps1`.
- Confirmed eight MenuCodes `63001–63008` with ScreenTypes `2,1,4,3,1,4,3,3`.
- Confirmed 13 `TDSI*` tables.
- Fixture has 3 projects (CCTV, Network, construction), 7 weighted tasks, 2 reports, 1 issue, 2 handovers, 1 publication, 2 notifications, and a private PNG attachment.
- Trial and staff rights are scoped to DEMO / c111. Other companies were not enrolled.

## Checks passed

- Center API Release build: 0 warnings, 0 errors; all 8 SITE action endpoints returned HTTP 200 with the DEMO staff token on `5080`.
- Flutter analyze for SITE and integration files: no issues. SITE route test passed.
- Flutter Web Release build passed; `8080` serves its latest `main.dart.js`.
- Full Center `flutter test` passed: 244 tests.
- Daily report: submit 204, duplicate submit 409, review 204, selective publish 200, duplicate publish 409.
- Returned report: edit reset status to DRAFT and incremented VersionNo to 2.
- Customer account: login succeeded, only granted project was listed, ungranted project returned 404, staff API returned 403.
- Handover: submit 204, customer notification/read 204, accept 204, duplicate accept 409.
- Private PNG: upload 201, authorized download 200; unauthenticated staff endpoint returned 401.

## Remaining manual acceptance

- Visual/touch review at 1440, 1024, 768, 430, and 360 px was not automated. Chrome headless did not produce a DOM result on this machine; the temporary browser profile was removed.
- Offline encrypted draft behavior was implemented and statically analyzed, but a real network-disconnect/reconnect interaction has not yet been exercised in a browser.
- Physical mobile camera and Android PWA behavior remain device acceptance checks.

Runtime uploads under `laoo_api/uploads/site` are intentionally private and Git-ignored. The sample attachment remains in place because the database references it.
