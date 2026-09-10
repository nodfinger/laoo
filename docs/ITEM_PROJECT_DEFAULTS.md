# Core item project availability and classification defaults

## Implemented contract

- Menu 08001 remains ScreenType 1; one Company item master is maintained in Core.
- `projectAccess` is additive on item detail/upsert: `accessModeCode` is `ALL` or
  `SELECTED`, and `projectIds` contains distinct enabled Company project IDs.
  SELECTED requires at least one ID; ALL sends an empty list. Old clients omitting
  this property preserve existing policy. Missing policy means ALL, retaining
  legacy availability; it never grants user, branch or warehouse permissions.
- Item and project selections commit in the same transaction. Existing item,
  usage, stock and document data are not migrated or rewritten.
- `GET /api/company/items/project-options` returns enabled, active, unexpired
  Company projects. `GET /api/company/items?projectId=...` additionally filters
  item availability. The unfiltered endpoint remains the Company master list.
- `GET /api/company/items/classification-defaults?groupCode=...&typeCode=...`
  resolves TYPE before GROUP. `PUT` accepts scopeCode, classificationCode,
  itemKindCode, stockTrackingCode and usageCodes, and requires item EDIT.
  Defaults are Company-scoped and apply only to new untouched form values.
  Group/type master groups remain the existing 006/007; no master recoding occurs.
- The form uses a bounded 1100px popup, fixed bottom actions, 13px buttons and
  14px inputs. Details/notes share a panel. Successful creation changes to edit
  mode rather than clearing the form or creating another item on a second save.

## Deployment and authorization boundary

Migration `20260910120000_LAOO_item_project_defaults` runs through the existing
transactional, application-locked, checksum-ledger migration runner.

- ItemController uses a dedicated Core catalog guard. It validates the active
  user, Company, Partner, session Project, Company entitlement dates and user
  project membership. Each action also checks the mapped Core menu 08001,
  ScreenType and direct/role permissions. Company Admin bypass remains within
  the enabled Company/project scope. Core catalog access no longer requires a
  Service subscription.
- Sales, delivery, item/material and inventory workflows belong to Core
  (`LAOO` / ข้อมูลส่วนกลาง). Their API project guards and item availability
  checks use Core. The legacy `projects/service` source location does not
  establish business ownership. Service is not required for these workflows.
  Existing feature, menu, Company and warehouse permission guards remain.
- Quotation, preorder, delivery, tax invoice, stock receipt and stock issue
  lookups filter project availability. Saves, warehouse/serial allocation and
  stock confirmation revalidate inside the document transaction. Serial lists,
  history and location changes also enforce availability. Inactive or
  cross-company items are denied with HTTP 403 / `ITEM_PROJECT_DENIED`.
- Existing document reads and stock reversal paths retain their existing
  permissions; revoking availability must not prevent reversing a historical
  document. Product availability never grants warehouse or user permissions,
  and Company Admin does not bypass a product's selected-project policy.
- Meeting and other project consumers are not integrated in this change. No
  Meeting source, configuration or data is changed. Do not advertise enforcement
  across every project until each consumer is integrated.

## Verification

- Backend build; Flutter item form widget tests at 390px and 1100px.
- New defaults, preserved edit values, project serialization, repeated-save ID.
- `tools/scripts/test-item-project-defaults.ps1` exercises SQL cases in a
  transaction that is always rolled back; no fixture data persists.
- `tools/scripts/test-item-project-enforcement.ps1` executes the production SQL
  predicates with rollback-only fixtures: Core without Service, action guards,
  Company/Partner boundaries, membership, active status and ALL/SELECTED policy.
- Browser visual and authenticated end-to-end checks remain required.
