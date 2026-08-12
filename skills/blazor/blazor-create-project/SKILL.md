---
name: blazor-create-project
description: Add a new product module to the single Tarazin Blazor Server app.
tags: [blazor, server, module, page, routing, navmenu, mudblazor]
trigger: Use when creating a new module (product) inside Tarazin — pages, schema, scripts, nav links — or when creating any new page in an existing module.
status: active
author: Hermes Agent (auto-generated)
version: 2.0
---

## Overview

Tarazin is **one Blazor Server project**. "Creating a project" now means
**creating a module** inside `Tarazin`:

1. Module folder with pages: `Tarazin.Shared/Modules/{Name}/Pages/`
2. Schema + scripts: `Tarazin.Shared/Data/Scripts/{schema}/` (`_Ensure.sql`, `_Seed.sql`, …)
3. Models: `Tarazin.Shared/Models/{Name}Models.cs`
4. Nav entries: `Tarazin.Shared/Layout/NavMenu.razor` + `Modules/Home/Home.razor` launcher card

## Step-by-Step

1. **Reports-first**: research what reports the domain must have; write them
   into the module PRD.
2. **Models**: `Tarazin.Shared/Models/{Name}Models.cs` with rows matching the report shapes
   (ADR-003 — column aliases must equal property names).
3. **Schema** (inside `Tarazin.Shared`):
   - `Tarazin.Shared/Data/Scripts/{schema}/_Ensure.sql` — idempotent `CREATE SCHEMA`/`CREATE TABLE`
   - `Tarazin.Shared/Data/Scripts/{schema}/_Seed.sql` — idempotent seed data
   - Named scripts for every query/execute the pages need.
4. **Pages** (MudBlazor only), standard 6:
   - `{Name}Home.razor` — `@page "/{route}"` — daily list + از تاریخ تا تاریخ filter
   - `{Name}Dashboard.razor` — `@page "/{route}/dashboard"`
   - `{Name}Entry.razor` — `@page "/{route}/entry"` — ورود عملیات
   - `{Name}Reports.razor` — `@page "/{route}/reports"` — گزارشات
   - `{Name}Special.razor` — `@page "/{route}/special"` — عملیات ویژه
   - `{Name}Settings.razor` — `@page "/{route}/settings"` — امکانات
5. **Register**:
   - `Layout/NavMenu.razor` → `<MudNavLink Href="/{route}">…</MudNavLink>`
   - `Modules/Home/Home.razor` → add a `ModuleCard` entry
6. **Validate**: `tools/cross-schema-scan.sh` + `dotnet build Tarazin.Web/Tarazin.Web.csproj`.
7. **Done**: the new module appears in BOTH the web host and the MAUI app automatically.

## Page Template (MudBlazor)

```razor
@page "/{route}"
@inject DbService Db
@inject ISnackbar Snackbar

<MudText Typo="Typo.h4">…</MudText>
<MudPaper Elevation="1" Class="pa-4">
    <MudTable Items="_rows" Loading="_loading" Hover="true" Dense="true" Striped="true">
        <HeaderContent>…<MudTh>…</MudTh>…</HeaderContent>
        <RowTemplate>…<MudTd DataLabel="…">@context.…</MudTd>…</RowTemplate>
        <EmptyContent><MudText Color="Color.Secondary">…</MudText></EmptyContent>
    </MudTable>
</MudPaper>

@code {
    private const string Schema = "{schema}";
    private List<…Row> _rows = new();
    private bool _loading = true;

    protected override async Task OnInitializedAsync()
    {
        try { _rows = (await Db.QueryAsync<…Row>(Schema, "ScriptName", new { … })).ToList(); }
        catch (Exception ex) { Snackbar.Add(ex.Message, Severity.Error); }
        finally { _loading = false; }
    }
}
```

## Pitfalls
- Route prefix must be unique; module pages are prefixed `/{route}/…` so they
  never collide. Pages live in `Tarazin.Shared` — never in a host project.
- Every data call passes the module's own `schema` — never another module's.
- RTL: `Culture="CultureInfo.GetCultureInfo("fa-IR")"` on MudDatePicker.
- Never reference `HttpClient` or old `IRequestService` — use `DbService`.
