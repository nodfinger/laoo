# SAP-PMS

## Core-owned contract

The live menu registry and permission tables were checked on 13 November 2026.

| Field | Registered value |
|---|---|
| Project entitlement | `LAOO_MY` (existing; do not create another project code) |
| MenuCode / name | `65002` / ตรวจสอบข้อมูล API SAP-PMS |
| Menu group | `65` / ระบบ-IT |
| FeatureCode | `MY_SYSTEM` |
| ScreenType | `3` |
| RouteName / RoutePath | `mySystemSapPms` / `/company/my-system/sap-pms` |
| Permission baseline | `VIEW` |
| Data ownership | SAP-PMS feature owns its integration behavior and any feature-specific data. Core owns only navigation, route composition, and the existing entitlement/permission records. |

Core keeps the existing public MenuCode, route name/path, entitlement and VIEW
permission unchanged. The Core Bootstrap makes the project-menu assignment
inactive until Green delivers the working feature. It does not disable the
global menu record.

## Green-owned implementation

Green owns the complete SAP-PMS feature under `projects/sap_pms/**`, including
the ScreenType 3 screen, feature API endpoints, DTOs, persistence if needed,
SAP-PMS client/integration, validation, error handling, tests, and module
documentation. Green may determine the API shape required by the feature
inside the module. Root only composes the module; it must not contain duplicate
business endpoints or UI.

SAP-PMS endpoint details, fields, authentication configuration, and sample
responses were not present in the repository or supplied by the owner at
Bootstrap time. Green must verify those details with the system owner while
implementing the integration; do not invent production endpoints or commit
credentials, tokens, or real SAP-PMS data. Keep secrets in the approved local
or deployment secret store. Any new shared Core API, permission, entitlement,
or schema dependency remains a separate Core change.

## Current code evidence

- Before Bootstrap, the Root route for `65002` pointed to
  `MySystemPlaceholderPage`; Bootstrap transfers route ownership into the
  Project package and keeps the temporary placeholder inside that package.
- No SAP-PMS-specific client, controller, DTO, table, or database object was
  found in the repository/database name search performed for Bootstrap.
- `docs/drafts/my_system_initial_screens.md` also describes ScreenType 3, but
  it is draft material; the registered menu metadata above is authoritative.

## Bootstrap rollout

- The Project package uses technical migration namespace `LAOO_SAP_PMS` if it
  later needs feature-owned migrations. This is separate from entitlement
  `LAOO_MY`.
- The Core migration leaves the unfinished project-menu row inactive.
- Green activates only its existing approved project-menu row in the Feature
  PR that contains the completed screen, API behavior, and tests.
- Green's PR must remain within `projects/sap_pms/**`; Core Root composition is
  prepared by this Bootstrap.
