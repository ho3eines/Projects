---
name: blazor-datagrid-parameter-handling
description: Handle Items parameter updates in DataGrid after prerender.
tags: [blazor, datagrid, parameter, prerender, onparameterssetasync]
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [blazor, datagrid, parameter, prerender, onparameterssetasync]
    related_skills: [blazor-gridview]
---

# DataGrid Items Parameter Handling

## When to Use
Use when a model‑driven `<DataGrid>` receives its `Items` list after initial prerender (e.g. data loaded in `OnInitializedAsync`), and the grid stays empty because the data arrives later.

## Problem
In Blazor Server with prerender → interactive:
1. Prerender runs → `Items` is empty list or null.
2. `OnInitializedAsync` loads real data and updates the field.
3. The grid already rendered with empty data and does not re‑render because `OnInitializedAsync` only fires once.

## Solution
Add `OnParametersSetAsync` to the DataGrid component to react when `Items` changes (only when not using `ItemsProvider`).

```csharp
protected override async Task OnParametersSetAsync()
{
    if (ItemsProvider == null && Items != null)
    {
        _allItems = Items;
        ApplyFilterSortPaging(_allItems.Count);
        StateHasChanged();
    }
}
```

Callers should pass a non‑null list and signal loading state:

```razor
<DataGrid TModel="ProjectRow"
          Items="_projects ?? new List<ProjectRow>()"
          IsLoading="@(_projects == null)" ... />
```

## Pitfalls
- `Items` must be a `List<TModel>` so reference change is detected.
- Guard with `ItemsProvider == null` to avoid double‑loading when server‑side paging is used.
- Do not rely on `OnInitializedAsync` alone for parameter‑driven data.

## Related Skills
- `blazor-gridview` (the grid component this pattern applies to)