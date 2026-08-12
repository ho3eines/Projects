---
name: blazor-gridview
description: Data grids in Hermes = MudTable (MudBlazor). No custom grid.
category: blazor
tags: [blazor, grid, table, mudtable, pagination, search, export]
version: 2.0.0
author: Ho3ein, Hermes Agent
license: MIT
platforms: [windows, linux, macos]
metadata:
  hermes:
    tags: [blazor, grid, table, mudtable, filtering, sorting, edit]
    related_skills: [blazor-clean-architecture, blazor-data-access]
---

# Data Grid for Blazor — MudTable

**The custom `DataGrid` component is gone.** In the v2 single Blazor Server
architecture, every grid is a **MudBlazor `MudTable`**. Model-driven, RTL-ready,
styling is free — no CSS, no hand-rolled pagination/sort/export.

## When to Use

- Any list of rows in a page (daily documents, movements, orders, reports, …)
- You need loading state, empty state, hover, dense/striped rows

## Basic usage

```razor
<MudTable Items="_rows" Loading="_loading" Hover="true" Dense="true" Striped="true">
    <HeaderContent>
        <MudTh>شماره</MudTh>
        <MudTh>تاریخ</MudTh>
        <MudTh>مبلغ</MudTh>
    </HeaderContent>
    <RowTemplate>
        <MudTd DataLabel="شماره">@context.DocumentNumber</MudTd>
        <MudTd DataLabel="تاریخ">@context.DocumentDate.ToString("yyyy/MM/dd")</MudTd>
        <MudTd DataLabel="مبلغ">@context.TotalAmount.ToString("N0")</MudTd>
    </RowTemplate>
    <EmptyContent>
        <MudText Color="Color.Secondary">داده‌ای نیست.</MudText>
    </EmptyContent>
</MudTable>
```

- `Items` = `IEnumerable<T>`; `Loading` shows the MudBlazor loader.
- `DataLabel` on each `MudTd` makes the table responsive (headers become labels
  on small screens).
- Row click: `OnRowClick="Handler"` where handler takes
  `TableRowClickEventArgs<T>`.

## Server-side paging / search

Load data yourself with `DbService` and pass the list to `Items`; MudTable also
supports `ServerData`/`OnServerDataRead` for large sets (see MudBlazor docs).

## Status/state chips

```razor
<MudChip Size="Size.Small" Color="@(context.IsActive ? Color.Success : Color.Default)">
    @(context.IsActive ? "فعال" : "غیرفعال")
</MudChip>
```

## Pitfalls

- **`Items` arriving after prerender**: with `Items` (not `ServerData`) MudTable
  re-renders when the list reference changes — load in `OnInitializedAsync` and
  assign a fresh `List<T>`. Don't mutate the same instance in place and expect
  a re-render; assign a new list or call `StateHasChanged`.
- **Totals**: show them as `MudText` below the table instead of
  `FooterContent`/`colspan` (portable across MudBlazor versions).
- **Inline editing in a row**: `Value="context.X"` + `ValueChanged="v => context.X = v"`.
- **RTL**: the app is `dir="rtl"` globally; MudTable handles it.

## Related
- `blazor-datagrid-parameter-handling` — loading/param patterns (MudTable edition)
- `blazor-data-access` — feeding the table from `DbService`
