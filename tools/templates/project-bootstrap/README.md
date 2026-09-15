# Project Bootstrap Flutter Template

Replace `{{project}}`, `{{ProjectPascal}}`, and `LAOO_{{PROJECT_CODE}}`.

Core uses this template during the Bootstrap PR. Once merged, the Project
machine owns the package files and may replace its Project-local placeholder
with a real screen without changing Root.

Core registers every approved MenuCode and route contract in the Bootstrap PR.
Keep unfinished menus at `TDADProjectMenu.IsActive = 0`; the Project PR that
delivers a real screen sets only its completed menu to `IsActive = 1`.

Required files:

- `pubspec.yaml`
- `lib/{{project}}_feature.dart`
- `lib/features/{{project}}/{{project}}_feature_host.dart`
- `lib/features/{{project}}/{{project}}_route_contract.dart`
- `lib/features/{{project}}/{{project}}_go_routes.dart`

Root must add the dependency, configure the Feature Host in `lib/main.dart`,
and compose `build{{ProjectPascal}}FeatureRoutes()` once in `app_router.dart`.
