# Core Screen Ownership

## Employee

- Source owner: LAOO Core.
- Current Core feature: `lib/features/support/employee/`.
- Shared contracts and reusable workspace components: `packages/laoo_shared_admin`
  and `packages/laoo_shared_admin_ui`.
- Business Projects must consume the shared employee contract/UI instead of
  starting another employee implementation.

## Item

- Source owner: LAOO Core.
- Current Core feature: `lib/features/company/item/`.
- The Core Item screen and API contract must be completed before a Business
  Project adds an Item-specific variant.
- When a second Project requires Item behavior, extract the common contract,
  model, and UI component into `packages/`; keep only Business-specific rules
  in that Project.

## Rule for new shared screens

A screen becomes a Core screen when it owns platform-wide master data or is
used by more than one Business Project. A screen remains inside a Business
Project when its workflow or data is specific to that Project.
