---
name: blazor-datagrid-parameter-handling
description: Handle Items updates in MudTable after prerender (Blazor Server).
tags: [blazor, mudtable, parameter, prerender, oninitializedasync]
version: 2.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [blazor, mudtable, parameter, prerender]
    related_skills: [blazor-gridview]
---

# MudTable Items Update Handling

## When to Use
Use when a `MudTable` receives its `Items` list **after** the initial prerender
(e.g. data loaded in `OnInitializedAsync`), and the grid stays empty because
the data arrived after the first render.

## Problem
In Blazor Server with prerender → interactive:
1. Prerender runs → `Items` is empty (or `null`).
2. `OnInitializedAsync` loads real data and updates the field.
3. `OnParametersSetAsync` fires again after the data is set; MudTable re-reads
   `Items` whenever the reference changes — but only if the field was actually
   reassigned, not mutated in place.

## Solution (MudTable edition)

- Always assign a **new list reference**:
  ```csharp
  private List<ItemRow> _rows = new();
  protected override async Task OnInitializedAsync()
  {
      _rows = (await Db.QueryAsync<ItemRow>(Schema, "ItemList")).ToList(); // new list
      // no extra work needed — MudTable re-renders on reference change
  }
  ```
- Use the `Loading` parameter so the table shows a loader while data loads:
  ```razor
  <MudTable Items="_rows" Loading="_loading" ...>
  ```
  ```csharp
  private bool _loading = true;
  try { ... } finally { _loading = false; }
  ```
- If you push data in a later event (search button), call `LoadAsync()` which
  assigns a fresh list; no manual `StateHasChanged` required (but harmless).

## Pitfalls
- `Items` must be a reference type collection (`List<T>`) — re-assign, don't
  `AddRange` into the same instance and rely on it.
- Do NOT combine `Items` with `ServerData`; pick one mode.
- Empty-state feedback: `EmptyContent` render fragment.
