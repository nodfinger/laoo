# LAOO Training module

`LAOO_TRAINING` is a Company-scoped business project.

- Core owns `TDADProject`, `TDADCompanyProject`, Navigation, and shared identity.
- Training owns future Training business tables and migrations in `database/migrations/`.
- Training-specific migrations use the `LAOO_TRAINING` filename namespace and run with `tools/scripts/run-migrations.ps1 -Module training`.
- No Training main menu, master data, instructor, assessment, or test schema exists in this bootstrap.
- Meeting room bookings retain `ActivityTypeCode=TRAINING` independently of this entitlement.
