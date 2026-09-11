## Summary

- Project: Core / Service / Visitor / Meeting / Time / Integration
- Change:

## Ownership and Core Impact

- Machine role: center-service / meeting / visitor / time
- Impact level: Green / Yellow / Red
- Owned paths changed:
- Consuming projects:
- Core PR dependency and merge order: None / describe
- Backward compatibility:

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

## Test instructions

Describe the account type, project, route, and expected result.
