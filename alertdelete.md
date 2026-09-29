# Alert Delete Standard

This file is the project reference for every delete-confirmation Popup.

- Popup background must always be white.
- Use a rounded outer border with the system Error/Delete color; this is the explicit exception to the borderless general Popup rule in `docs/standards/POPUP_UI_STANDARD.md`.
- Put the delete icon and `ยืนยันการลบข้อมูล` caption on the same header row.
- Put the selected record in a separate light-red information bar.
- Show a warning that deleted data cannot be restored.
- Put a divider before the footer and keep Cancel/Delete on the same row.
- Keep the delete icon, header caption, information bar accent, outer border, and Delete button in the semantic Error/Delete color; the red caption is an explicit exception to the standard black Popup caption.
- Use a plain TextButton for Cancel and require confirmation before deleting.
- Respect UI and backend permissions.
- Show a readable error description when deletion fails.
