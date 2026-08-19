# بررسی انطباق با PRD — گزارش حسابرسی

> **به‌روزرسانی امنیتی: ۲۰۲۶/۰۸/۱۸**
>
> این سند دیگر ادعای «انطباق کامل» یا اجرای موفق برنامه را مطرح نمی‌کند. راهکار
> فعلی یک Solution پنج‌پروژه‌ای (`Share`، `Data`، `Ui`، `Web` و `Maui`) است.
> تغییرات امنیت credential از نظر منبع و کنترل‌جریان بازبینی ایستا شده‌اند، اما
> به‌دلیل نبود .NET SDK، SQL Server، `sqlcmd`، Docker/Podman و artifact انتشار،
> build، migration و تست E2E در این محیط اجرا نشده‌اند. نتیجه تا سبزشدن gateهای
> بخش ۷ برای release آماده نیست.

---

## ۱) وضعیت معیارهای اصلی

| معیار | وضعیت فعلی | شواهد/محدودیت |
|---|---|---|
| build پنج پروژه | ⚠️ اجرا نشد | `Tarazin.slnx` پنج پروژه دارد؛ Web و MAUI باید در CI build شوند. |
| هفت ماژول اصلی و مسیرهای UI | ⚠️ خارج از دامنهٔ این اصلاح | ساختار حفظ شده است؛ رفتار runtime دوباره تأیید نشده است. |
| SQL نامدار و نبود SQL خام در صفحات | ✅ بررسی ایستا | عملیات کسب‌وکار همچنان از `DbService` و اسکریپت‌های Embedded استفاده می‌کند. |
| مرز schema | ✅ بررسی ایستا | `tools/cross-schema-scan.sh`: ۲۷۱ اسکریپت و بدون reference اعلام‌نشده در آخرین اجرای محلی. |
| قرارداد فراخوان C# و TSQL | ✅ بررسی ایستا | `tools/sql-contract-scan.py`: ۲۷۱ اسکریپت و صفر warning در آخرین اجرا. |
| ورود Web | ⚠️ اجرا نشد | PBKDF2 و bootstrap مبتنی بر secret استقرار حفظ شده‌اند؛ مقدار پیش‌فرض bootstrap حذف شده است. |
| ورود MAUI و آماده‌سازی اتصال | ⚠️ فقط بازبینی ایستا | `Login → broker → credential موقت در حافظه → عملیات مستقیم فعلی DbService`. |
| ممیزی | ❌ gate باز | مالکیت tenant اضافه شده، ولی `RowHash` هنوز `PrevHash` را پوشش نمی‌دهد و lookup/insert سریال نیست. |

## ۲) معماری داده و استثنای امنیتی MAUI

- Web اتصال مدیریتی SQL را فقط از secretهای server-side استقرار می‌گیرد.
- `Tarazin.Maui/appsettings.json` فقط `ServerEndpoint` عمومی HTTPS و `CustomerGuid`
  عمومی دارد؛ هیچ connection string، SQL password، token، یا کلید دائمی در تنظیمات
  MAUI نیست. شناسه از فرم ورود یا URL خوانده نمی‌شود.
- API عمومی CRUD اضافه نشده است. API محدود broker فقط login/refresh/revoke
  credential موقت MAUI را انجام می‌دهد.
- broker قبل از صدور credential، customer، فعال‌بودن customer/user/company،
  مجوز کاربر، binding نشست و nonce/timestamp را بررسی می‌کند.
- credential SQL کوتاه‌عمر، customer/company-bound، revocable و permission-derived
  است؛ MAUI آن را فقط در حافظه نگه می‌دارد. انتقال HTTPS و validation عادی
  certificate اجباری است.
- داشتن credential قابل‌استفاده در process کلاینت به این معنی است که روی دستگاه
  compromise‌شده قابل استخراج است؛ encryption با کلید دائمی داخل client این
  محدودیت را حل نمی‌کند و به‌عنوان راهکار استفاده نشده است.

## ۳) مسیرهای خطا و نشت

- خطاهای broker به کدها و پیام‌های عمومی تبدیل می‌شوند و responseها `no-store` هستند.
- exception خام SQL از مرز `DbService` عبور نمی‌کند؛ logها نوع خطا را ثبت می‌کنند،
  نه message/connection string/password/token را.
- Android backup و cleartext traffic غیرفعال شده‌اند.
- اسکن منبع/تنظیمات با `tools/security-regression-scan.py --self-test` در آخرین
  اجرای محلی پاس شده است. اسکن artifact واقعی MAUI فقط پس از build در CI ممکن است.

## ۴) تغییرات امنیتی مرتبط با PRD

1. پیکربندی SQL از MAUI حذف و با `ISqlConnectionProvider` جایگزین شد.
2. قراردادهای broker و endpointهای `/api/mobile/connection/login`، `refresh` و
   `revoke` اضافه شدند.
3. token و nonce فقط به‌شکل hash در SQL نگهداری می‌شوند؛ SQL password در broker
   persistence ذخیره نمی‌شود.
4. principalهای موقت ابتدا pending هستند، با family lock و تراکنش اتمیک rotate،
   به‌صورت whole-family revoke و سپس cleanup می‌شوند؛ endpoint عمومی SQL اجازهٔ
   تزریق property اضافی connection string را ندارد.
5. migration امنیت موبایل customer/company authorization، RLS، مالکیت ممیزی
   database-resolved و triggerهای ضد self-escalation برای RBAC را اضافه می‌کند؛
   این migration هنوز روی SQL Server واقعی compile/اجرا نشده است.
6. secretهای tracked Web/Compose/tool، license keyها و DLLهای patch‌شده از درخت
   فعال حذف شدند. secretهای قبلی باید compromised فرض و خارج از این PR rotate شوند.
7. CI اسکن source/config و artifact MAUI را اجرا می‌کند؛ نتیجهٔ runner هنوز در
   این محیط موجود نیست.

## ۵) کنترل‌های ایستای اجراشده

- `python3 tools/security-regression-scan.py --self-test`
- `bash tools/cross-schema-scan.sh` — ۲۷۱ اسکریپت
- `python3 tools/sql-contract-scan.py` — صفر warning
- parse فایل‌های JSON و compile ابزارهای Python
- `bash -n tools/test-connection.sh tools/cross-schema-scan.sh`
- جست‌وجوی متمرکز secret، TLS bypass، storage و log
- `git diff --check`

این کنترل‌ها compile یا اجرای .NET/TSQL و اثبات امنیت runtime نیستند.

## ۶) مواردی که اجرا نشده‌اند

- restore/build/test پروژه‌های Web، Data، Ui، Share و targetهای MAUI
- اجرای `_MobileSecurity.sql` و همهٔ migrationها روی SQL Server واقعی
- تست واقعی login/refresh/revoke، pending activation، expiry، replay و cleanup
- customer جعلی/غیرفعال، cross-customer، user/company غیرفعال و مجوز ناکافی
- triggerهای Users/Roles/RolePermissions شامل self-promotion و statement چندردیفی
- قطع API/SQL، credential نامعتبر/منقضی و raceهای refresh/revoke/cancellation
- publish برای Android/Windows و اسکن/decompile APK/EXE/assemblies
- بررسی storage/log/crash dump روی device واقعی

## ۷) gateهای اجباری پیش از release

1. build و تست Web و همهٔ targetهای MAUI در CI سبز شود.
2. migration روی clone سازگار تولید اجرا و rollback/مالکیت داده تأیید شود.
3. ماتریس E2E و امنیت بخش ۶، شامل replay/expiry/cross-customer، پاس شود.
4. artifactهای واقعی publish اسکن و decompile شوند و هیچ secret دائمی نداشته باشند.
5. chain ممیزی اصلاح شود: `RowHash` باید predecessor را commit کند و انتخاب
   predecessor/insert برای هر tenant سریال و اتمیک باشد.
6. SQL principal ایجادشده با permissionهای واقعی هر نقش آزمایش و issuer با
   کمترین اختیار ممکن provision شود.
7. تمام credentialهای تاریخی rotate و پاک‌سازی history به‌صورت جداگانه بررسی شود؛
   checkout فعلی grafted است و نبود secret در history را اثبات نمی‌کند.

گزارش تفصیلی مسیر ورود secret، طراحی broker، فایل‌های تغییرکرده و محدودیت‌های
release در `docs/SECURITY_REMEDIATION_REPORT.md` ثبت شده است.
