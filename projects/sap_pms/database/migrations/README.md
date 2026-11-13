# SAP-PMS project migrations

This folder is owned by the SAP-PMS Project feature. Use the migration runner
with `-Module sap_pms`; its technical namespace is `LAOO_SAP_PMS`. This is
separate from the existing company entitlement `LAOO_MY`.

Keep SAP-PMS-owned schema changes here. Do not alter Core tables or put
credentials, tokens, or real SAP-PMS data in migrations.
