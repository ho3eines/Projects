# عیب‌یابی بالا نیامدن اپ ویندوز MAUI

## سناریو: پنجره باز می‌شود ولی «can't reach this page / ERR_CONNECTION_CLOSED» روی 0.0.0.0

**نشانه‌ها:** در Release برنامه اجرا می‌شود، پنجره می‌آید، و `maui-crash.log` کاملاً
سالم است (تا `CreateWindow completed` پیش می‌رود و هیچ استثنایی ندارد)، ولی داخل
پنجره صفحهٔ خطای Edge دیده می‌شود:

```text
Hmmm… can't reach this page
It looks like 0.0.0.0 closed the connection.
ERR_CONNECTION_CLOSED
```

**این خطای شبکه نیست.** `0.0.0.0` میزبان مجازی‌ای است که `BlazorWebView` روی ویندوز
برای سرو کردن `wwwroot/index.html` و `_content/...` استفاده می‌کند؛ هیچ سوکت واقعی و
هیچ پورتی در کار نیست و اینترنت/فایروال/پراکسی بی‌ربط‌اند.

**ریشه:** در MAUI 8، `WinUIWebViewManager.TryServeFromFolderAsync` صفحهٔ میزبان را از
روی دیسک می‌خواند:

* برنامهٔ packaged (MSIX نصب‌شده) → `Package.Current.InstalledLocation\wwwroot\index.html`
* برنامهٔ unpackaged → `AppContext.BaseDirectory\wwwroot\index.html`

اگر فایل پیدا نشود، MAUI **هیچ پاسخی برای درخواست ست نمی‌کند** (فقط یک لاگ
«Response content not found»). آن‌وقت WebView2 درخواست را واقعاً به شبکه می‌فرستد، به
میزبان جعلی `0.0.0.0` می‌رسد و Edge همین صفحهٔ خطا را نشان می‌دهد. یعنی پیام
`ERR_CONNECTION_CLOSED` در عمل معنی‌اش **«فایل نیست»** است، نه «شبکه نیست».

چرا فقط در Release: در Debug، ویژوال استودیو بستهٔ packaged را درست register و اجرا
می‌کند. در Release معمولاً یکی از این دو حالت رخ می‌دهد:

1. exe لختِ داخل `bin\Release\net8.0-windows10.0.19041.0\win10-x64\` مستقیم اجرا شده،
   در حالی که در بیلد packaged محتوای واقعی در `obj\...\MsixContent\` قرار می‌گیرد.
2. بستهٔ MSIX نصب‌شده static web assets را ندارد (خروجی ناقص یا publish نیمه‌کاره).

**تشخیص سریع:** لاگ را باز کنید:

```text
%LocalAppData%\Tarazin\maui-crash.log
```

از این نسخه، برنامه پیش از ساخت WebView دارایی‌ها را بررسی می‌کند و دقیقاً می‌نویسد
کجا را گشته و چه چیزی نبوده (`بررسی دارایی‌های وب (wwwroot)`)، و اگر فایلی غایب باشد
به‌جای WebView خالی یک صفحهٔ خطای فارسی با مسیرها نشان می‌دهد. لاگ‌های خود
`BlazorWebView` هم در همین فایل نوشته می‌شوند.

**بررسی دستی:** کنار `Tarazin.Maui.exe` باید این‌ها باشند:

```text
wwwroot\index.html
wwwroot\_content\MudBlazor\MudBlazor.min.css
wwwroot\_content\Tarazin.Ui\css\app.css
```

**رفع:**

```powershell
# خروجی unpackaged که همهٔ دارایی‌ها را کنار exe می‌گذارد (تست سریع):
dotnet publish .\Tarazin.Maui\Tarazin.Maui.csproj /p:PublishProfile=Folder-win10-x64
.\Tarazin.Maui\bin\Release\net8.0-windows10.0.19041.0\win10-x64\folder-publish\Tarazin.Maui.exe
```

اگر بیلد packaged می‌خواهید، بستهٔ MSIX را **نصب** کنید و از منوی استارت اجرا کنید؛
اجرای مستقیم exe از پوشهٔ بیلد packaged همین خطا را می‌دهد. در صورت خروجی ناقص:

```powershell
dotnet clean .\Tarazin.Maui\Tarazin.Maui.csproj
Remove-Item -Recurse -Force .\Tarazin.Maui\obj, .\Tarazin.Maui\bin
dotnet publish .\Tarazin.Maui\Tarazin.Maui.csproj /p:PublishProfile=MSIX-win10-x64
```

بیلد ویندوز حالا هشدارهای `TZN0001`/`TZN0002`/`TZN0003` می‌دهد اگر این فایل‌ها در
خروجی نباشند — یعنی مشکل سرِ بیلد دیده می‌شود، نه بعد از اجرا.

**کارهای بی‌فایده (وقت‌تان را نگیرید):** بررسی فایروال/پراکسی، نصب دوبارهٔ WebView2
Runtime، تغییر `<base href>`، یا هر تنظیم شبکه‌ای. هیچ‌کدام ربطی به این خطا ندارند.

---


اگر پروژه بدون خطای build ساخته می‌شود ولی پنجرهٔ برنامه باز نمی‌شود، دو علت رایج است:

1. خروجی MSIX بدون نصب/امضای درست اجرا شده است. برای نصب روی سیستم دیگر، MSIX باید signed باشد.
2. Windows App SDK Runtime روی دستگاه مقصد نصب نیست و برنامه قبل از رسیدن به کد managed بسته می‌شود.

در این شاخه برای کاهش این خطاها:

- خروجی ویندوز **در Release** self-contained شد: `WindowsAppSDKSelfContained=true` (فقط Release).
  در Debug عمداً framework-dependent است: در بیلد packaged (MSIX) معمولی، فایل
  `obj\...\MsixContent\AppxManifest.xml` تولید نمی‌شود و فعال‌بودن self-contained در Debug
  باعث خطای `MSB4018` (تسک `GenerateAppManifestFromAppx`) می‌شود. در F5 دیباگ، خود Visual
  Studio پکیج framework ویندوز App SDK را روی دستگاه توسعه register می‌کند (نیاز به نصب
  جداگانهٔ runtime ندارد؛ اگر دستگاه runtime را نداشت، از
  `winget install Microsoft.WindowsAppRuntime.1.5` استفاده کنید).
- پروفایل x64 استاندارد اضافه شد: `MSIX-win10-x64.pubxml`.
- پروفایل تست مستقیم اضافه شد: `Folder-win10-x64.pubxml`.
- لاگ و fallback native startup اضافه شد تا اگر BlazorWebView/XAML خطا داد، پنجرهٔ خطا بسته نشود.

## تست سریع بدون MSIX

```powershell
dotnet publish .\Tarazin.Maui\Tarazin.Maui.csproj /p:PublishProfile=Folder-win10-x64
.\Tarazin.Maui\bin\Release\net8.0-windows10.0.19041.0\win10-x64\folder-publish\Tarazin.Maui.exe
```

## MSIX x64

```powershell
dotnet publish .\Tarazin.Maui\Tarazin.Maui.csproj /p:PublishProfile=MSIX-win10-x64
```

برای نصب MSIX روی دستگاه دیگر، بسته باید امضا شود؛ Visual Studio Publish wizard می‌تواند self-signed certificate بسازد.

## لاگ startup

```text
%LocalAppData%\Tarazin\maui-crash.log
```

اگر برنامه همچنان هیچ پنجره‌ای نشان نداد و این فایل هم ساخته نشد، مشکل قبل از managed startup است؛ معمولاً نصب/امضا/Windows App Runtime یا اجرای مستقیم exe خروجی packaged به‌جای نصب MSIX.
