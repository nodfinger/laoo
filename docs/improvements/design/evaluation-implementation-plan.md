# Evaluation UX implementation plan

1. Align `47001` route/API/UI with ScreenType 2. Return VIEW/EDIT permissions only, expose an EDIT-authorized upsert for the six fixed source types, and remove create/delete UI.
2. Redesign settings as caption card plus responsive source-setting cards. Load on entry and after save; show retry only in the error state.
3. Remove page-level refresh/reload actions from all Evaluation screens and replace reload instructions with contextual retry behavior.
4. Standardize Evaluation dialogs through shared local helpers: white surface, 4px radius, theme divider, 48px header/actions, 16px field rhythm, theme typography and colors.
5. Add locale/company-aware date formatting, safe display normalization, keyboard dismissal, focus release before modal open, and desktop scrollbars where relevant.
6. Update route and UI contract tests for seven implemented routes and ScreenType 2 settings.
7. Run format, analyze, Flutter tests, Evaluation module Release build, Center API Release build, permission/metadata checks, and runtime smoke tests.

Migration and database metadata changes remain a separately approved step under repository policy.
