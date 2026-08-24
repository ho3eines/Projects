# ماژول داشبورد و BI (Stimulsoft)

این سند نگهدارندهٔ مستندات ماژول BI است: مرکز فرماندهی `/bi`، گزارش‌ها و چاپ (`/bi/reports`) و — مهم‌تر از همه — نحوهٔ کار موتور رندر گزارش (Stimulsoft) در هر پلتفرم، که با بررسی (decompile) سطح IL از اسمبلی‌های نصب‌شده تأیید شده است.

> **ارجاع‌ها:** `PRD.md` §BI 1-121، `README.md`، `todo.md` (ردیف ۱۱)، کامنت‌های `BiReportService.cs` و `Program.cs`.
>
> **وضعیت سند:** بخش «موتور رندر» بر پایهٔ یافتهٔ IL از `Stimulsoft.Drawing.dll` / `Stimulsoft.Base.dll` / `Stimulsoft.Report.dll` نسخهٔ `2024.3.2` (مورخ بررسی: آگوست ۲۰۲۶) است.

---

## ۱. نمای کلی

- اسکیمهٔ دیتابیس: `bi` (۲۸ اسکریپت — `Tarazin.Data/Scripts/bi/`).
- مرکز فرماندهی `/bi` با ۱۴ تب اجرایی/مالی/فروش/خزانه/طلا/ارز/انبار/مشتریان/بدهی‌ها/حقوق/فروشگاه/اهداف/هشدار/تحلیل هوشمند.
- هشدارها: اسکریپت `BiAlerts` از دادهٔ واقعی.
- چاپ و گزارش: `Stimulsoft.Reports.Blazor` + `BiReportService` + صفحهٔ `/bi/reports`.

---

## ۲. زیرساخت چاپ و گزارش

### وابستگی‌ها
| قطعه | نسخه | محل |
|------|------|-----|
| `Stimulsoft.Reports.Blazor` | `2024.3.2` | `Tarazin.Ui/Tarazin.Ui.csproj` |

### اجزای کد
- **`Tarazin.Ui/Services/BiReportService.cs`** — ساخت گزارش جدولی (سربرگ + سرستون + باند داده) از خروجی اسکریپت نامدار.
  - `BuildAsync(def)` — گزارش از دادهٔ واقعی (اسکریپت + پارامترها + عنوان‌های فارسی).
  - `BuildDemoReport()` — گزارش آزمایشی از دادهٔ ثابت (بدون نیاز به دیتابیس/ورود)، برای تست رندر روی هر پلتفرم.
  - `MakeFont(...)` — سازندهٔ فونت هر `StiText`؛ خانوادهٔ فونت **«Vazirmatn»** (همان فونت UI).
  - `GetActualFontName(report)` — نام فونتِ **واقعاً** resolve شده (مثلاً «Roboto»)، با خواندن فیلد داخلی `sixFont` (SixLabors) از طریق reflection (چون `Font.Name` عمومی فقط نام درخواستی را می‌دهد).
- **`Tarazin.Ui/Modules/Bi/Pages/BiReports.razor`** — صفحهٔ `/bi/reports`؛ انتخاب گزارش + بازهٔ تاریخ + نمایش در `StiBlazorViewer` + چاپ/PDF/Excel.
- **`Tarazin.Ui/Modules/Home/DevBiReport.razor`** — صفحهٔ تست `/dev/bireport`؛ نمایش مشخصات میزبان، نسخهٔ `Stimulsoft.Drawing`/`StiReport`، **فونت واقعی رندر** و خروجی تصویری (PNG) صفحهٔ اول بدون Viewer.

### لایسنس
- بدون کلید لایسنس، خروجی با **واترمارک آزمایشی** رندر می‌شود؛ پس از انقضای دورهٔ trial، `StiBlazorViewer` به‌جای گزارش، مودال «Your trial has expired» نشان می‌دهد (خروجی PNG/PDF این گیت را ندارد).
- لایسنس از متغیر محیطی زمان استقرار خوانده می‌شود (`Program.cs`):
  ```csharp
  var path = Environment.GetEnvironmentVariable("TARAZIN_STIMULSOFT_LICENSE_PATH");
  if (…File.Exists…)
      Stimulsoft.Base.StiLicense.LoadFromFile(path);
  ```

---

## ۳. موتور رندر — یافتهٔ IL (ImageSharp در همهٔ پلتفرم‌ها)

این بخش بر پایهٔ decompile کردن IL اسمبلی‌های **`Stimulsoft.Drawing.dll`**، **`Stimulsoft.Base.dll`** و **`Stimulsoft.Report.dll`** (نسخهٔ ۲۰۲۴.۳.۲) نوشته شده و رفتار واقعی موتور در زمان اجرا را توصیف می‌کند:

### ۳.۱ پیش‌فرض موتور: **ImageSharp** (نه System.Drawing)
- در `Stimulsoft.Drawing.Graphics`:
  ```csharp
  public enum GraphicsEngine { Gdi, ImageSharp }
  public static GraphicsEngine GraphicsEngine { get; set; } = GraphicsEngine.ImageSharp;   // ← پیش‌فرض
  ```
- در هیچ‌جای کد decompile شدهٔ `Stimulsoft.Drawing` / `Base` / `Report` این خاصیت **ست نمی‌شود** (فقط مقایسهٔ `== GraphicsEngine.Gdi` هست). پروژهٔ ترازین نیز هیچ‌جای آن را تغییر نمی‌دهد. ⇒ **در همهٔ پلتفرم‌ها (ویندوز، اندروید، iOS) موتور پیش‌فرض ImageSharp است.**

### ۳.۲ مسیر ImageSharp هرگز System.Drawing را وهله‌سازی نمی‌کند
- سازندهٔ `Stimulsoft.Drawing.Font`:
  ```csharp
  if (GraphicsEngine == GraphicsEngine.Gdi)
  {
      netFont = new System.Drawing.Font(…);   // فقط مسیر opt-in
      return;
  }
  // مسیر پیش‌فرض (ImageSharp):
  name = family.Name; …
  sixFont = fontFamily.CreateSixFont(sizeInPoints, style);   // SixLabors.Fonts.Font
  ```
- در مسیر پیش‌فرض میدان `netFont` (نوع `System.Drawing.Font`) **null** می‌ماند. `System.Drawing.Common` فقط یک **مرجع** است و هرگز ساخته نمی‌شود ⇒ **هیچ ریسک `PlatformNotSupportedException` در اندروید/iOS برای مسیر رندر/خروجی وجود ندارد.**

### ۳.۳ چه زمانی Gdi لازم است؟
تنها برای **چاپ مستقیم به پرینتر سخت‌افزاری** (در `Stimulsoft.Report.dll`):
> «Printing does not work with a graphics engine based on ImageSharp. Please switch `Stimulsoft.Drawing.Graphics.GraphicsEngine` to Gdi.»

Viewer، خروجی PNG/PDF/Excel و رندر صفحه همگی در ImageSharp کار می‌کنند و نیازی به سوئیچ ندارند.

### ۳.۴ رزولوشن فونت و فالتبک
حل خانوادهٔ فونت در `Stimulsoft.Drawing.FontFamily` (مسیر ImageSharp):
```csharp
if (!val.TryGet(name, ref key) && !SystemFonts.TryGet(name, ref key))
    key = FontFamilyRoboto;   // ← فونت جاسازیشده‌ی Roboto
```
ترتیب جستجو:
1. فونت‌های جاسازیشدهٔ خود Stimulsoft (Roboto-Regular/Bold/Italic — درون `Stimulsoft.Drawing.dll`).
2. `SystemFonts` (دایرکتوری‌های فونت OS: `C:\Windows\Fonts`، `/system/fonts` در اندروید، `/Library/Fonts` در iOS/Mac).
3. **فالتبک: Roboto جاسازیشده** — پس رندر هرگز به‌خاطر نبود فونت از کار نمی‌افتد.

### ۳.۵ پیامد عملی برای پروژه (فونت «Vazirmatn»)
- فونت گزارش «Vazirmatn» است، اما موتور آن را از **فایل‌های فونت نصب‌شدهٔ همان دستگاه** پیدا می‌کند (نه CSS مرورگر). چون Vazirmatn معمولاً به‌عنوان فونت سیستمی نصب نیست (نه روی ویندوز سرور و نه اندروید/iOS)، موتور به **Roboto** برمی‌گردد.
- در نتیجه در دستگاه‌های بدون Vazirmatn، خروجی وب و موبایل **هر دو Roboto** و یکسان است.
- ⚠️ اگر Vazirmatn روی **سرور** نصب شود، وب = Vazirmatn ولی موبایل = Roboto می‌شود (دیگر یکسان نیست). برای ضمانت «Vazirmatn واقعی» در همهٔ پلتفرم‌ها باید فایل TTF/OTF فونت را در پروژه ببندیم و هنگام استارتاپ در مجموعهٔ فونت رجیستر کنیم (کار پیشنهادی؛ فایل فونت در repo نیست).
- برای دیدن فونتِ واقعاً استفاده‌شده: صفحهٔ `/dev/bireport` (ستون «فونت واقعی رندر») و `BiReportService.GetActualFontName()`.

---

## ۴. صفحه‌های تست و عیب‌یابی
- `/dev/bireport` — رندر گزارش آزمایشی (بدون دیتابیس)، نمایش مشخصات میزبان/موتور، خروجی PNG صفحهٔ اول، و در صورت اتصال SQL، گزارش از دادهٔ واقعی.
- `/diag` — وضعیت ارائه‌دهندهٔ اتصال داده (غیرمحرمانه).

---

## ۵. نکات استقرار / اجرا
- بیلد کامل (وب): `dotnet build Tarazin.Web/Tarazin.Web.csproj`.
- بیلد MAUI اندروید: `dotnet build Tarazin.Maui/Tarazin.Maui.csproj -f net8.0-android` (لازم است `ANDROID_HOME` به SDK اندروید اشاره کند).
- بیلد MAUI ویندوز: `dotnet build Tarazin.Maui/Tarazin.Maui.csproj -f net8.0-windows10.0.19041.0`.
- تست خروجی واقعی در موبایل: برنامه را روی دستگاه/امولاتور اجرا و `/dev/bireport` را باز کن.
