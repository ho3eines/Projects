---
name: windows-computer-control
description: کنترل امن و قابل‌راستی‌آزمایی دسکتاپ ویندوز از طریق MCP برای تست بصری UI پروژه.
version: 1.0.0
---

# Windows Computer Control

این اسکیل برای مشاهده و تست بصری Tarazin Web با سرور `screen_windows` استفاده می‌شود.

## ابزار سریع Python

برای جلوگیری از سربار اجرای Hermes در هر درخواست، کلاینت سبک زیر مستقیماً با Streamable HTTP به MCP متصل می‌شود:

```bash
python tools/windows_mcp_client.py screen
python tools/windows_mcp_client.py list-windows
python tools/windows_mcp_client.py call computer.capture_screen '{"format":"jpeg","quality":70,"resize":1280}'
```

این ابزار فقط به کتابخانهٔ استاندارد Python وابسته است، دادهٔ JSON را مستقیم ارسال می‌کند و برای capture/inspection سریع مناسب است. عملیات حساس را فقط با `call` و پس از بررسی/تأیید اجرا کن.

## اتصال

سرور MCP باید فعال باشد:

```text
http://127.0.0.1:5050/mcp
```

بررسی اتصال:

```bash
hermes mcp test screen_windows
```

پس از تغییر کانفیگ MCP، در Hermes از `/reload-mcp` استفاده کن. ابزارهای مورد انتظار با پیشوند `mcp_screen_windows_` ارائه می‌شوند.

## روال اجباری بررسی UI

1. ابتدا با `computer.get_screen` یا `windows.list` وضعیت را مشاهده کن.
2. پنجرهٔ `Tarazin.Web` یا مرورگر را با `windows.find` پیدا و فعال کن.
3. برای عناصر قابل دسترسی، اول `ui.tree` و `ui.find` را استفاده کن.
4. اگر UI Automation برای Chrome کامل نبود، از `computer.capture_window` سپس `vision.ocr` یا `vision.analyze` استفاده کن.
5. مختصات را فقط از capture تازه بگیر؛ مختصات قدیمی معتبر نیستند.
6. بعد از هر کلیک، تایپ، تغییر اندازه یا drag با `computer.get_screen_changes` یا capture تازه نتیجه را تأیید کن.

## سناریوی تست Tarazin

- اجرای وب‌اپ با پورت درج‌شده در `Tarazin.Web/Properties/launchSettings.json`.
- بررسی صفحهٔ ورود، AppBar، Drawer، زیرمنو، صفحهٔ خانه، فرم‌ها، جدول‌ها و دیالوگ‌ها.
- تست viewport دسکتاپ و موبایل با تغییر اندازهٔ پنجرهٔ مرورگر.
- بررسی فونت Vazirmatn، اندازهٔ دکمه‌ها، فاصله‌ها، RTL، overflow افقی و خوانایی جدول‌ها.
- تست drag drawer فقط با capture تازه و verify بعد از gesture.
- بررسی حالت dark و focus کیبورد در صورت امکان.

## راهبرد تعامل

اولویت روش‌ها:

1. UI Automation
2. Accessibility patterns
3. Vision/OCR
4. مختصات صفحه به‌عنوان آخرین گزینه

## امنیت

SAFE: capture، OCR، فهرست پنجره‌ها و UI tree.

MODERATE: کلیک، تایپ، resize، اجرای برنامهٔ توسعه.

HIGH RISK: `system.execute`، کشتن process، حذف فایل یا بستن پنجرهٔ مهم؛ بدون تأیید صریح انجام نشود.

## گزارش

هر تست باید شامل viewport، مسیر، نتیجه، مشکل مشاهده‌شده، capture/روش تشخیص و تغییر اعمال‌شده باشد. اگر ابزار MCP در نشست inject نشده بود، فقط اتصال CLI را گزارش کن و ادعای مشاهدهٔ صفحه نداشته باش.
