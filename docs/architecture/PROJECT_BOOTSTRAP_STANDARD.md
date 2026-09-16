# LAOO One-time Project Bootstrap Standard

## Purpose

Core establishes the shared contract once. After the Bootstrap PR is merged
into `main`, the owning Project machine can add or replace screens and routes
inside `projects/<project>/` without a follow-up Root Router PR.

## Required merge order

1. Core opens and merges the Bootstrap PR into `main`.
2. Every affected machine runs `git pull --ff-only origin main`.
3. The Project machine opens Feature PRs directly against `main`.

Any later Root, shared-contract, Navigation, entitlement, permission,
authentication, or schema dependency is a separate compatible Core PR to
`main`. It must merge before the dependent Project PR.

## Change classification

Project machines classify a change before coding:

| Level | Scope | Owner and merge order |
| --- | --- | --- |
| Green | UI/UX, Project-local GoRoutes under an existing contract, business API, Project migration/schema, report, and test inside projects/<project>/ | Project machine opens one Project PR directly to main. |
| Yellow | MenuCode, public route contract, entitlement, permission baseline, Root integration, or shared UI contract | Core merges a compatible Bootstrap/contract PR first; then the Project PR continues. |
| Red | Person, Employee, User, Authentication, Building/Room, Item, or any shared schema/contract | Stop dependent work until Core designs and merges a compatible contract. |

Each Project keeps its own package, migration namespace, API package, and PR.
A machine may own more than one Project, but a Feature PR still contains one
Project only. A Project machine must not edit Root Router, TDADMainMenu, or the
shared permission model.

## Mandatory Bootstrap contents

- ProjectCode and Company entitlement;
- approved MenuCode, ScreenType, Project Menu, and Permission baseline;
- Project package `projects/<project>/pubspec.yaml`;
- package entry point `lib/<project>_feature.dart`;
- Feature Host contract;
- Route contract and `build<Project>FeatureRoutes()`;
- Center API composition and Project migration namespace when approved;
- Root dependency in `pubspec.yaml`, Feature Host configuration in `lib/main.dart`,
  and one route-builder composition point in `lib/app/router/app_router.dart`;
- Navigation registration that reads caption and access from Navigation API /
  `TDADMainMenu`. Client fallback menus are forbidden.

Start from `tools/templates/project-bootstrap/` when creating a package.

## Route ownership

Root composes `build<Project>FeatureRoutes()` exactly once. The Project package
owns every route after Bootstrap, including its temporary Project-local
placeholder while a screen is not implemented. Root must never add or retain a
per-menu `_scopePlaceholder` for a bootstrapped Project.

Changing a Project-local placeholder to a real screen is a Project-only
change. Adding a new menu, changing a public route contract, or changing Root
composition is Core work and requires a separate Core PR.

## Validation

Run these before a Project Feature PR:

```powershell
.\tools\scripts\check-machine-boundaries.ps1 -Module <project>
.\tools\scripts\test-project-bootstrap.ps1 -Project <project>
.\tools\scripts\verify-center.ps1 -Module <project>
```

`test-project-bootstrap.ps1` validates the required package contract, one Root
route-builder call, and rejects Root `_scopePlaceholder` references for the
selected Project. The Flutter route regression test additionally rejects
duplicate route names and paths across Root and all composed Project routes.

## Time reference

`LAOO_TIME` is the reference implementation. Root calls
`buildTimeFeatureRoutes()` once, and Time owns all Time GoRoutes. No Time
MenuCode may be added to Root `_scopePlaceholder`.
