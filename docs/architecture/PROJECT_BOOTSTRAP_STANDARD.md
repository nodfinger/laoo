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

## Menu and route rollout

Core Bootstrap creates the complete approved menu map for the Project in one
PR: MenuGroup, every MenuCode/ScreenType, Permission baseline, Navigation
registration, and matching route contract entries. It does not wait for each
screen to be built.

Every approved route is owned by the Project package from that point onward.
The package may use a Project-local placeholder until the screen is ready, but
Root must not add a placeholder for an individual Project menu.

To avoid exposing unfinished work, the Bootstrap migration creates each
unfinished Project menu with `IsVisible = 0`. The Project machine changes only
its own `TDADProjectMenu.IsVisible` to `1` in the same Project PR that delivers
the real screen, route, API behavior, and tests. A visible menu must never
route to a Root fallback or an unimplemented screen.

If the menu map itself changes later, Core adds the new approved menu/route
contract in a separate Bootstrap extension PR before the Project feature PR.

## Route ownership

Root composes `build<Project>FeatureRoutes()` exactly once. The Project package
owns every route after Bootstrap, including its temporary Project-local
placeholder while a screen is not implemented. Root must never add or retain a
per-menu `_scopePlaceholder` for a bootstrapped Project.

Changing a Project-local placeholder to a real screen is a Project-only
change. The Project also opens its own completed menu by setting
`TDADProjectMenu.IsVisible = 1`. Adding a new menu, changing a public route
contract, or changing Root composition is Core work and requires a separate
Core PR.

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
