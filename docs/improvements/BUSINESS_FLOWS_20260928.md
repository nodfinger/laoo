# LAOO business flows and case checklist

This is the execution map for the seven current projects. `P` means proven by an isolated API/DB case, `R` means reconciled against historical DB records, `W` means widget/route evidence only, `U` means untested, and `G` means a known gap. Evidence and fixture IDs are in [FLOW_TEST_CASES_20260928.md](FLOW_TEST_CASES_20260928.md).

## Shared prerequisites

1. Authenticate as a Company User; Navigation returns only active project/menu mappings with VIEW permission.
2. Load the current MenuName/ScreenType from navigation metadata. Check action permission in both UI and API. Use CompanyID and PartnerID from claims.
3. Any new test object has a `FLOW-` prefix and uses active, same-company references. Check the persisted source row and downstream row after each action.
4. For each business case, repeat with no permission, another Company, invalid reference/status, duplicate action, stale or closed time window, empty data, and API failure. These negative variants are still `U` unless explicitly shown below.

## Evaluation (47001–47007)

`47001` default per source → `47002` Template with RATING_5/SINGLE_CHOICE/MULTIPLE_CHOICE/TEXT → `47003` DRAFT with immutable Template Snapshot and frozen respondents → submit → `47004` approve/publish → notification → `47005` one editable submission per respondent until close → `47006/47007` aggregate results.

| Branch/case | Expected transition or constraint | Evidence |
|---|---|---|
| Create, submit and approve GENERAL | DRAFT → PENDING_APPROVAL → PUBLISHED | P: Round 18 |
| Approve early/repeat, invalid question, missing required answer | Reject without mutation | P |
| Edit answers before close, close by worker, edit after close | Latest submission only; CLOSED rejects edits | P |
| Anonymous report with 1–4 respondents | No question/comment breakdown | P: one respondent |
| Five or more respondents, all four question types | Distribution and comments without identity | U |
| Source event from Service/Meeting/Training | Generate one DRAFT per source type/reference, eligible respondents only | P for Service 17/18; R for Booking 99/105 |
| Editable Master evaluation type and service-type default Template | Select by real service category, preserve source code and historical snapshots | G: new feature not implemented |

## Service (14005–20006, except retired 14003)

`18001` settings → `14005/14006` requester lookup → `15001/20001` NEW → assign active technician RECEIVED → start IN_PROGRESS → optionally issue parts from accessible stock → complete with resolution COMPLETED → create SERVICE Evaluation DRAFT for the requester → approve/answer/report. Cancellation is allowed only before completion.

| Branch/case | Expected transition or constraint | Evidence |
|---|---|---|
| Real resident + equipment + technician | Create → receive → start → complete | P: Request 17 |
| Complete early or twice | 409, no extra Evaluation round | P |
| Successful completion | One Evaluation draft with requester assignment | P: Round 19 |
| Employee self-service to response | Requester c111 creates Request 18; c completes, approves Round 21; c111 responds through Evaluation API; one notification, one anonymous submission | P: source and destination DB/API reconciled; Service pages 20005/19003 remain placeholders |
| Cancel, QR, stock debit/serial, insufficient stock, PM and complaints | Status and inventory remain consistent | U |
| Service requester answers from 20005; admin reads 19003 | Shared Evaluation submission and anonymous aggregate | G: both Service pages remain placeholders; 20005 is now ScreenType 3/VIEW-only by user decision |
| Evaluation publication failure after completed request | Durable retry and observable state | G: current best-effort log only |

## Meeting (21001–24003)

`23001–23004/22006` location/room/equipment/food/setup → `21001` booking MEETING or TRAINING → optional evaluation selections → `21004` approval → `21003` invitation response → `22002/22005` room/equipment preparation → `22004` attendance → `21006/21007` food → `22001` room check-in/return → `24001–24003` utilization/no-show/evaluation reports.

| Branch/case | Expected transition or constraint | Evidence |
|---|---|---|
| Booking beyond room advance limit | Reject | P: 10 days rejected vs 5-day rule |
| TRAINING booking within window | Save type/instructor; select all three evaluation categories | P: Booking 108, then cancelled |
| Wrong category Template | 400; previous selections remain | P |
| Invitation accepted + check-in | Exactly eligible people assigned to Meeting Evaluation | R: Booking 99/105; expected 1/5, unexpected 0 |
| Reject/withdraw invitation, no-show, equipment, food, room return | No unauthorized attendance or issued stock | U |
| Multiple/duplicate return and publication | At most one round per chosen category; no overwritten draft title | U |
| Room feedback report (24003) | Filter and paginate actual rounds; suppress average for fewer than five submissions | P: Rounds 7/15, filter/page/401 checked; small-group suppression enforced in API, exact 1–4 submitted fixture unavailable |

## Training (37001–37006)

`37001–37004` type/instructor/exam/settings → approved TRAINING Booking from Meeting → participant invitation and check-in → PRE/POST exam when configured → `37005` result summary → Evaluation rounds for course/instructor when selected → `37006` participant view.

| Branch/case | Expected transition or constraint | Evidence |
|---|---|---|
| Real booked participant eligibility | Accepted + checked-in users become respondents | R: Booking 99/105 |
| Training result opens related Evaluation rounds | Two rounds per Booking 99/105 | P: API after SQL fix |
| PRE and POST template, attempt, scoring and retry rules | Follow configured templates and active time window | U |
| Missing check-in, no consent, late submission | Reject exam/evaluation according to specific action policy | U |

## Time (25001–30004)

`28002/28005–28010/29001` policies/calendars/periods → `27001–27004/28001` schedule/employee assignment → `25001` raw events → `25002/29004` computed attendance → `26001–26004/30001/30003` correction/leave approval → `29003` close → `25003/25004` payroll export/history. `28011/28012/30002/30004` are read-only balance/history/report views.

| Branch/case | Expected transition or constraint | Evidence |
|---|---|---|
| Route/screen contract and settings card | 33 active routes, update-only policy UI | W: 12 Time widget tests |
| Proxy leave list | Show only authorized Company requests | P (read): two PENDING rows |
| Shift rotation, holiday override, raw import, calculation | Deterministic attendance and audit | U |
| Correction/leave/OT approval and reversal | Only assigned actor can transition, no cross-company data | U |
| Period close and payroll export | Locked source period, traceable export | U |

## Visitor (31002/32001–32003/33001/34003/36004)

`36004` policy → `33001` active contact point/operator → `32001` appointment or `31002` walk-in → `32002` approval when configured → check-in and evidence → `32003` host confirmation → check-out → `31005` history and `34003` exceptions. Operator pages require an active contact point.

| Branch/case | Expected transition or constraint | Evidence |
|---|---|---|
| Appointment read | Company scope and pagination | P (read): zero rows |
| Operator without contact point | Context/inside/exceptions unavailable | P: account c receives 404 by explicit guard |
| Operator with point, host approval, evidence, checkout | Persist visit, audit and exception state | U: operator/host test persona needed |
| Repeated host decision, cross-branch access | Reject with no duplicate/out-of-scope change | U |

## Vote (44001–44005)

`44001` settings → `44002` DRAFT topic (>=2 distinct options, ALL or CUSTOM employee/department) → SUBMIT → `44003` APPROVE or RETURN with reason → edit returned topic and resubmit → publish and freeze active eligible users → `44004` one vote per eligible person within window → close → `44005` dashboard/results.

| Branch/case | Expected transition or constraint | Evidence |
|---|---|---|
| ALL and CUSTOM target lookup/freeze | Deduplicate active same-company users | P: Topic 6 froze 13; Topic 7 froze 1 |
| Approval skip, return without reason, repeat publish/edit | Reject invalid transition | P: Topics 6/7 |
| Before close result; after close vote | Reject both | P: Topic 8 |
| Non-assigned detail | Hidden | P: account c gets 404 for Topic 7 |
| Eligible user casts once; duplicate blocked | One immutable vote | U: eligible test login needed |
| OPEN names and export by permission | Expose only to authorized reporter after close | G: API returns aggregate only, no export permission |

## Completion gate

Each remaining `U` needs a fixture ID, source/API/UI/DB evidence and negative permission case. `G` needs a separate implementation decision. No system is marked fully complete by this document.
