# Center Meeting access, role permission uniqueness, and Vote settings

Date: 2026-09-30

## Changes

- Meeting project guard accepts an active LAOO Center session or a direct LAOO_MEETING session. Both the active project and Meeting must be enabled for the session company/partner and assigned to its user. Other project sessions remain rejected; menu checks remain in place.
- Core migration `20260930060000_LAOO_role_permission_project_unique` changes permission uniqueness to `(RoleGroupID, ProjectID, MenuCode, ActionCode)`. Existing permission rows are preserved.
- Menu `44001` was read from TDADMainMenu and confirmed as ScreenType 2. Vote settings now resolves its Card surface and text/button theme inside the Workspace context. Caption and content remain separate cards, with a 6px gap and 4px corners.

## Verification

- Latest origin/main is an ancestor of the working branch; no other Core migrations were pending.
- Standard `tools/scripts/run-migrations.ps1 -Module core`: applied successfully; ledger and new unique index confirmed.
- Center API Debug build: passed; existing Six Labors license warning remains.
- API restarted on 5080 from `.codex-center-build/center-20260930-guard`, using the source API content root.
- c111 calendar GET: LAOO session 200, LAOO_MEETING session 200, LAOO_SERVICE session 403, anonymous request 401.
- Temporary role `QA-UK-0930054843` (ID 28, no assigned users) retained a legacy VIEW permission in Project 1 and saved the same menu/action in Project 4 through the API. Initial and repeated PUT returned 204; GET confirmed VIEW and the database held both project rows.
- Only that temporary role and its permissions were deleted after the test; remaining fixture count is zero. Admin role permissions were not changed by the test.
- Vote file format and targeted analyzer passed. Flutter 8080 hot restart completed. Actual post-change browser appearance awaits user review.

No commit or push performed. Existing unrelated working-tree changes were preserved.
