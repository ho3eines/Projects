# فهرست اسکیل‌های راهنما (SKILLS_INDEX)

> خلاصهٔ یک‌جای هر ۴ اسکیل رسمی پروژهٔ «ترازین» + سناریوی استفاده از هرکدام.
> منبع یکتا (و الزامی) قواعد کدنویسی در `.claude/skills/{name}/SKILL.md` است — این فایل فقط **نمایه و راهنما** است، نه جایگزین متن اسکیل.
>
> ⚠️ **قاعدهٔ طلایی:** اگر بین یک اسکیل و کد واقعی اختلاف دیدی، **اسکیل را به‌روز کن** نه اینکه برخلافش کد بزنی.
> ⚠️ **قانون طلایی بیلد:** بعد از هر تغییر در `Tarazin.Ui` حتماً `dotnet build Tarazin.Web/Tarazin.Web.csproj` بزن (جزئیات در اسکیل development).

---

## ۱. tarazin-development — معماری و کدنویسی (اسکیل مادر)

**فایل:** `.claude/skills/tarazin-development/SKILL.md`
**زمان خواندن:** قبل از **هر** تغییر کد در پروژه (هر پنج پروژه: Share/Data/Ui/Web/Maui).

**خلاصه:**
- معماری ۵ پروژه با وابستگی یک‌طرفه `Share ← Data ← Ui ← {Web, Maui}` و قواعد لایه‌بندی (مدل فقط در Share، داده فقط در Data، UI فقط در Ui).
- لایهٔ داده: `DbService` + اسکریپت‌های نامدار Embedded TSQL (`Tarazin.Data/Scripts/{schema}/`) + `ScriptCatalog` — هرگز SQL خام در Razor.
- چیدمان پوشهٔ ماژول‌ها (`Modules/{Module}/Pages/...`)، الگوهای MudDialog، نوبار/منو (`TarazinModules`)، تله‌های نسخهٔ MudBlazor 9.8.0 (MUD0002، ValidateAsync، ActivatorContent).
- مدل RBAC چهارلایه، نشست کاربر و بافت شرکت/سال مالی فعال، تم RTL و فونت‌ها، خط لولهٔ چاپ/PDF (QuestPDF).
- قواعد سبک کد، دستورهای بیلد/تست، و الگوهای کپی‌پذیر (جدول CRUD، فرم، منو، دیالوگ).

**سناریوی استفاده:** شروع هر کار — قبل از ساخت صفحه، سرویس، مجوز، آیتم منو یا اسکریپت SQL، اول اینجا قواعد معماری و لایه را چک کن.

---

## ۲. tarazin-ui-ux — کاتالوگ کامپوننت و طراحی رابط کاربری

**فایل:** `.claude/skills/tarazin-ui-ux/SKILL.md`
**زمان خواندن:** قبل از ساخت/ویرایش **هر** `.razor` (صفحه، جدول، فرم، دیالوگ، پیکر، کارت داشبورد، حالت خالی، اسکلتون، زیرمنو، هر کلاس `tz-*`).

**خلاصه:**
- کاتالوگ کامپوننت‌های مشترک با پارامترهای دقیق: `PageHeader`، `PageToolbar`، `TzDataTable<T>`، `EmptyState`، `TableSkeleton`، `FormSection`، `EntityActions`، `StatusChip`، `StatCard`، `ModuleCard`، `ModuleSubNav`، `PrintBrandHeader` و پیکرها (`EntityPickerField`، `AccountPickerField`، ...).
- قانون بازاستفاده: جدول جدید = `TzDataTable`، حالت خالی = `EmptyState`، اسکلتون = `TableSkeleton` — ساخت نسخهٔ موازی ممنوع.
- پالت `TarazinAccents` و قرارداد `--tz-accent`، کلاس‌های `tz-*` در `wwwroot/css/app.css`.
- جریان CRUD پایه: `EntityCrudService` + `EntityEditorDialog` + کارخانه‌های `EntityEditorModel.From{Entity}` + چهار ویرایش هماهنگ برای موجودیت جدید.
- تله‌های MudBlazor 9.8.0 (MUD0002)، قانون literal-vs-expression در Razor، تعهدات RTL/ریسپانسیو/dark-mode/prefers-reduced-motion.

**سناریوی استفاده:** هر کار UI — قبل از ساخت هر تکهٔ رابط، اول §۲ کاتالوگ را چک کن؛ اگر کامپوننت مشترک هست از همان استفاده کن، اگر نه «کامپوننت مشترک» بساز نه کد inline.

---

## ۳. tarazin-reporting — گزارش‌سازی، چاپ و PDF

**فایل:** `.claude/skills/tarazin-reporting/SKILL.md`
**زمان خواندن:** قبل از ساخت/ویرایش هر صفحهٔ گزارش (`.razor` در `Modules/*/Pages/*Reports*`)، دیالوگ چاپ یا خروجی PDF.

**خلاصه:**
- یک روال واحد برای همهٔ گزارش‌ها: اسکلت صفحه (`PageHeader` + فیلترها + جدول + جمع‌بندی) + خط لولهٔ چاپ/PDF یکسان.
- خط لولهٔ چاپ: `ReportPrintDialog` (پیش‌نمایش + چاپ + دانلود) + `PdfReportService.BuildTablePdf` (QuestPDF سمت سرور) + `IPdfSaver` (وب: بلاب، MAUI: فایل محلی).
- نام فایل PDF استاندارد فارسی از `PdfFileNames` (تاریخ شمسی + پاک‌سازی کاراکتر) — هرگز نام دستی.
- تاریخ شمسی و بازهٔ سال مالی، قانون بیلد پس از تغییر گزارش، چک‌لیست نهایی هر صفحهٔ گزارش.
- گاردهای pymupdf (`tools/check-rtl-headers.sh`) و تست‌های PDF در `Tarazin.Tests` — برگشت RTL/اندازه‌ی صفحه را می‌گیرند.

**سناریوی استفاده:** هر گزارش جدید/ویرایش — اسکلت §۲ و خط لولهٔ §۳ را دنبال کن؛ چاپ/PDF را هرگز از نو نساز، از `ReportPrintDialog` + `BuildTablePdf` استفاده کن.

---

## ۴. windows-computer-control — تست بصری ویندوز

**فایل:** `.claude/skills/windows-computer-control/SKILL.md`
**زمان خواندن:** هر تست چشمی/ریسپانسیو/دستگاه (وقتی خروجی بصری باید دیده یا تأیید شود).

**خلاصه:**
- کنترل دسکتاپ ویندوز از طریق MCP (ابزارهای `computer.*`/`windows.*`/`ui.*`/`vision.*`) برای تست بصری UI پروژه.
- روال اجباری بررسی: اول مشاهده (`get_screen`/`windows.list`) → یافتن پنجره → `ui.tree`/`ui.find` → در صورت نبود UI Automation از capture + OCR → مختصات فقط از capture تازه → تأیید بعد از هر gesture.
- سناریوی تست Tarazin: صفحهٔ ورود/AppBar/Drawer/زیرمنو/فرم‌ها/جدول‌ها/دیالوگ‌ها، viewport دسکتاپ و موبایل، فونت Vazirmatn، RTL، overflow افقی، حالت dark.
- سلسله‌مراتب امنیت: SAFE (capture/OCR/list)، MODERATE (کلیک/تایپ/resize)، HIGH RISK (execute/کشتن process/حذف فایل — نیاز به تأیید صریح).
- هر تست باید شامل viewport، مسیر، نتیجه، مشکل، روش تشخیص و تغییر اعمال‌شده باشد؛ اگر MCP تزریق نشده فقط اتصال CLI را گزارش کن.

**سناریوی استفاده:** وقتی باید خروجی واقعی را ببینی/تأیید کنی (رندر، ریسپانسیو، dark mode، فونت) — قبل از ادعای «درست نمایش داده می‌شود»، طبق روال اجباری این اسکیل مشاهده و ثبت کن.

---

## جدول انتخاب سریع

| کار | اسکیل اصلی | مکمل |
|-----|-----------|------|
| شروع هر کار کدنویسی | development | — |
| ساخت/ویرایش هر `.razor` | ui-ux | development |
| ساخت/ویرایش گزارش، چاپ، PDF | reporting | ui-ux |
| تست چشمی/دستگاه/ریسپانسیو | windows-computer-control | reporting |
| افزودن موجودیت جدید (CRUD) | ui-ux (§۳.۱) | development (RBAC) |
| اسکریپت SQL جدید | development | — |

---

*همهٔ اسکیل‌ها از گیت در دسترس‌اند: `.claude/skills/{name}/SKILL.md` — مرجع اصلی: `README.md` (بخش «اسکیل‌های راهنما»).*
