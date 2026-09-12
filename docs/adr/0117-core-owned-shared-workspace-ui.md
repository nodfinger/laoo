# Core-owned Shared Workspace UI

LAOO keeps reusable Caption, Filter, Table, Pagination and workspace layout primitives in the Core-owned `laoo_shared_workspace_ui` package. Business Projects supply their workflow content and data only; they do not redefine the common surface rhythm, so a Core change can standardize all Projects without mixing Project business logic into the Center host.

Each Project host must wrap its composed routes in its project workspace theme. This gives all existing Project screens the same card, form, dialog, button, typography and user-style color contract while individual screens are migrated to the reusable workspace primitives. `LAOO_TIME` is the first adopter; its workflow/API ownership remains in `projects/time`.
