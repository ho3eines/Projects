---
name: blazor-maui-hybrid
description: "MAUI Blazor Hybrid host for Tarazin — one shared UI (RCL), native Windows/Android/iOS/macOS app via BlazorWebView. Complete setup, wiring, platform constraints and pitfalls."
category: blazor
tags: [blazor, maui, hybrid, blazorwebview, android, ios, maccatalyst, windows, native, mudblazor, rcl]
version: 1.0.0
author: Ho3ein (Hermes Agent)
license: MIT
platforms: [windows, android, ios, maccatalyst]
metadata:
  tarazin:
    tags: [blazor, maui, hybrid, blazorwebview, native, rcl, windows, android, ios]
    related_skills: [tarazin-project-architecture, blazor-data-access, blazor-create-project]
trigger:
  - "MAUI"
  - "Blazor Hybrid"
  - "BlazorWebView"
  - "native app"
  - "دسکتاپ"
  - "موبایل"
  - "اندروید"
  - "اپ بومی"
---

# 📱 MAUI Blazor Hybrid — Tarazin Host (کامل و دقیق)

راهنمای مرجع برای هاست MAUI در ترازین. هدف: **یک UI (Tarazin.Ui) که هم در
مرورگر (Blazor Server) و هم در اپ بومی (BlazorWebView) اجرا می‌شود** — بدون
تکرار هیچ صفحه‌ای.

---

## 1. Blazor Hybrid چیست؟ (خلاصهٔ دقیق)

- **MAUI** (.NET Multi-platform App UI) = فریم‌ورک بومی برای ویندوز، اندروید،
  iOS و macOS.
- **Blazor Hybrid** = کامپوننت‌های Blazor داخل یک **BlazorWebView** رندر
  می‌شوند؛ کامپوننت‌ها **روی رانتایم .NET خود اپ** اجرا می‌شوند (نه WASM، نه
  سرور). یعنی سرویس‌ها و کتابخانه‌های in-process (MudBlazor، Dapper، DI) بدون
  تغییر کار می‌کنند.
- برخلاف Blazor Server **هیچ SignalR/سرور لازم نیست**؛ برخلاف WASM **هیچ کلید/رمز
  در باندل کلاینت نمی‌رود** (همه‌چیز در پروسهٔ محلی است).

## 2. ساختار پروژه‌ها (پنج‌تایی ترازین)

```
Tarazin.Share/ ← مدل‌ها/قراردادها (namespace Tarazin.Models)
Tarazin.Data/  ← لایهٔ داده: DbService + ScriptCatalog + AuditService + Scripts (EmbeddedResource)
Tarazin.Ui/    ← RCL UI: Modules/ Layout/ Services/{UserSession, AuthService, AddTarazinUiServices}
                  ← App.razor: Router + MudBlazor providers + TarazinDbInitializer
Tarazin.Web/   ← هاست وب (Blazor Server): Program.cs + Pages/_Host.cshtml
Tarazin.Maui/  ← هاست بومی (این اسکیل): MauiProgram + MainPage.xaml + Platforms/
```

هر دو هاست فقط این کارها را می‌کنند:
1. رجیستر سرویس‌ها: `AddTarazinUiServices()` (در `Tarazin.Ui`) — که خودش
   `AddTarazinDataServices()` (در `Tarazin.Data`) را هم صدا می‌زند
2. ثبت UI kit: `AddMudServices()`
3. رندر کردن `Tarazin.App` (در `Tarazin.Ui/App.razor`)

## 3. فایل‌های کلیدی Tarazin.Maui (یک‌به‌یک)

### 3.1 `Tarazin.Maui.csproj`
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFrameworks>net10.0-android;net10.0-ios;net10.0-maccatalyst</TargetFrameworks>
    <TargetFrameworks Condition="$([MSBuild]::IsOSPlatform('windows'))">$(TargetFrameworks);net10.0-windows10.0.19041.0</TargetFrameworks>
    <OutputType>Exe</OutputType>
    <RootNamespace>Tarazin.Maui</RootNamespace>
    <UseMaui>true</UseMaui>
    <SingleProject>true</SingleProject>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <ApplicationTitle>ترازین</ApplicationTitle>
    <ApplicationId>ir.tarazin.app</ApplicationId>
    <ApplicationDisplayVersion>1.0</ApplicationDisplayVersion>
    <ApplicationVersion>1</ApplicationVersion>
    <SupportedOSPlatformVersion ...>…</SupportedOSPlatformVersion>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="MudBlazor" Version="9.8.0" />
    <PackageReference Include="Microsoft.Extensions.Configuration.Json" Version="10.0.0" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\Tarazin.Ui\Tarazin.Ui.csproj" />
  </ItemGroup>
  <ItemGroup>
    <MauiIcon Include="Resources\AppIcon\appicon.svg" Color="#0F766E" />
    <MauiSplashScreen Include="Resources\Splash\splash.svg" Color="#0F766E" BaseSize="128,128" />
  </ItemGroup>
  <ItemGroup>
    <EmbeddedResource Include="appsettings.json" LogicalName="Tarazin.Maui.appsettings.json" />
  </ItemGroup>
</Project>
```
نکته‌ها:
- `TargetFrameworks` شامل ویندوز فقط وقتی روی ویندوز build می‌شود.
- `<UseMaui>true</UseMaui>` + `<SingleProject>true</SingleProject>` = فایل‌های
  `Platforms/` خودکار در build هر TFM شرکت می‌کنند.
- **پیش‌نیاز build**: `dotnet workload install maui` (فقط در CI/سیستم dev).

### 3.2 `MauiProgram.cs`
```csharp
using Microsoft.Extensions.Configuration;
using Microsoft.Maui.Controls.Hosting;
using Microsoft.Maui.Hosting;
using MudBlazor.Services;
using Tarazin.Services;

namespace Tarazin.Maui;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();

        using (var stream = typeof(MauiProgram).Assembly
            .GetManifestResourceStream("Tarazin.Maui.appsettings.json"))
        {
            if (stream is not null)
                builder.Configuration.AddJsonStream(stream);
        }

        builder.UseMauiApp<App>();
        builder.Services.AddMauiBlazorWebView();
#if DEBUG
        builder.Services.AddBlazorWebViewDeveloperTools();
#endif
        builder.Services.AddMudServices();
        builder.Services.AddTarazinUiServices();
        return builder.Build();
    }
}
```

### 3.3 `App.xaml` / `App.xaml.cs` (MAUI Application)
```xml
<Application xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
             xmlns:x="http://schemas.microsoft.com/winfx/2009/xaml"
             x:Class="Tarazin.Maui.App">
    <Application.Resources>
        <ResourceDictionary>
            <ResourceDictionary.MergedDictionaries>
                <ResourceDictionary Source="Resources/Styles/Colors.xaml" />
                <ResourceDictionary Source="Resources/Styles/Styles.xaml" />
            </ResourceDictionary.MergedDictionaries>
        </ResourceDictionary>
    </Application.Resources>
</Application>
```
```csharp
namespace Tarazin.Maui;

public partial class App : Application
{
    public App() => InitializeComponent();
    protected override Window CreateWindow(IActivationState? state) => new(new MainPage());
}
```

### 3.4 `MainPage.xaml` — قلب هاست
```xml
<ContentPage xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
             xmlns:x="http://schemas.microsoft.com/winfx/2009/xaml"
             xmlns:tarazin="clr-namespace:Tarazin;assembly=Tarazin.Ui"
             x:Class="Tarazin.Maui.MainPage"
             BackgroundColor="{DynamicResource PageBackgroundColor}">
    <BlazorWebView HostPage="wwwroot/index.html">
        <BlazorWebView.RootComponents>
            <RootComponent Selector="#app" ComponentType="{x:Type tarazin:App}" />
        </BlazorWebView.RootComponents>
    </BlazorWebView>
</ContentPage>
```
- `ComponentType` = **همان** `App.razor` مشترک (از `Tarazin.Ui`) — «Hybrid» همین است.
- `Selector="#app"` باید با `<div id="app">` در index.html یکی باشد.

### 3.5 `wwwroot/index.html` — صفحهٔ میزبان WebView
```html
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <base href="/" />
    <title>ترازین — مدیریت هوشمند کسب‌وکار</title>
    <link rel="stylesheet" href="_content/MudBlazor/MudBlazor.min.css" />
    <link href="_content/Tarazin.Ui/css/app.css" rel="stylesheet" />
</head>
<body>
    <div id="app">در حال بارگذاری...</div>
    <script src="_framework/blazor.webview.js"></script>
    <script src="_content/MudBlazor/MudBlazor.min.js"></script>
</body>
</html>
```
⚠️ **مهم**: اسکریپت رانتایم باید `_framework/blazor.webview.js` باشد —
هرگز `blazor.server.js` (مربوط به Server) یا `blazor.web.js` (مربوط به WASM).

### 3.6 `appsettings.json` (Embedded)
همان ساختار وب (`ConnectionStrings:DefaultConnection` + `Tarazin:*`) —
توسط `AddJsonStream` خوانده می‌شود تا لایهٔ مشترک بدون تفاوت کار کند.

### 3.7 `Platforms/` و `Resources/`
- `Platforms/Android` → `AndroidManifest.xml` (+INTERNET)، `MainActivity.cs`
  (MauiAppCompatActivity)، `MainApplication.cs` (MauiApplication)
- `Platforms/iOS` و `Platforms/MacCatalyst` → `AppDelegate.cs`
  (MauiUIApplicationDelegate)، `Program.cs`، `Info.plist`
- `Platforms/Windows` → `Package.appxmanifest` (MSIX + runFullTrust)،
  `app.manifest`، `Assets/StoreLogo.png`
- `Resources/AppIcon/appicon.svg` + `Resources/Splash/splash.svg` +
  `Resources/Styles/{Colors,Styles}.xaml` (حداقلی — UI اصلی MudBlazor است)

## 4. اشتراک سرویس‌ها (چرا بدون تغییر کار می‌کند)

| سرویس | Scope | رفتار در وب | رفتار در MAUI |
|---|---|---|---|
| `ScriptCatalog` | Singleton | بارگذاری Embedded در ctor | همان |
| `DbService` | Scoped | per circuit | ≈ singleton (اپ تک‌کاربره) |
| `UserSession` | Scoped | per circuit | ≈ singleton |
| `AuditService` | Scoped | per circuit | همان منطق |
| `AuthService` | Scoped | per circuit | همان |

`TarazinDbInitializer.EnsureInitializedAsync(services)` (guard شده با
`Interlocked`) در هر دو هاست فقط یک‌بار: ensure → seed → bootstrap admin.
- وب: در `Program.cs` قبل از `app.Run()`.
- MAUI: در `App.razor` مشترک (OnInitializedAsync) — خطاها به‌صورت Snackbar/Alert
  نمایش داده می‌شوند.

## 5. ⚠️ محدودیت پلتفرم داده (بسیار مهم)

`Microsoft.Data.SqlClient` از **ویندوز، لینوکس و macOS** پشتیبانی می‌کند؛
**اندروید و iOS را پشتیبانی نمی‌کند**.

| TFM | دادهٔ مستقیم (DbService) |
|---|---|
| `net10.0-windows10.0.19041.0` | ✅ کار می‌کند (نصب SQL Server / داکر روی همان ماشین یا شبکه) |
| `net10.0-maccatalyst` | ✅ (در عمل تست شود) |
| `net10.0-android` / `net10.0-ios` | ❌ نیاز به جایگزین: SQLite/EF Core یا یک سرویس داده (بک‌لاگ) |

برای موبایل: رابط کاربری ۱۰۰٪ آماده است؛ فقط لایهٔ داده باید عوض شود — پس
اگر هدفتان اندروید/iOS است، اول معماری دادهٔ موبایل را تصمیم بگیرید
(پیشنهاد: افزودن یک endpoint مشترک یا سرویس محلی SQLite).

## 6. اجرا و build

```bash
# پیش‌نیازها (یک‌بار)
dotnet workload install maui

# ویندوز (خروجی: exe/MSIX)
dotnet build Tarazin.Maui/Tarazin.Maui.csproj -c Release -f net10.0-windows10.0.19041.0
dotnet run  Tarazin.Maui/Tarazin.Maui.csproj     -f net10.0-windows10.0.19041.0

# اندروید (نیازمند Android SDK/Emulator)
dotnet build Tarazin.Maui/Tarazin.Maui.csproj -t:Run -f net10.0-android

# راه‌اندازی دیتابیس (یک‌بار)
docker compose up -d   # SQL Server روی localhost:1433
```

## 7. Pitfalls (درس‌های سخت‌گرفته)

| # | مشکل | راه‌حل |
|---|------|--------|
| 1 | صفحهٔ سفید در WebView | `_framework/blazor.webview.js` را فراموش کرده‌اید یا `Selector` با `id="app"` نمی‌خواند |
| 2 | خطای `blazor.server.js` در MAUI | رانتایم Hybrid = `blazor.webview.js` — نه server، نه web |
| 3 | `_content/...` فایل‌های RCL پیدا نمی‌شوند | مسیر درست: `_content/{AssemblyName}/...` — برای `Tarazin.Ui` می‌شود `_content/Tarazin.Ui/css/app.css` |
| 4 | تداخل namespace | RCL = `Tarazin`، هاست وب = `Tarazin.Web`، هاست MAUI = `Tarazin.Maui` — هیچ‌کدام نباید هم‌نام شوند |
| 5 | اسکریپت‌های SQL در MAUI پیدا نمی‌شوند | آن‌ها EmbeddedResource در RCL هستند؛ `ScriptCatalog` با پیشوند `Tarazin.Scripts.` بارگذاری می‌کند |
| 6 | خطای SqlClient روی اندروید/iOS | محدودیت پلتفرم (بخش ۵) — ویندوز/مک را هدف بگیرید یا لایهٔ داده را عوض کنید |
| 7 | `appsettings.json` خوانده نمی‌شود | به‌صورت `EmbeddedResource` با `LogicalName="Tarazin.Maui.appsettings.json"` و `AddJsonStream` |
| 8 | build بدون workload خطا می‌دهد | `dotnet workload install maui` (CI: `windows-latest`) |
| 9 | MudBlazor بدون JS | `_content/MudBlazor/MudBlazor.min.js` را در index.html اضافه کنید (CSS هم لازم است) |
| 10 | اعتبارنامهٔ SQL در بستهٔ اپ | هرگز رازهای تولید را داخل appsettings بومی نگذارید؛ از پیکربندی per-machine استفاده کنید |
| 11 | scoped سرویس در MAUI | circuit وجود ندارد؛ scoped ≈ singleton — برای اپ تک‌کاربره درست است |
| 12 | لوگوی Windows | `Package.appxmanifest` به `Assets/StoreLogo.png` اشاره می‌کند — فایل باید وجود داشته باشد |

## 8. Checklist نهایی (قبل از تحویل)

- [ ] `dotnet build Tarazin.Web/Tarazin.Web.csproj` سبز (هسته + وب)
- [ ] `dotnet build Tarazin.Maui/... -f net10.0-windows10.0.19041.0` سبز (با workload)
- [ ] `docker compose up -d` و ورود admin/admin در **هر دو** هاست
- [ ] یک فرم ثبت داده (مثلاً سند حسابداری) در MAUI امتحان شده و در گزارش/ممیزی دیده می‌شود
- [ ] RTL و تاریخ شمسی (MudDatePicker با fa-IR) در WebView درست است
- [ ] `tools/cross-schema-scan.sh` پاس
- [ ] صفحه‌های جدید فقط در `Tarazin.Ui/Modules` ساخته شده‌اند
- [ ] بدون راز/credential در `Tarazin.Maui/appsettings.json`

## 9. منابع
- مستندات مایکروسافت: «Blazor Hybrid» و «BlazorWebView»
- الگوی رسمی: `dotnet new maui-blazor`
- این مخزن: `Tarazin.Maui/` نمونهٔ کامل مرجع است
- اسکیل‌های مرتبط: `tarazin-project-architecture`، `blazor-data-access`،
  `blazor-create-project`
