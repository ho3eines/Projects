using Microsoft.Maui.Controls;
using Microsoft.Maui.Graphics;

namespace Tarazin.Maui;

/// <summary>
/// Native MAUI fallback shown when the BlazorWebView page cannot be created.
/// This keeps the Windows process visible instead of closing immediately, so an
/// operator can copy the real startup error and the crash-log path.
/// </summary>
internal sealed class StartupErrorPage : ContentPage
{
    public StartupErrorPage(string title, Exception exception)
    {
        Title = "ترازین — خطای راه‌اندازی";
        FlowDirection = FlowDirection.RightToLeft;
        BackgroundColor = Color.FromArgb("#0B3A38");

        var errorText = exception.ToString();
        var logPath = StartupCrashLog.FilePath;

        Content = new ScrollView
        {
            Content = new VerticalStackLayout
            {
                Padding = new Thickness(28),
                Spacing = 16,
                Children =
                {
                    new Label
                    {
                        Text = title,
                        FontSize = 24,
                        FontAttributes = FontAttributes.Bold,
                        TextColor = Color.FromArgb("#F4DE9C")
                    },
                    new Label
                    {
                        Text = "برنامه اجرا شد، اما ساخت پنجره/رابط کاربری شکست خورد. جزئیات خطا در پایین و در فایل لاگ ذخیره شده است.",
                        FontSize = 15,
                        TextColor = Colors.White
                    },
                    new Label
                    {
                        Text = "مسیر لاگ: " + logPath,
                        FontSize = 13,
                        TextColor = Color.FromArgb("#CFE7E3")
                    },
                    new Border
                    {
                        Stroke = new SolidColorBrush(Color.FromArgb("#E8C872")),
                        StrokeThickness = 1,
                        BackgroundColor = Color.FromArgb("#082C2A"),
                        Padding = new Thickness(14),
                        Content = new Label
                        {
                            Text = errorText,
                            FontFamily = "Consolas",
                            FontSize = 12,
                            TextColor = Color.FromArgb("#FFF7ED"),
                            LineBreakMode = LineBreakMode.WordWrap
                        }
                    }
                }
            }
        };
    }
}
