namespace BlazorGrid;

/// <summary>Column definition for DataGrid. Model-driven, no DataTable.</summary>
public class DataGridColumn<TModel>
{
    public string PropertyName { get; set; } = "";
    public string Caption { get; set; } = "";
    public Type? PropertyType { get; set; }
    public bool Sortable { get; set; } = true;
    public bool Filterable { get; set; } = true;
    public bool Visible { get; set; } = true;
    public int Width { get; set; } = 0;
    public Func<TModel, object?>? Formatter { get; set; }
    public string CssClass { get; set; } = "";
}

/// <summary>Base class for models that support inline editing.</summary>
public abstract class EditableEntity
{
    public bool IsEditMode { get; set; }
}

/// <summary>Paged result returned by an ItemsProvider.</summary>
public class GridResult<TModel>
{
    public List<TModel> Items { get; set; } = new();
    public int TotalCount { get; set; }
}

/// <summary>Standard grid events.</summary>
public class GridState
{
    public string SearchText { get; set; } = "";
    public string SortColumn { get; set; } = "";
    public bool SortAscending { get; set; } = true;
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 10;
}