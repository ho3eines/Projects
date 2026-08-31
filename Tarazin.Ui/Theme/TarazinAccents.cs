using MudBlazor;

namespace Tarazin.Theme;

/// <summary>
/// Named accent palette for stat cards, module cards, and sub-nav accents.
/// These are the only sanctioned accent colors; components must reference
/// these names instead of hard-coded hex strings so light/dark theming and
/// future palette changes stay centralized in TarazinTheme.cs.
/// </summary>
public static class TarazinAccents
{
    /// <summary>Primary ink-teal (light-theme primary).</summary>
    public const string Ink = "#0E4D4A";

    /// <summary>Steel blue — accounting chrome.</summary>
    public const string Steel = "#1E4B73";

    /// <summary>Brass gold (light-theme secondary).</summary>
    public const string Gold = "#C49A3C";

    /// <summary>Dark brass — gold shop chrome.</summary>
    public const string Brass = "#B8860B";

    /// <summary>Wine red (tertiary) — warnings, payroll.</summary>
    public const string Wine = "#9C3B2E";

    /// <summary>Petrol teal — informational accents.</summary>
    public const string Petrol = "#2B6B7A";

    /// <summary>Moss green — inventory chrome.</summary>
    public const string Moss = "#4A6B3A";

    /// <summary>Emerald — currency gains.</summary>
    public const string Emerald = "#2E7D32";

    /// <summary>Jade — success/positive trend.</summary>
    public const string Jade = "#2E7D57";

    /// <summary>Crimson — danger/overdue.</summary>
    public const string Crimson = "#C62828";

    /// <summary>Violet — BI/command center.</summary>
    public const string Violet = "#5E35B1";

    /// <summary>Slate gray-blue — neutral balances.</summary>
    public const string Slate = "#607D8B";

    /// <summary>Amber — due-soon warnings.</summary>
    public const string Amber = "#EF6C00";
}
