# 📘 Hermes Projects — Master Blueprint

> **Structure**: `D:\hermes\projects\`
> **Last updated**: 2026-08-09

---

## 🧭 Overview

A **modular ERP ecosystem**: one central Blazor WASM client manages all company projects; every product (accounting, inventory, store, ...) is a **Client-only Blazor WASM app**; all data flows through a **single shared WebAPI** that executes **named TSQL scripts**; every project owns its **own DB schema**.

---

## 🗂️ Directory Layout

```
D:\hermes\projects\
│
├── central-client/          ← هوشمند مرکزی: وبسایت شرکت + مدیریت پروژهها + ویجتها + news/blog/gallery/users
│   ├── Pages/               (Dashboard, Projects, News, Blog, Gallery, Users, Auth)
│   ├── Shared/Components/Widgets/   ← ویجتهای قابل نمایش در وبسایت شرکت
│   └── wwwroot/
│
├── webapi/                  ← تنها API سیستم (مشترک بین همه پروژهها)
│   ├── Controllers/SystemController.cs   ← /api/system/{query|execute|scalar}
│   ├── Services/SystemQueryExecutor.cs   ← اجرای فایلهای TSQL نامدار
│   ├── Data/Scripts/{schema}/{name}.sql  ← اسکریپتهای هر پروژه (اسکیمای مجزا)
│   ├── Program.cs / appsettings.json
│   └── wwwroot/ (اختیاری)
│
├── share/                   ← کتابخانه اشتراکی (unified models, components, services, helpers)
│   ├── Models/              (BaseEntity, SystemRequestPayload, ApiResponse, PagedResult, ...)
│   ├── Components/
│   ├── Services/
│   └── Helpers/
│
├── blazordeployservice/     ← پکیج NuGet: سرویسهای عمومی (RequestService, ModalService, ...)
│   ├── Services/RequestService.cs
│   ├── Models/
│   └── wwwroot/{css,js,lib}/
│
├── [project-name]/          ← هر محصول = فقط Client
│   ├── Client/
│   │   ├── Pages/
│   │   │   ├── Entry/               (ورود عملیات)
│   │   │   ├── SpecialOperations/   (عملیات ویژه)
│   │   │   ├── Reports/             (گزارشات)
│   │   │   └── Settings/            (امکانات، جداول پایه)
│   │   ├── Shared/Components/
│   │   └── wwwroot/{css,js,lang,resources}
│   └── Shared/Models/               (مدلهای اختصاصی پروژه)
│
├── accounting/  inventory/  store/  ...   ← پروژههای واقعی
│
└── docs/PROJECT.md
```

---

## 🔑 Core Rules

| # | Rule |
|---|------|
| 1 | هر پروژه = **فقط کلاینت** (Blazor WASM). هیچ API اختصاصی ندارد. |
| 2 | ارتباط داده = **فقط از طریق `webapi`** با اجرای فایلهای **TSQL نامدار**. |
| 3 | هر پروژه **اسکیمای (Schema) مخصوص خودش** را در دیتابیس دارد. |
| 4 | `share/` → مدلها/کامپوننتها/سرویسهای **مشترک** همه پروژهها. |
| 5 | `blazordeployservice/` → منبع **پکیج NuGet** با کامپوننتهای عمومی (RequestService و ...). |
| 6 | کلاینت مرکزی (`central-client`) → سایت داینامیک شرکت + مدیریت پروژهها + ویجتها. |
| 7 | **گزارشمحور**: قبل از هر پروژه، تحقیق کنید چه گزارشاتی لازم است، سپس مدلها را بر اساس آن طراحی کنید. |

---

## 🧩 هر پروژه ۴ بخش دارد

1. **ورود عملیات (Entry)** — عملیات ورودی (مثلاً در حسابداری: ثبت سند، مدیریت اسناد)
2. **عملیات ویژه (Special Operations)** — عملیات الزامی (مثلاً: تغییر سال مالی)
3. **گزارشات (Reports)** — همه گزارشات (قبل از طراحی: تحقیق!)
4. **امکانات (Settings)** — جداول پایه (شرکتها، حسابهای کل/معین/تفصیلی) + امکانات عمومی

---

## 🏠 صفحه اصلی هر نرمافزار

- باکس جستجوی اسناد با فیلترها — حتماً **از تاریخ / تا تاریخ** (پیشفرض امروز، قابل تغییر)
- گرید اسناد روز — کلیک روی ردیف → رفتن به سند

## 📊 داشبورد هر نرمافزار
- خلاصه و نمای کلی **همه بخشها**

---

## 🔐 احراز هویت

- لاگین در **کلاینت مرکزی**
- توکن از طریق **پارامتر URL** به بخشهای دیگر پروژهها ارسال میشود
- کلاینت مرکزی: news / blog / gallery / مدیریت کاربران (تعریف کاربر، دسترسیها)

---

## 🚦 ارتباطات (Flow)

```
central-client ──(login, token)──► [project]-client
      │                                   │
      └──────────► webapi ◄───────────────┘
                      │
            اجرای TSQL نامدار
                      │
            SQL Server (schema per project)
```

---

## ⛔ ممنوعیتها

- ❌ MudBlazor / Radzen — فقط HTML + Bootstrap 5.3 + CSS/JS
- ❌ API اختصاصی برای هر پروژه
- ❌ `server-client-comm` / WebSocket / Controller جدا / SQL خام از کلاینت (`RequestService`)
- ❌ پرسیدن دوباره ساختار از کاربر

مهارت داده: `.agents/hermes-tsql/SKILL.md`

---

## 🎯 گام بعدی (Todo)

- [ ] انتقال و بهروزرسانی `DataGridView` به `blazordeployservice`
- [ ] سرویسهای `ModalService`, `ThemeService`, `TranslateService` عمومی در `blazordeployservice`
- [ ] پروژه حسابداری: تحقیق گزارشات → طراحی مدلها → صفحات Entry/Reports/Settings
- [ ] ویجتهای مرکزی برای وبسایت شرکت