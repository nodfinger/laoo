# Core Vendor (08007)

Vendor belongs to Core LAOO, in menu group 08. ScreenType 1 uses the central
List/Card and 480px popup conventions, table typography 14px, and the approved
red delete confirmation from alertdelete.md.

## Behavior

- Search explicitly by code/name/tax ID/telephone; filter status and entity type.
- Person and organization vendor types are supported. Person identity, customer
  records, login accounts and receipt integration are not created by this feature.
- Code/name are required. Code is unique within Company, including inactive rows.
- Popup save stays open and changes create to edit. A create-only user cannot
  update the created row after save. View-only users get a read-only popup.
- RowVersion protects update/delete from stale edits. Data returned from a save
  is the atomic SQL OUTPUT for that write.
- Delete is permanent with confirmation; FK references reject deletion. Disable
  a referenced vendor rather than removing it.

## API and ownership

- GET /api/company/vendors/actions returns VIEW/CREATE/EDIT/DELETE capabilities.
- GET /api/company/vendors supports search, isActive, entityTypeCode, page and
  pageSize (1–200); returns items, total, page, pageSize.
- GET /api/company/vendors/{id}, POST /api/company/vendors,
  PUT /api/company/vendors/{id}, DELETE /api/company/vendors/{id}?rowVersion=...
- Request fields: vendorCode, vendorName, entityTypeCode (PERSON/ORGANIZATION),
  taxID, address, telephone, email, contactName, contactTelephone, contactEmail,
  creditDays (0–3650), remark, isActive; rowVersion required for updates/deletes.
- TDAPVendor.CompanyID comes from session; CompanySetupID references the existing
  TDSTCompanySetUp.PKValue candidate key. Backend resolves it within Company/Partner.
- Every endpoint checks active user/Company/Partner, enabled Core entitlement,
  active menu, ScreenType and direct/role action permission. Admin bypass applies
  inside Company scope. No new permissions are automatically granted to ordinary users.

## Deployment and verification

Migration: 20260910150000_LAOO_vendor via tools/scripts/run-migrations.ps1 -Module core.
Legacy migration 20260909100000 used SHA256 of its UTF-16 migration ID plus :v1,
not the runner's UTF-8 normalized file hash. The approved reconciliation script
checks the legacy digest and schema under the migration application lock,
preserves the original ledger row as
20260909100000_LAOO_branch_warehouse_user_access_legacy_v1_checksum, then updates
only the original checksum. It does not change branch/warehouse business rows.

Backend regression: build tools/vendor-tests/VendorTests.csproj with a separate
output directory while the API is running; run VendorTests.dll with repository
root as argument. Actual controller writes run in an uncommitted TransactionScope.
UI regression: flutter test test/features/company/vendor/vendor_test.dart.

Restart Core API and reload Flutter after deployment. Refresh navigation/login
to see the new menu. Non-admin users need menu 08007 permission assigned first.
