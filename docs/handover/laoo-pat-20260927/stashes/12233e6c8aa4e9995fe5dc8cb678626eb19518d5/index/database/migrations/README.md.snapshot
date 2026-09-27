# LAOO database migrations

New migrations must use the following file name format:

```text
yyyyMMddHHmmss_PROJECT_CODE_short_description.sql
```

Examples:

```text
20260906193000_LAOO_SERVICE_add_ticket_priority.sql
20260906194500_LAOO_MEETING_add_room_capacity.sql
20260906200000_LAOO_VISITOR_add_visit_pass.sql
```

Store migrations in the owner directory:

- Core: `database/migrations`
- Service: `projects/service/database/migrations`
- Meeting: `projects/meeting/database/migrations`
- Visitor: `projects/visitor/database/migrations`
- Time: `projects/time/database/migrations`

Run migrations only through `tools/scripts/run-migrations.ps1`. The runner
uses `dbo.TDSTSchemaMigration`, verifies SHA-256 checksums, and takes the SQL
application lock `LAOO_SCHEMA_MIGRATION` before applying a file.
