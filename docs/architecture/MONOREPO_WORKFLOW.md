# LAOO Monorepo Workflow

`C:\laooplatform\laoo` and GitHub `nodfinger/laoo` are the only source of
truth for Core, Service, Meeting, Visitor, and Time.

```text
laoo/
├─ lib/                  Center Flutter host and Core screens
├─ laoo_api/             Center API host
├─ packages/             Shared contracts and UI
└─ projects/
   ├─ service/           LAOO_SERVICE package/module
   ├─ meeting/           LAOO_MEETING package/module
   ├─ visitor/           LAOO_VISITOR package/module
   └─ time/              LAOO_TIME package/module
```

The Center Flutter host composes Business route contracts and builders. The
Center API loads `Laoo.Service.Module`, `Laoo.Meeting.Module`,
`Laoo.Visitor.Module`, and `Laoo.Time.Module` as application parts. Business
code has one owner under `projects`; Root must not contain duplicate Business
screens/controllers.

All machines open the repository root and run `8080/5080`. A Meeting, Visitor,
or Time developer edits only the owned project directory, then Hot Restarts or
restarts Center. Root, Core API, Authentication, shared packages, and shared
schema are owned by the Center machine.

New Business Projects use two stages:

1. Center creates and merges the Project Bootstrap: ProjectCode, approved
   MenuCode/ScreenType, ownership, inactive navigation, route/API composition,
   entitlement, and migration namespace.
2. The Project machine pulls `main` and develops Business code only under its
   `projects/<project>` directory.

If Project work needs a Core or shared change, describe the Core Impact before
dependent coding. Use a separate backward-compatible Core PR, merge it first,
sync every machine, and only then merge the dependent Project PR.

Use one task branch and Pull Request per change. Before Merge, merge current
`origin/main` into the task branch and run:

```powershell
.\tools\scripts\verify-center.ps1 -Module <service|meeting|visitor>
```

Each machine may squash-merge its own verified PR. Database changes use only
the migration runner and ledger described in `MULTI_MACHINE_RUNBOOK.md`.
