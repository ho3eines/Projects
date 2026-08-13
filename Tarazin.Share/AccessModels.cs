namespace Tarazin.Models;

// ============================================================
// Access-control models (RBAC): permissions, roles.
// Column aliases in the named TSQL scripts MUST match these names.
// ============================================================

/// <summary>یک دسترسی (ردیف [central].[Permissions]).</summary>
public class PermissionRow
{
    public int PermissionId { get; set; }
    public string PermissionKey { get; set; } = "";
    public string Title { get; set; } = "";
    public string ModuleKey { get; set; } = "";
    public bool IsDeleted { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

/// <summary>یک نقش (ردیف [central].[Roles]) + تعداد کاربرانش.</summary>
public class RoleRow
{
    public int RoleId { get; set; }
    public string RoleKey { get; set; } = "";
    public string Title { get; set; } = "";
    public string? Description { get; set; }
    public bool IsSystem { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }
    public int UserCount { get; set; }
}
