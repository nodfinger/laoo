## Summary

- Project: Core / Service / Visitor / Meeting / Time / Other
- Change:
- Branch format: `<project>/<feature|fix|chore>/<short-name>`

## Ownership and Core Impact

- Machine role: core / `<project>` / center-service
- Impact level: Green / Yellow / Red
- Owned paths changed:
- Consuming projects:
- Core PR dependency and merge order: None / describe
- Backward compatibility:
- Bootstrap contract already merged: Yes / No / Not applicable

## Impact

- [ ] Shared package
- [ ] API or contract
- [ ] Database or migration
- [ ] Authentication, permission, PartnerID, or CompanyID scope
- [ ] Navigation, MenuCode, RouteName, or RoutePath
- [ ] UX/UI or responsive layout
- [ ] Core Impact is separated from the Project PR, or not applicable

## Verification

- [ ] `git diff --check`
- [ ] `flutter analyze --no-fatal-warnings --no-fatal-infos`
- [ ] `flutter test`
- [ ] Affected API builds in Release
- [ ] Login and owner scope tested
- [ ] Screenshot attached for UX/UI changes
- [ ] Migration is transactional and idempotent
- [ ] Machine boundary check passed
- [ ] Dependent machines pulled the prerequisite Core PR, or not applicable
- [ ] Project boundary check passed for a Project PR
- [ ] Migration filename uses `yyyyMMddHHmmss_PROJECTCODE_description.sql`
- [ ] Project API/DTO changes remain Project-owned or have a separate Core PR

## Test instructions

Describe the account type, project, route, and expected result.
