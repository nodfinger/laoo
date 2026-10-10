# LAOO_RENTAL

The Center host composes the "Rental" module under `/api/company/rental`.
Rental owns TDRN data and reads shared customer, item, serial and warehouse
records by CompanyID. Its MenuCodes are 60001–60010.

Do not execute database migrations without schema approval.
The bootstrap creates menu records hidden until the Flutter routes are ready.

Rental evidence is stored outside public web assets. Set
`Rental:PrivateStorageRoot` to a persistent private directory on the API
server; without it, the module uses `private/rental` below the app binary.
