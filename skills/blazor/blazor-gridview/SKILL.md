---
name: blazor-gridview
description: Reusable Blazor grid with search, paging, sorting, export.
category: blazor
tags: [blazor, grid, table, pagination, search, export]
version: 1.0.0
author: Ho3ein, Hermes Agent
license: MIT
platforms: [windows, linux, macos]
metadata:
  hermes:
    tags: [blazor, grid, table, pagination, filtering, sorting, edit, export, csv, excel]
    related_skills: [blazor-clean-architecture]
---

# DataGrid for Blazor

Model-driven Blazor grid component. Works with any POCO model. No DataTable/DataRow — pure C# models + Bootstrap 5.3 + optional JS interop for export.

## When to Use

- You need a data grid that binds to `List<TModel>` (not DataTable)
- You need search, filter, sort, pagination out of the box
- You need Excel/CSV export, inline edit, row selection
- You want pure Bootstrap styling (no MudBlazor/Radzen)

## Features

- Model-driven columns (auto from properties or explicit)
- Global search + per-column filters
- Sorting (ASC/DESC)
- Pagination (page size, page jump)
- Row selection (single/multi) via checkboxes
- Inline edit + save/cancel + delete
- Export: CSV, Excel (JS), Print
- Skeleton loading + empty state
- RTL / Dark Mode via CSS variables

## File Map

```
blazor-gridview/
├── SKILL.md
├── templates/
│   ├── DataGrid.razor               # Main component
│   ├── DataGridColumn.cs            # Column def
│   ├── DataGridModels.cs            # EditableEntity, GridResult
│   └── DataGridPagination.razor     # Pagination UI
└── references/
    └── GridUsageExamples.md         # Real usage samples
```