# Evaluation UX findings

Review scope: Center Flutter host and `projects/evaluation/lib`.

**1. Format evaluation dates for the user's locale**

The evaluation round dialog builds day, month, year, hour, and minute by hand. This bypasses the application's locale and company date conventions.

**2. Dismiss the keyboard while scrolling forms**

Evaluation template, round, and response dialogs contain text fields inside scrollable regions without `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag`.

**3. Unfocus text fields before opening a modal**

Evaluation pages and dialogs can open detail, confirmation, and date/time dialogs while a search or form field remains focused. The keyboard can return after the modal closes.

**4. Show scrollbars for long vertical content**

Long template, respondent, response, and result lists do not expose a visible scrollbar on web/desktop, so users cannot judge list length or position.

**5. Never render API values as `null`**

Several evaluation labels call `toString()` directly on dynamic API fields. Central display normalization is needed for null, empty, and serialized `"null"` values.

## LAOO-specific findings selected by the user

- Menu `47001` is currently ScreenType 1 in database and source but must be ScreenType 2 with VIEW/EDIT only.
- ScreenType 2 settings must render all data inside cards and must not expose create/delete actions.
- Evaluation list/settings captions expose page-level refresh icons; these must be removed and data must reload automatically after actions.
- Evaluation dialogs need a white surface and subtle theme dividers below the caption and above actions.
- The route bootstrap test still expects Evaluation routes to be unimplemented even though all seven routes are implemented.
