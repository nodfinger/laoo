# LAOO_SCHOOL_FOOD Bootstrap

- Owner: Center service. Project type BUSINESS; dependency LAOO_SCHOOL.
- MenuCode 53001–53012 and ScreenType are defined by the approved bootstrap migration and read from Navigation at runtime.
- Company scope comes from the authenticated session. Shop assignment further restricts company users.
- School owns student, classroom, level and guardian identity. Inventory owns items, warehouses, balances and movements.
- School Food owns TDSF tables: settings, shops, assignments, prices, commissions, identifiers, device references, credentials, guardian access, wallet ledger, operations, sales, refunds, transfers, settlement and audit.
- Company API composition: /api/company/school-food through Center 5080; client uses Center 8080.
- Planned student API: /api/school/student; guardian extension uses existing guardian identity. Neither is published by this bootstrap.
- Migration namespace: LAOO_SCHOOL_FOOD, directory projects/school_food/database/migrations.
- Apply only with tools/scripts/run-migrations.ps1 -Module school_food after schema approval.
- The two migration files are independently transactional; do not enable subscriptions until both succeed.
- No company subscription, credentials, sample money or inventory is automatically granted/seeded.
- Bootstrap introduces only module registration and metadata/schema. Business API/UI completion is tracked separately.

## Verification (2026-10-04)

Center Release build passed. Both migrations applied on the authorized DBTDLaooService database after approval; 53001–53012 metadata matches the plan.
The first core migration attempt rolled back because CompanyID is not a candidate key of TDSTCompanySetUp. The unapplied script was corrected without changing any existing table.
Business behavior and hardware acceptance are not certified by bootstrap.
