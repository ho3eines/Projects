---
name: project-relationship-management
description: "Multi-project PRD, todo lifecycle, status codes 0-4."
version: 1.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [project-management, prd, multi-project]
trigger:
  - "PRD"
  - "project architecture"
  - "todo status"
  - "multi-project coordination"
---

## Status Codes for Tasks
- 0 = Not started / unplanned
- 1 = In progress
- 2 = Error / blocked
- 3 = Completed
- 4 = Deployed / final

## Step 1 — PRD Creation
Write `PRD.md` covering:
1. Project scope & boundaries
2. Inter-project communication channels
3. Shared resources
4. Assumptions & constraints
5. Risks & mitigations
6. Acceptance criteria

## Step 2 — TODO List
After PRD approval:
1. Break each major milestone into sub-tasks
2. Assign ownership
3. Tag each task with a status code (0-4)
4. Review weekly and update statuses

## Step 3 — Integration Review
- Confirm cross-project dependencies are resolved before status moves to 3
- Ensure automated tests cover inter-project boundaries
- Archive PRD + TODO on completion

### TODO Template

| فاز | وضعیت (0 تا 4) | شرح کار | مسئول |
|-----|-----------------|---------|--------|
| 1 | 2 | طراحی معماری ارتباطی | @backend_lead |
| 2 | 1 | پیاده‌سازی API Project A | @dev_a |
| 3 | 0 | وصل شدن Project B به API | @dev_b |
| 4 | 3 | پردازش داده در Project C | @data_eng |
| 5 | 4 | نوشتن تست‌های واحد API | @qa_lead |

## Status Legend
- 0 = برنامه‌ریزی نشده
- 1 = در حال پیاده‌سازی
- 2 = دارای مشکل / در حال رفع
- 3 = تکمیل شده
- 4 = کامل شده و Deploy شده
