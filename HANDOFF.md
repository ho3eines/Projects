---
project: Tarazin
type: Handoff
date: 2026-08-22
author: Hermes Agent
status: completed

## خلاصه تغییرات

### مشکل اصلی
در ماژول حسابداری، بخش گزارشات (AccountingReports.razor) وقتی کاربر روی آخرین سطر جدول گردش (DetailAccountTransactionRow) کلیک میکرد، به جای باز کردن دیالوگ، با `Nav.NavigateTo` به صفحهٔ `/accounting/document/{id}` هدایت میشد.

### راهحل
تغییر `OpenDocument` در AccountingReports.razor از ناوبری به DialogService.ShowAsync.

### فایل‌های تغییر یافته
1. `Tarazin.Ui/Modules/Accounting/Components/DocumentDetailDialog.razor` (ایجاد شده)
   - دیالوگ MudBlazor برای نمایش جزئیات سند
   - شامل: تاریخ، نوع، طرف حساب، وضعیت، مبلغ کل، ردیفهای سند
   - استفاده از DocumentById و DocumentLines scripts
   - استفاده از IMudDialogInstance برای بستن دیالوگ

2. `Tarazin.Ui/Modules/Accounting/Pages/AccountingReports.razor` (تغییر)
   - افزودن `@using Tarazin.Modules.Accounting.Components`
   - افزودن `[Inject] private IDialogService DialogService`
   - تغییر `OpenDocument` از `Nav.NavigateTo` به `DialogService.ShowAsync<DocumentDetailDialog>`

### الگوی استفاده از Dialog در پروژه
دیالوگ‌های موجود در پروژه (مثل AccountPickerDialog, EntityEditorDialog) از این الگو پیروی میکنند:
- `@inject IDialogService DialogService`
- `[CascadingParameter] private IMudDialogInstance MudDialog`
- `<MudDialog>` در Rooter
- `MudDialog.Cancel()` برای بستن
- `DialogService.ShowAsync<T>(title, parameters, options)` برای باز کردن

### تست
- Build موفق: `dotnet build Tarazin.Web/Tarazin.Web.csproj` ✅
- Build UI: `dotnet build Tarazin.Ui/Tarazin.Ui.csproj` ✅
- 0 error, فقط warnings وجود دارد

### نحوه تست
1. `cd /d/hermes/projects/webapi && dotnet run`
2. به `/accounting/reports` بروید
3. گزارش «گردش تفصیلی» را انتخاب کنید
4. روی آخرین سطر جدول گردش کلیک کنید
5. دیالوگ «جزئیات سند» باید باز شود (نه ناوبری)
