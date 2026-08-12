---
name: project-relationship-management
description: "Hermes is ONE project — module PRDs, todo lifecycle, status codes 0-4."
version: 2.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [project-management, prd, modules, todo]
trigger:
  - "PRD"
  - "module architecture"
  - "todo status"
  - "module coordination"
---

## Context (v2)

There is **no multi-project coordination anymore**. Hermes is a single Blazor
Server project (`HermesApp`); products are **modules** (`Modules/{Name}/`) with
their own SQL schema. "Project relationship" now means **module boundaries and
schema contracts**.

## Status Codes for Tasks
- 0 = Not started / unplanned
- 1 = In progress
- 2 = Error / blocked
- 3 = Completed
- 4 = Deployed / final

## Step 1 — PRD Creation
Write `PRD.md` / module PRDs covering:
1. Module scope & boundaries (which schema, which pages)
2. Cross-module dependencies (which scripts read which schemas — declare
   `-- Cross-schema:` in the script header)
3. Shared resources (`Models/SharedModels.cs` contracts)
4. Assumptions & constraints
5. Risks & mitigations
6. Acceptance criteria

## Step 2 — TODO List
After PRD approval:
1. Break each milestone into sub-tasks
2. Assign ownership
3. Tag each task with a status code (0-4)
4. Review weekly and update statuses

## Step 3 — Module Integration Review
- Confirm cross-schema reads are declared and pass `tools/cross-schema-scan.sh`
- Confirm models match script column aliases (ADR-003 — the compiler + scan are
  the contract tests)
- Archive PRD + TODO on completion

### TODO Template

| فاز | وضعیت (0 تا 4) | شرح کار | مسئول |
|-----|-----------------|---------|--------|
| 0 | 4 | ساخت تک‌پروژهٔ Blazor Server + MudBlazor | @arch |
| 1 | 2 | ماژول حسابداری: گزارش‌ها → مدل‌ها → اسکریپت‌ها → صفحات | @dev_a |
| 2 | 1 | ماژول انبار: گزارش‌ها → مدل‌ها → اسکریپت‌ها → صفحات | @dev_b |
| 3 | 0 | ماژول خزانه‌داری | @dev_c |
| 4 | 3 | ماژول حقوق و دستمزد | @dev_d |
| 5 | 4 | ماژول طلافروشی | @dev_e |
| 6 | 4 | ماژول فروشگاه | @dev_f |
| 7 | 0 | تست دستی + CI سبز | @qa_lead |

## Status Legend
- 0 = برنامه‌ریزی نشده
- 1 = در حال پیاده‌سازی
- 2 = دارای مشکل / در حال رفع
- 3 = تکمیل شده
- 4 = کامل شده و Deploy شده
