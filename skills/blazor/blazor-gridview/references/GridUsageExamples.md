# DataGrid Usage Examples

## 1. Basic (auto columns from model properties)

```razor
@page "/products"

<DataGrid TModel="ProductDto"
          Items="products"
          AllowSelect="true" />

@code {
    private List<ProductDto> products = new();

    protected override async Task OnInitializedAsync()
    {
        products = await _req.GetData<ProductDto>(
            "SELECT Id, Title, Price, CreatedAt FROM Products");
    }
}
```

## 2. Explicit columns + Persian caption + formatter

```razor
<DataGrid TModel="ProductDto" Items="products" PageSize="15">
    <Column PropertyName="Id" Caption="کد" Width="80" Sortable="true" />
    <Column PropertyName="Title" Caption="عنوان" />
    <Column PropertyName="Price" Caption="قیمت"
            Formatter="p => p!.Price.ToString(\"N0\") + \" تومان\"" />
    <Column PropertyName="Active" Caption="وضعیت"
            Formatter="p => p!.Active ? \"✔ فعال\" : \"✖ غیرفعال\"" />
</DataGrid>
```

## 3. Server-side paging (ItemsProvider)

```razor
<DataGrid TModel="UserDto"
          ItemsProvider="LoadUsers"
          PageSize="20"
          ExportButtons="true" />

@code {
    private async Task<GridResult<UserDto>> LoadUsers(GridState state)
    {
        var result = await _req.Request<UserDto>(
            "SELECT * FROM Users WHERE (@search = '' OR Name LIKE '%' + @search + '%')",
            new {
                search = state.SearchText
            });   // note: paging happens client-side in this sample

        return new GridResult<UserDto>
        {
            Items = result?.Skip((state.Page - 1) * state.PageSize)
                          .Take(state.PageSize).ToList() ?? new(),
            TotalCount = result?.Count ?? 0
        };
    }
}
```

## 4. Inline edit + delete + select

```razor
<DataGrid TModel="EditableUser"
          Items="users"
          AllowInlineEdit="true"
          AllowDelete="true"
          OnSaveItem="SaveUser"
          OnDeleteItem="DeleteUser"
          OnSelectionChanged="OnSelection" />

@code {
    private List<EditableUser> users = new();

    private async Task SaveUser(EditableUser u)
    {
        await _req.Request<bool>(
            "UPDATE Users SET Name=@Name, Email=@Email WHERE Id=@Id",
            u, isExec: true);
    }

    private async Task DeleteUser(EditableUser u)
    {
        await _req.Request<bool>(
            "DELETE FROM Users WHERE Id=@Id", u, isExec: true);
        users.Remove(u);
    }

    private void OnSelectionChanged(List<EditableUser> selected)
    {
        Console.WriteLine($"Selected: {selected.Count}");
    }

    public class EditableUser : EditableEntity
    {
        public int Id { get; set; }
        public string Name { get; set; } = "";
        public string Email { get; set; } = "";
    }
}
```

## 5. Header template (add custom button)

```razor
<DataGrid TModel="ProductDto" Items="products">
    <HeaderTemplate>
        <button class="btn btn-sm btn-success" @onclick="AddNew">➕ جدید</button>
        <button class="btn btn-sm btn-danger" @onclick="DeleteSelected">🗑 حذف انتخابی</button>
    </HeaderTemplate>
</DataGrid>
```

## 6. Empty state

```razor
<DataGrid TModel="ProductDto" Items="emptyList">
    <EmptyTemplate>
        <div class="text-muted">📭 هنوز محصولی ثبت نشده است.</div>
    </EmptyTemplate>
</DataGrid>
```

---

## Notes

- **Pagination** is client-side by default; for big data use `ItemsProvider` with server-side `SKIP/TAKE`.
- **Excel export** produces a lightweight `.xls` (HTML table). For true `.xlsx` add `ClosedXML` package (see advanced).
- **DateFormat**: change `GetDisplayValue` in DataGrid.razor to render Persian dates with `PersianCalendar`.
- All controls are pure Bootstrap 5.3 — no MudBlazor/Radzen.