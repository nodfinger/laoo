# Meeting Extraction Completion

Status: completed and superseded by
`docs/adr/0003-center-single-runtime-host.md`.

Meeting business Flutter source is owned by `projects/meeting/lib/features/meeting`.
Its route contract and route builder are exported by `meeting_feature.dart` and
composed by the Root Center router.

Meeting business API source is owned by
`projects/meeting/packages/dotnet/Laoo.Meeting.Module`. The Root `laoo_api`
loads this assembly as an MVC application part. Authentication, navigation,
shared administration, and database routing remain in the Root API.

The separate Meeting Flutter entrypoint, platform runners, and API host were
removed after route, test, Center Web build, and Swagger endpoint verification.
Meeting is now developed and tested through the Center host at `8080/5080`.
