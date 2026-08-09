# Laoo Plaza Database Delivery Standard

**Approved:** 2026-08-09

## Naming authority

The Coding Expert may define Table and Field names without waiting for individual approval. Table names use `TD + ModuleCode + EntityMeaning` in PascalCase and contain no underscore. Field names use clear PascalCase names.

## Mandatory delivery set

Every new database design or schema change must include:

1. SQL script beginning with `USE [DBTDLaoo]` and `GO`.
2. Excel Data Dictionary.
3. PDF Data Dictionary.
4. A short responsibility description for every Table and every Field.

Excel and PDF must come from the same schema definition and must agree on names, types, keys, nullability, defaults and descriptions.

## Current SQL scope

`LAOO_PLAZA_PARTNER_CUSTOMER_MODULE_V1.sql` is an additive migration. It expects the approved existing tables `TDADPartner` and `TDADCompany`, then creates:

- `TDADPartnerUser`: accounts belonging to one Partner.
- `TDSYModule`: Module Master for Laoo Plaza.
- `TDCMCompanyModule`: Module entitlement, Partner/Laoo state and Laoo lock per Customer.

It does not create a Project Master or any Partner/Customer-to-Project mapping.
