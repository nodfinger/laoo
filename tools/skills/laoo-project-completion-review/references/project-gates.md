# LAOO project gates

## Menu and UI gate

- Metadata, route contract, Navigation API, caption resolver, and screen action model agree.
- ScreenType 1 supports permission-gated CRUD; ScreenType 2 supports VIEW/EDIT only; ScreenType 3 is read-only; ScreenType 4 follows document header-detail rules.
- Caption, cards, filters, tables, pagination, popup, typography, alerts, empty/loading/error states, and responsive layout follow `docs/standards`.
- No page-level refresh/reload button remains. Successful mutations reload automatically; failed loads expose a contextual retry action.

## API and data gate

- JWT/session, active Project, MenuCode action permission, and Company scope are enforced in the backend.
- References belong to the same Company and active records unless the domain explicitly allows historical inactive references.
- Writes are transactional when they span header/detail or multiple owned tables.
- Shared references preserve their owning Project and use backward-compatible contracts.
- Pagination and filters are enforced server-side for growing datasets.

## Integration gate

- Build Center API and the selected API module in Release mode.
- Run root and selected-project Flutter analyze/tests.
- Run route, navigation, permission, and shared-contract tests.
- Start Center API on 5080 and Flutter web on 8080 when local config is available.
- Verify the source action, persisted state, downstream projection/event, destination API, and destination UI.
- Include negative tests for missing permission, wrong Company, missing assignment, invalid status, duplicate submission, and closed time windows.

## Initial project order

1. Evaluation: templates, settings, rounds, approval, response, aggregate results, privacy.
2. Meeting: booking type, attendance, food, equipment, room return, evaluation selection.
3. Training: participant eligibility, PRE/POST sets, completion, evaluation publishing.
4. Run the combined Meeting -> Training -> Evaluation workflow before continuing.
