# LAOO Monorepo Workflow

`C:\laooplatform\laoo` and GitHub `nodfinger/laoo` are the only source of
truth for Core, Service, Meeting, and Visitor.

```text
laoo/
├─ lib/                  Center Flutter host and Core screens
├─ laoo_api/             Center API host
├─ packages/             Shared contracts and UI
└─ projects/
   ├─ service/           LAOO_SERVICE package/module
   ├─ meeting/           LAOO_MEETING package/module
   └─ visitor/           LAOO_VISITOR package/module
```

The Center Flutter host composes Business route contracts and builders. The
Center API loads `Laoo.Service.Module`, `Laoo.Meeting.Module`, and
`Laoo.Visitor.Module` as application parts. Business code has one owner under
`projects`; Root must not contain duplicate Business screens/controllers.

All machines open the repository root and run `8080/5080`. A Meeting or
Visitor developer edits only the owned project directory, then Hot Restarts
or restarts Center. Standalone project hosts are removed only after route,
API, permission, and UX parity passes.

Use one task branch and Pull Request per change. Before Merge, merge current
`origin/main` into the task branch and run:

```powershell
.\tools\scripts\verify-center.ps1 -Module <service|meeting|visitor>
```

Each machine may squash-merge its own verified PR. Database changes use only
the migration runner and ledger described in `MULTI_MACHINE_RUNBOOK.md`.
