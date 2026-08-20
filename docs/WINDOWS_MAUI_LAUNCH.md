# عیب‌یابی بالا نیامدن اپ ویندوز MAUI

اگر پروژه بدون خطای build ساخته می‌شود ولی پنجرهٔ برنامه باز نمی‌شود، دو علت رایج است:

1. خروجی MSIX بدون نصب/امضای درست اجرا شده است. برای نصب روی سیستم دیگر، MSIX باید signed باشد.
2. Windows App SDK Runtime روی دستگاه مقصد نصب نیست و برنامه قبل از رسیدن به کد managed بسته می‌شود.

در این شاخه برای کاهش این خطاها:

- خروجی ویندوز self-contained شد: `WindowsAppSDKSelfContained=true`.
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
