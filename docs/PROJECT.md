# ترازین — نمای کلی پروژه (Master Blueprint)

## معماری

پنج پروژه با وابستگی یک‌طرفه:

```
Tarazin.Share ← Tarazin.Data ← Tarazin.Ui ← Tarazin.Web
                                                 ↕
                                              Tarazin.Maui
```

| پروژه | نقش | خروجی |
|---|---|---|
| `Share` | مدل‌های POCO، enum‌ها، ثوابت | کلاس‌های مشترک |
| `Data` | دسترسی Dapper + اسکریپت‌های TSQL تعبیه‌شده | `DbService`، `ScriptCatalog` |
| `Ui` | RCL — UI، ناوبری، احراز هویت، تم | کامپوننت‌های Blazor |
| `Web` | هاست Blazor Server | اپلیکیشن وب |
| `Maui` | هاست MAUI Blazor Hybrid | اپلیکیشن بومی (Windows/Android/iOS) |

## قراردادهای کلیدی

- **`ICurrentUser`** / **`UserSession`** — اطلاعات کاربر جاری و شرکت فعال
- **`AuthService`** — احراز هویت با PBKDF2
- **`DbService`** — اجرای اسکریپت‌ها با Dapper (پارامتری‌شده)
- **`ScriptCatalog`** — نقشهٔ نام اسکریپت‌ها به فایل‌های `.sql`
- **`EntityCrudService`** — CRUD استاندارد برای جداول

## ماژول‌ها

| ماژول | اسکیمه | مسیر UI | توضیح |
|---|---|---|---|
| حسابداری | `accounting` | `/Modules/Accounting/` | سند، تفصیلی، معین، گزارشات |
| انبار | `inventory` | `/Modules/Store/` | کالا، رسید، حواله، انبارگردانی |
| خزانه‌داری | `treasury` | `/Modules/Currency/` | صندوق، بانک، چک، تنخواه |
| ارز | `currency` | `/Modules/Currency/` | نرخ، کیف پول، خرید/فروش ارز |
| طلافروشی | `goldshop` | `/Modules/GoldShop/` | فاکتور، قیمت طلا، مشتریان |
| حقوق | `payroll` | `/Modules/Payroll/` | کارمندان، فیش حقوقی |
| مرکزی | `central` | `/Modules/Central/` | شرکت‌ها، نقش‌ها، کاربران |
| شعبه | `branch` | `/Modules/Branch/` | شعب و دسترسی شعبه‌ای |
| BI | `bi` | `/Modules/Bi/` | گزارش‌های تحلیلی |
| دارایی | `assets` | `/Modules/Assets/` | دارایی‌های ثابت |

## قوانین توسعه

1. **UI** فقط در `Tarazin.Ui/Modules/{Module}/`
2. **مدل** فقط در `Tarazin.Share`
3. **داده** فقط در `Tarazin.Data/Scripts/{schema}/`
4. هیچ SQL خام در Razor
5. هیچ HTTP برای انتقال عملیات کسب‌وکار (فقط endpoint bootstrap)
6. مرز اسکیمه با `tools/cross-schema-scan.sh` چک می‌شود

## فرآیند توسعه

```
گزارش → مدل → اسکریپت SQL → مجوز → UI → اسکن اسکیمه → CI
```

## دستورات استقرار

```bash
# وب
dotnet publish Tarazin.Web/Tarazin.Web.csproj -c Release -o ./publish

# MAUI ویندوز
dotnet publish Tarazin.Maui/Tarazin.Maui.csproj -c Release -f net8.0-windows10.0.19041.0

# MAUI اندروید
dotnet publish Tarazin.Maui/Tarazin.Maui.csproj -c Release -f net8.0-android

# MAUI iOS
dotnet publish Tarazin.Maui/Tarazin.Maui.csproj -c Release -f net8.0-ios
```

## امنیت

- هش رمز عبور: PBKDF2
- لاگ ممیزی: `accounting.AuditLog`
- جداول مجوز: `central.Permissions`، `central.RolePermissions`
- کوئری‌ها: پارامتری‌شده (Dapper)
- RLS: فیلتر CompanyId در همهٔ اسکریپت‌ها
