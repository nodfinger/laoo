# Booking and equipment request permission correction

## Behavior

- Company admins and the admin of the booked room can approve, reject, and roll back a booking.
- Booking owners can manage food, configure equipment requests, edit and cancel their booking. Ownership alone does not authorize approval.
- Accepted invitees (including training attendees using the same participant records) can request equipment in their own name.
- Booking management uses the first slot start. Equipment submissions also require an active plan and an unexpired cutoff.
- Equipment request edits cancel a cancellable original line and submit a new request. An existing waiting/pending/in-progress request for the same user's item prevents duplicate submission.
- Equipment request SQL uses employee names and room ownership rather than nonexistent user/contact columns.
- Request timelines are scoped to managers or the requester. Cancellation and department updates write timeline events transactionally.

## Verification

Run from the repository root:

```powershell
dotnet run --project projects/meeting/tests/BookingPermissionChecks -- C:/laooplatform/laoo
dotnet build laoo_api/laoo_api.csproj -c Release --no-restore
dart analyze projects/meeting/lib/features/meeting/pages/meeting_invitation_page.dart projects/meeting/lib/features/meeting/pages/meeting_room_booking_page.dart projects/meeting/lib/features/meeting/pages/meeting_equipment_request_page.dart
```

The permission suite checks role combinations, boundary times, first-slot behavior, approval restrictions, and SQL against the configured database. Role fixtures use SELECT-only CTEs and do not modify company data.

Additional verification: Meeting popup widget tests pass.

## Existing verification limitations

- The existing FoodPlanQuantityChecks suite fails at its legacy-payload assertion: the controller opens a connection whereas the test expects validation before database access. This is outside the permission correction.
- The machine boundary check detects pre-existing Core/Time edits in the shared working tree. Do not include these in a Meeting commit.
- Interactive browser end-to-end testing and concurrent successful submissions have not been executed. Production booking/request records were not created for testing.

Restart the Center API on port 5080 and reload the frontend on port 8080 to load the updated implementation. No schema migration is needed for this correction. No commit or push has been performed.
