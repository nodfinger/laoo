# LAOO Visitor

Business feature package for the Visitor system inside the LAOO monorepo.

Visitor is loaded by the Center host only:

```text
Web: http://localhost:8080
API: http://localhost:5080
Project entitlement: LAOO_VISITOR
```

Run and test from the repository root. Do not create or run a separate Visitor
web/API host. Business menus remain inactive until each route and API is
implemented and verified through the Center host.

Shared Branch, Employee, Organization, User, Permission, and Theme code must be
consumed from `../../packages` instead of copied into this project.
