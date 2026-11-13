# Project Ownership Registry

This registry is the operational index for the Monorepo Project PR workflow.
The linked system specification remains the source for menu/function behavior;
this file records code ownership, data ownership and the Core contracts each
Project may consume.

| Project directory | ProjectCode | Code owner | Data/API owner | Core data read contract |
|---|---|---|---|---|
| `projects/expense` | `LAOO_EXPENSE` | Expense Project | Expense Project | Company, Employee, Branch, Permission |
| `projects/meeting` | `LAOO_MEETING` | Meeting Project | Meeting Project | Company, Employee, Branch, Permission |
| `projects/intranet` | `LAOO_INTRANET` | Intranet Project | Intranet Project | Company, Employee, Organization, Permission |
| `projects/service` | `LAOO_SERVICE` | Service Project | Service Project | Company, Employee, Branch, Permission |
| `projects/time` | `LAOO_TIME` | Time Project | Time Project | Company, Employee, Branch, Organization, Permission |
| `projects/visitor` | `LAOO_VISITOR` | Visitor Project | Visitor Project | Company, Employee, Branch, Permission |
| `projects/training` | `LAOO_TRAINING` | Training Project | Training Project | Company, Employee, Organization, Permission |
| `projects/gate_pass` | `LAOO_GATE_PASS` | Gate Pass Project | Gate Pass Project | Company, Employee, Branch, Permission |
| `projects/five_s` | `LAOO_5S` | Five S Project | Five S Project | Company, Employee, Organization, Permission |
| `projects/survey` | `LAOO_SURVEY` | Survey Project | Survey Project | Company, Employee, Permission |
| `projects/project` | `LAOO_PROJECT` | Project Project | Project Project | Company, Employee, Permission |
| `projects/vote` | `LAOO_VOTE` | Vote Project | Vote Project | Company, Employee, Permission |
| `projects/pos` | `LAOO_POS` | POS Project | POS Project | Company, Employee, Branch, Permission |
| `projects/sales` | `LAOO_SALES` | Sales Project | Sales Project | Company, Customer, Branch, Employee, Permission |
| `projects/evaluation` | `LAOO_EVALUATION` | Evaluation Project | Evaluation Project | Company, Employee, Organization, Permission |

Projects not listed above remain in Bootstrap/discovery status until their
ProjectCode, complete MenuCode set, data tables and Core read contracts are
confirmed. Never infer ownership from a route or folder name alone; update the
Project Bootstrap and this registry together.

## Project specification checklist

Each `docs/system/<system>.md` should identify:

- ProjectCode and owning `projects/<project>` path;
- MenuCode, ScreenType, Route and Permission baseline;
- Project-owned tables, migrations, API/DTO and Core read contracts;
- Green/Yellow/Red Core Impact boundary;
- current behavior, requirements and unresolved gaps as separate sections.
