# Training Phase 2A — pre/post tests

Status: Training API, migration, feature route and Flutter screens are implemented.
This feature reports test scores only. It does not implement Survey or training evaluation.

## Ownership and entry point

Only Training-owned files and tables are added. There is no new menu or permission seed.
The Meeting booking action and invitation entry point require a separate integration change;
do not add fallback navigation or route-permission bypasses in Training.
Company Training entitlement and active user project assignment are required in addition
to booking role checks. Managers are company admin, admin of the booked room, or booking owner.
Participants must be active employees linked to the authenticated user and have accepted
the same booking. Company/partner and booking scope are validated server-side.

## API

Base: /api/company/training/bookings/{bookingId}/tests

- GET base: permissions, booking window, PRE/POST availability.
- GET/PUT {section}/definition: manager-only complete question set; PUT includes rowVersion.
  Question and option IDs are UUIDs. Array order is the editor's question order.
  Each question must contain four options with one correct answer. Text, imageId, or both
  are accepted. Whole-definition PUT supports adding, editing, deleting and reordering.
- POST {section}/attempt: accepted participant starts or resumes a persisted random set.
- PUT {section}/attempt: answers, submit, rowVersion; saves draft or submits once.
- GET {section}/results?page=1&pageSize=30: manager sees all attempts; participant sees own.
- POST images: base64 JSON; only JPEG, PNG and WebP signatures, max decoded size 1 MiB.
- GET images/{imageId}: authenticated base64 response; participants only access assigned images.
- DELETE images/{imageId}: manager-only, forbidden while referenced by any definition or attempt.

Definition: questionCount, passingPercent, isActive, questions[{id,text,imageId,
options[{id,text,imageId,isCorrect}]}].
Attempt response excludes all correctness fields; question/option ordering remains stable.
Score and pass threshold are calculated on the server. No rounding before pass/fail comparison.
Results order: submitted first, score descending, submission time ascending, name, attempt ID.
Incomplete attempts are explicitly unfinished, not failed.

## Windows and concurrency

PRE closes at the first booking slot start. POST opens at the last slot end and closes
seven days later. Booking must be APPROVED. Booking wall-clock times follow Meeting's
existing server-local DateTime.Now convention; audit timestamps are UTC.
A unique exam/participant constraint and transactional per-booking application lock prevent
duplicate starts/submissions. Version tokens reject stale definition and draft updates.
An exam freezes at the first started attempt, protecting resumed work as well as submissions.

Images are private files under API App_Data/training-tests/{company}/{booking}/{imageId:N}.
Do not serve this directory as static files. Database stores metadata, not image bytes.
Signature validation is not full image decoding or malware scanning.

## Verification

dotnet run --project projects/training/tests/ExamRulesChecks/ExamRulesChecks.csproj
dotnet build projects/training/packages/dotnet/Laoo.Training.Module/Laoo.Training.Module.csproj
powershell -ExecutionPolicy Bypass -File tools/scripts/run-migrations.ps1 -Module training -DryRun

Dry-run only lists files and does not execute SQL. Full API authorization, concurrency,
migration application, Flutter and browser checks remain required before completion.

The feature route is /company/training-tests/{bookingId}?section=PRE|POST.
It is intentionally not a navigation menu. The Meeting booking action and invitation
entry point require a separate Meeting-owned integration change.

Current local verification: 34 domain checks passed; Training module build and full API
build to an isolated temporary output passed with zero warnings/errors. Flutter analyze
for projects/training/lib passed. Migration dry-run passed; SQL has not been applied.
The current machine role is Meeting, so boundary verification correctly rejects applying
or validating the Training migration here. No commit or push has been performed.

The question delete dialog follows alertdelete.md: red icon/title/border, red
information bar, non-recoverable warning, and cancel/delete actions.
