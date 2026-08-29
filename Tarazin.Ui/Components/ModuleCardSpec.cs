using Tarazin.Theme;

namespace Tarazin.Components;

/// <summary>مشخصات یک کارت ماژول (برای ModuleCard). از TarazinModule ساخته می‌شود.</summary>
public record ModuleCardSpec(string Icon, string Title, string Lead, string Url, string Accent)
{
    public static ModuleCardSpec FromModule(TarazinModule m)
        => new(m.Icon, m.Title, m.Lead, m.Url, m.Accent);
}