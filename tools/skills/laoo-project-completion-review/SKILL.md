---
name: laoo-project-completion-review
description: Audit, complete, integrate, repair, and verify LAOO business projects one at a time, including MenuCode/ScreenType contracts, shared data, permissions, API, Flutter UX, runtime workflows, and evidence reports. Use for unfinished-project reviews or cross-project workflow completion; do not use for a narrow isolated code edit.
---

# LAOO Project Completion Review

Complete one LAOO project at a time and prove its shared-data workflows before moving to the next project.

## Required preflight

1. Read the repository `AGENTS.md` and the standards it routes to.
2. Read `local.machine.json`. Stop if the role does not own the selected project or Center integration.
3. Preserve unrelated working-tree changes. Never reset, discard, or overwrite them.
4. Read the selected Project's routes, controllers, migrations, tests, handoff notes, and feature specification.
5. Query `dbo.TDADMainMenu`, `dbo.TDADProjectMenu`, and permissions for every selected MenuCode. Database metadata is the source of truth; if it conflicts with an explicit newer user requirement, report the conflict and obtain required migration approval before changing it.
6. Read [project gates](references/project-gates.md) before changing source. Read [report format](references/report-format.md) before reporting.

## Completion workflow

Work in this order and keep an evidence row per MenuCode.

1. Inventory each menu as `PASS`, `PARTIAL`, `PLACEHOLDER`, `MISSING_API`, `MISSING_ROUTE`, or `BLOCKED`.
2. Trace its complete path: navigation metadata -> route -> page -> API -> permission -> database -> downstream consumer.
3. Identify shared ownership and classify Core impact as Green, Yellow, or Red under repository policy.
4. Ask the user before proceeding when a business relationship is ambiguous. Do not infer who owns shared data, approval authority, status transitions, or destructive side effects.
5. Implement missing behavior within the selected project. Additional features are allowed only when they close a demonstrated workflow gap, preserve existing contracts, and receive the same tests and permission checks as requested features.
6. For Flutter UX, verify ScreenType and action permissions first. Follow repository standards and shared theme tokens. ScreenType 2 content stays inside cards and exposes update actions only. Do not show page-level refresh/reload buttons; load on entry and after successful actions, with retry only in an error state.
7. Verify popup surfaces are white, use theme divider tokens below the caption and above actions, and use the standard header, field spacing, buttons, validation, and responsive behavior.
8. Build deterministic fixtures with a run identifier. The configured LAOO database may be used as test data when authorized, but target exact rows and never use broad destructive cleanup.
9. Run static, unit, contract, API, permission, database, browser, and cross-project workflow checks that apply.
10. Repair failures and rerun the failed check plus related regression checks. After three repeated failures with the same cause, stop that flow, record evidence, and continue independent flows.
11. Do not start the next project until the selected project's gate passes or every remaining blocker is explicitly recorded.

## UX review routing

- Use `flutter-improve-design` only for its read-only audit and design-plan phase; respect its restriction against source edits while it is active.
- Use `flutter-ui-design` when a screen needs a visible structural transformation, and inspect rendered evidence before claiming completion.
- Ordinary standards-compliance repairs can be implemented directly after the audit phase.

## Safety and authorization

- Never accept CompanyID, EmployeeID, DepartmentID, ParticipantID, or UserID from the client as authorization scope.
- Backend permission and company-scope checks are mandatory even when the UI hides an action.
- Schema changes and migrations require the approval specified by repository policy. Metadata/data repair does not authorize schema changes.
- Do not commit, push, merge, or apply migrations unless the user has authorized that stage.
- Do not commit secrets, local configuration, uploads, build output, runtime logs, screenshots, or generated test artifacts.

## Required output

Produce a concise Thai report with the selected Project, MenuCode/MenuName/ScreenType, changes, shared-data links, tests and evidence, remaining blockers, runtime URLs, and one of: `พร้อมใช้งาน`, `พร้อมทดสอบ`, `รอ Migration`, or `ติดปัญหา`.
