using MudBlazor;

namespace Tarazin.Theme;

/// <summary>
/// Persian-first MudBlazor theme: warm paper surfaces, ink-teal chrome, gold accent.
/// Typography is Vazirmatn — loaded from wwwroot / Google Fonts.
/// </summary>
public static class TarazinTheme
{
    public static readonly string[] Fonts = ["Vazirmatn", "Tahoma", "Segoe UI", "sans-serif"];

    public static MudTheme Create() => new()
    {
        PaletteLight = new PaletteLight
        {
            Black = "#14110B",
            White = "#FFFDF8",
            Primary = "#0E4D4A",
            PrimaryContrastText = "#F7F1E3",
            Secondary = "#C49A3C",
            SecondaryContrastText = "#1A1408",
            Tertiary = "#9C3B2E",
            TertiaryContrastText = "#FFF8F3",
            AppbarBackground = "#0B3A38",
            AppbarText = "#F4EBD4",
            Background = "#F3EEE3",
            BackgroundGray = "#E7DFD0",
            Surface = "#FFFBF4",
            DrawerBackground = "#072826",
            DrawerText = "#E8DFC8",
            DrawerIcon = "#D4B06A",
            TextPrimary = "#1C1914",
            TextSecondary = "#5C5648",
            TextDisabled = "#9A9280",
            ActionDefault = "#3D5A56",
            ActionDisabled = "#C4BBA8",
            ActionDisabledBackground = "#EDE6D8",
            TableLines = "#E4DCCB",
            TableStriped = "rgba(14,77,74,0.035)",
            TableHover = "rgba(14,77,74,0.07)",
            Divider = "#E2D8C4",
            DividerLight = "#EEE6D6",
            LinesDefault = "#E2D8C4",
            LinesInputs = "#D5CCB8",
            GrayDefault = "#8A8270",
            GrayLight = "#EDE6D8",
            GrayLighter = "#F6F1E6",
            GrayDark = "#4A453A",
            GrayDarker = "#2A261E",
            OverlayDark = "rgba(7,40,38,0.48)",
            OverlayLight = "rgba(255,251,244,0.72)",
            Success = "#2E7D57",
            SuccessContrastText = "#F3FFF8",
            Info = "#2B6B7A",
            InfoContrastText = "#F3FBFF",
            Warning = "#C49A3C",
            WarningContrastText = "#1A1408",
            Error = "#9C3B2E",
            ErrorContrastText = "#FFF8F3",
        },
        PaletteDark = new PaletteDark
        {
            Black = "#040807",
            White = "#F7F1E3",
            Primary = "#D4B06A",
            PrimaryContrastText = "#1A1408",
            Secondary = "#7EB8B0",
            SecondaryContrastText = "#06201E",
            Tertiary = "#E08A78",
            AppbarBackground = "#061615",
            AppbarText = "#F4EBD4",
            Background = "#0B1615",
            BackgroundGray = "#12201E",
            Surface = "#12211F",
            DrawerBackground = "#071110",
            DrawerText = "#E8DFC8",
            DrawerIcon = "#D4B06A",
            TextPrimary = "#F3EBD8",
            TextSecondary = "#B8AE96",
            TextDisabled = "#6F6858",
            ActionDefault = "#C9B889",
            TableLines = "#243330",
            TableStriped = "rgba(212,176,106,0.04)",
            TableHover = "rgba(212,176,106,0.08)",
            Divider = "#243330",
            LinesDefault = "#243330",
            LinesInputs = "#33423F",
            OverlayDark = "rgba(0,0,0,0.6)",
            Success = "#5FBF8A",
            Info = "#6CB8C7",
            Warning = "#D4B06A",
            Error = "#E08A78",
        },
        Typography = new Typography
        {
            Default = new DefaultTypography
            {
                FontFamily = Fonts,
                FontSize = "0.9375rem",
                FontWeight = "400",
                LineHeight = "1.72",
                LetterSpacing = "0",
            },
            H1 = new H1Typography { FontFamily = Fonts, FontWeight = "800", LetterSpacing = "-0.03em" },
            H2 = new H2Typography { FontFamily = Fonts, FontWeight = "800", LetterSpacing = "-0.03em" },
            H3 = new H3Typography { FontFamily = Fonts, FontWeight = "700", LetterSpacing = "-0.02em" },
            H4 = new H4Typography { FontFamily = Fonts, FontWeight = "700", FontSize = "1.35rem", LetterSpacing = "-0.02em", LineHeight = "1.35" },
            H5 = new H5Typography { FontFamily = Fonts, FontWeight = "700", FontSize = "1.125rem", LetterSpacing = "-0.015em" },
            H6 = new H6Typography { FontFamily = Fonts, FontWeight = "600", FontSize = "1rem" },
            Subtitle1 = new Subtitle1Typography { FontFamily = Fonts, FontWeight = "600" },
            Subtitle2 = new Subtitle2Typography { FontFamily = Fonts, FontWeight = "600" },
            Body1 = new Body1Typography { FontFamily = Fonts, LineHeight = "1.72", FontSize = "0.9375rem" },
            Body2 = new Body2Typography { FontFamily = Fonts, LineHeight = "1.68", FontSize = "0.875rem" },
            Button = new ButtonTypography { FontFamily = Fonts, FontWeight = "600", FontSize = "0.875rem", TextTransform = "none", LetterSpacing = "0" },
            Caption = new CaptionTypography { FontFamily = Fonts, FontWeight = "400", FontSize = "0.8125rem" },
            Overline = new OverlineTypography { FontFamily = Fonts, FontWeight = "600", LetterSpacing = "0.06em" },
        },
        LayoutProperties = new LayoutProperties
        {
            DefaultBorderRadius = "14px",
            DrawerWidthLeft = "300px",
            DrawerWidthRight = "300px",
            AppbarHeight = "68px",
        },
    };
}
