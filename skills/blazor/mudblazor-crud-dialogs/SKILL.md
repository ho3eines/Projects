---
name: mudblazor-crud-dialogs
description: Build MudBlazor CRUD with dialogs and delete prompts.
version: 0.1.0
author: ho3eines, Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [blazor, mudblazor, crud, dialogs, messagebox]
    related_skills: [blazor-server-admin-pages, blazor-data-access]
---

# MudBlazor CRUD Dialogs Skill

Build consistent list-based CRUD in Tarazin: create and edit use a reusable
`MudDialog`, deletion requires a `MudBlazor MessageBox`, and data changes use
`DbService` named TSQL scripts. Do not use inline create/edit forms or browser
confirmation APIs.

Official references:

- Dialog usage: <https://mudblazor.com/components/dialog#usage>
- MessageBox: <https://mudblazor.com/components/messagebox#message-box>

## When to Use

- Adding create, edit, or delete actions to a Tarazin management table.
- Replacing an inline form with a MudBlazor dialog.
- Adding a destructive action that needs explicit confirmation.
- Standardizing `Id = 0` insert detection across modules.

Do not use this pattern for immutable posted transactions or report filters.
For removal of an unsaved in-memory child row, still use the MessageBox but
remove only from the local collection; no delete script is needed.

## Prerequisites

- Both hosts register MudBlazor with `AddMudServices()`.
- Shared `Tarazin.Ui/App.razor` renders `MudDialogProvider` and
  `MudSnackbarProvider`.
- Pages inject `DbService`, not `HttpClient`.
- Every mutation has a named embedded script under
  `Tarazin.Data/Scripts/{schema}/`.

## Core Contract

1. `Id == 0` means create.
2. `Id > 0` means edit or delete.
3. Create and edit share one editor model and one dialog component.
4. Delete never runs before `ShowMessageBoxAsync(...)` returns `true`.
5. Cancel (`null`) and No (`false`) never mutate data.
6. Successful save/delete reloads the list from SQL.
7. Prefer soft delete (`IsDeleted = 1`) so historical foreign keys remain
   valid.

```csharp
public int Id { get; init; }
public bool IsNew => Id == 0;
public string DialogTitle => $"{(IsNew ? "ایجاد" : "ویرایش")} {EntityTitle}";
```

The Upsert script must use the same rule explicitly:

```sql
IF @EntityId = 0
BEGIN
    INSERT INTO [schema].[Entities] (...)
    VALUES (...);
END
ELSE
BEGIN
    UPDATE [schema].[Entities]
    SET ...
    WHERE EntityId = @EntityId;
END
```

Do not use `IF NOT EXISTS(EntityId = @EntityId)` to detect creation. An invalid
non-zero edit ID must not silently insert a new row.

## Dialog Procedure

1. Put the editor in its own Razor component with `<MudDialog>` as the root.
   Completion criterion: the page itself contains only the list and action
   buttons, not duplicated create/edit inputs.
2. Put inputs inside `<DialogContent>` and buttons inside `<DialogActions>`.
3. Receive a cloned editor model through an `[EditorRequired]` parameter.
   Editing must not mutate the table row before Save succeeds.
4. Receive `IMudDialogInstance` as a cascading parameter.
5. Validate a `MudForm`, guard against duplicate submits with `_busy`, execute
   the named Upsert, then close with `DialogResult.Ok(true)`.
6. Cancel with `MudDialog.Cancel()`.

```razor
<MudDialog>
    <DialogContent>
        <MudForm @ref="_form" @bind-IsValid="_isValid">
            <MudTextField Label="عنوان" @bind-Value="Model.Title"
                          Required="true" Variant="Variant.Outlined" />
        </MudForm>
    </DialogContent>
    <DialogActions>
        <MudButton OnClick="Cancel">انصراف</MudButton>
        <MudButton Color="Color.Primary" Variant="Variant.Filled"
                   OnClick="SaveAsync" Disabled="_busy">ذخیره</MudButton>
    </DialogActions>
</MudDialog>

@code {
    [CascadingParameter]
    private IMudDialogInstance MudDialog { get; set; } = default!;

    [Parameter, EditorRequired]
    public EntityEditorModel Model { get; set; } = default!;

    private void Cancel() => MudDialog.Cancel();
}
```

Open it with typed parameters and await the result:

```csharp
var parameters = new DialogParameters<EntityEditorDialog>
{
    { x => x.Model, model }
};
var options = new DialogOptions
{
    MaxWidth = MaxWidth.Small,
    FullWidth = true,
    CloseButton = true,
    CloseOnEscapeKey = true
};

var dialog = await DialogService.ShowAsync<EntityEditorDialog>(
    model.DialogTitle, parameters, options);
var result = await dialog.Result;
if (result is { Canceled: false })
    await LoadAsync();
```

## Delete MessageBox Procedure

1. Render a red delete icon in the table's `عملیات` column.
2. Build the prompt from the entity type and a recognizable row label.
3. Await `ShowMessageBoxAsync`; never use `async void`.
4. Continue only when the nullable result is exactly `true`.
5. For persisted rows, execute the named delete script with the real non-zero
   ID. For unsaved child rows, remove from the local collection instead.
6. Show a success/error snackbar and reload persisted lists after success.

```csharp
bool? confirmed = await DialogService.ShowMessageBoxAsync(
    "تأیید حذف",
    $"آیا از حذف «{model.DisplayLabel}» مطمئن هستید؟ این عملیات قابل بازگشت نیست.",
    yesText: "حذف",
    cancelText: "انصراف",
    options: new DialogOptions
    {
        MaxWidth = MaxWidth.ExtraSmall,
        FullWidth = true,
        BackdropClick = false,
        CloseOnEscapeKey = true
    });

if (confirmed is not true)
    return;

await Db.ExecuteAsync("schema", "EntityDelete", new { EntityId = model.Id });
await LoadAsync();
```

Standard table actions:

```razor
<MudTd DataLabel="عملیات">
    <MudTooltip Text="ویرایش">
        <MudIconButton Icon="@Icons.Material.Filled.Edit"
                       Color="Color.Primary" Size="Size.Small"
                       OnClick="@(() => OpenEditorAsync(FromRow(context)))" />
    </MudTooltip>
    <MudTooltip Text="حذف">
        <MudIconButton Icon="@Icons.Material.Filled.DeleteOutline"
                       Color="Color.Error" Size="Size.Small"
                       OnClick="@(() => DeleteAsync(FromRow(context)))" />
    </MudTooltip>
</MudTd>
```

## Delete Script Rules

- Use one named delete script per entity for clear auditing.
- For entities with history or foreign keys, update `IsDeleted` instead of
  issuing `DELETE`.
- Set `IsActive = 0` when the table has that column.
- Add `WHERE IsDeleted = 0` to every list/search query.
- If a legacy table lacks `IsDeleted`, add an idempotent `COL_LENGTH` migration
  in `_Ensure.sql` before using soft delete.
- Protect invariants in SQL; for example, do not allow deletion of the final
  active administrator.

```sql
UPDATE [schema].[Entities]
SET IsDeleted = 1, IsActive = 0, UpdatedAt = SYSUTCDATETIME()
WHERE EntityId = @EntityId AND IsDeleted = 0;
```

## Pitfalls

- `ShowMessageBoxAsync` returns `bool?`, not `bool`: `true` is Yes, `false` is
  No, and `null` is Cancel or close.
- Do not treat `result != null` as confirmation; that would accept No.
- Do not pass `Id = 0` to delete scripts.
- Soft-deleted unique codes still occupy their unique key. Decide explicitly
  whether recreation should restore the old row or report a duplicate.
- Do not put raw SQL in Razor or the dialog service.
- Do not physically delete accounting, inventory, payroll, order, or audit
  history referenced by other records.
- The MessageBox confirms intent; database constraints still enforce safety.

## Verification

Use `terminal` to run:

```text
dotnet build Tarazin.Web/Tarazin.Web.csproj -c Release
bash tools/cross-schema-scan.sh
```

Then verify each modified table manually:

- New opens a dialog and saves with ID zero.
- Edit opens the same dialog with current values and keeps the real ID.
- Canceling the dialog changes nothing.
- Delete opens a MessageBox.
- Canceling or closing the MessageBox changes nothing.
- Confirming delete removes the row from the refreshed list.
- A failed delete leaves the row visible and shows an error snackbar.
