# LAOO Service

Business feature package and .NET controller module for `LAOO_SERVICE`.
Develop and test it through the Root Center host at `8080/5080`; no standalone
Service web or API host is supported.

## Source ownership

- Product master (`features/company/item`) is maintained in the Root Center
  `lib/features/company/item`, not in the legacy Service copy.
- The Root Center composes Service through `lib/service_feature.dart` and its
  exported routes. Opening a screen in Center does not mean its implementation
  has moved to Center.
- Customer, quotation, pre-order, tax invoice, temporary receipt, delivery note,
  and inventory screens exported by `service_feature.dart` are live Service
  implementations. Keep these and their .NET controllers while Center uses them.
- Legacy Service copies of Center login, administration, and product screens are
  pending retirement. Do not implement new changes in these duplicate copies.
  Before removal, reconcile pending changes and tests with Center and verify
  all imports, exports, and route consumers.

Run the required verification from the repository root:

```powershell
.\tools\scripts\verify-center.ps1 -Module service
```
