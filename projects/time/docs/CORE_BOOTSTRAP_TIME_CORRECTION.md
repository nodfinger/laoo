# Core Bootstrap: Time Correction

The Time module owns the business implementation. Center/Core must register the
following navigation and permission contracts before the screens are enabled.

| MenuCode | MenuName | ScreenType | RouteName | RoutePath |
|---|---|---:|---|---|
| 26001 | คำขอปรับเวลา | 4 | `timeCorrectionProxy` | `/company/time-corrections` |
| 26002 | กล่องอนุมัติคำขอเวลา | 3 | `timeApprovalInbox` | `/company/time-approval-inbox` |
| 28003 | เหตุผลทำแทน | 1 | `timeOnBehalfReasons` | `/company/time-on-behalf-reasons` |
| 28004 | เหตุผลปรับเวลา | 1 | `timeAdjustmentReasons` | `/company/time-adjustment-reasons` |
| 30001 | คำขอปรับเวลาของฉัน | 4 | `myTimeCorrections` | `/company/my-time-corrections` |

Permission actions:

- 26001: `VIEW`, `CREATE`, `ACT_ON_BEHALF`, `APPROVE`, `SELF_APPROVE`
- 26002: `VIEW`, `APPROVE`, `SELF_APPROVE`
- 28003 and 28004: `VIEW`, `CREATE`, `EDIT`, `DELETE`
- 30001: `VIEW`, `CREATE`, `SUBMIT`, `CANCEL`

The Center navigation API remains the source of truth. The Time client does not
add fallback or hard-coded sidebar entries. The Time migration intentionally
does not execute any Core menu or permission writes.
