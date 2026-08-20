# امنیت ترازین — Web + MAUI Blazor Hybrid

آخرین بازبینی: 2026-08-20

این سند مدل تهدید و الزامات عملیاتی معماری پنج‌پروژه‌ای را توضیح می‌دهد. جزئیات
عیب‌یابی استقرار در `docs/CONNECTION_TROUBLESHOOTING.md` و گزارش بازبینی امنیتی
در `docs/SECURITY_REMEDIATION_REPORT.md` (سند تاریخی زمان خودش) است.

## مرزهای اعتماد

- **Web** یک پردازش مورد اعتماد سمت سرور است. رشتهٔ اتصال مدیریتی SQL و رمز
  bootstrap فقط از secret store محیط استقرار به Web تزریق می‌شوند.
- **MAUI** یک کلاینت غیرقابل‌اعتماد است. بسته، IL و حافظهٔ پردازش آن ممکن است
  توسط کاربر دستگاه بازرسی شود؛ بنابراین هیچ credential دائمی، connection
  string، token یا کلید رمزنگاری در بستهٔ آن قرار نمی‌گیرد (فقط نشانی عمومی
  HTTPS وب). رشتهٔ اتصال پس از ورود موفق، رمزگذاری‌شده از API تحویل می‌شود و
  فقط در حافظهٔ همان پردازش می‌ماند.
- SQL Server مرز مجوز است: MAUI پس از ورود موفق دقیقاً با همان هویت اتصالِ
  پیکربندی‌شدهٔ سرور کار می‌کند (همان حسابی که Web استفاده می‌کند).

## مسیر ورود و داده

### Web

`Login → AuthService/PBKDF2 → UserSession → DbService → SQL Server`

Web با provider سمت سرور کار می‌کند. secret اتصال نه به مرورگر ارسال می‌شود و
نه در diagnostics یا log نمایش داده می‌شود.

### MAUI

`Login(username, password) → HTTPS POST /api/mobile/login → PBKDF2 روی
[central].[Users] (همان بررسی ورود وب) → رشتهٔ اتصال سرور، رمزگذاری‌شده با
AES-256-CBC تحت کلید مشتق از رمز ورود (SHA-256) → رمزگشایی فقط در حافظهٔ MAUI →
DbService و اسکریپت‌های نامدار موجود → SQL Server`

- تنها endpoint موبایل `POST /api/mobile/login` است؛ پاسخ‌ها `no-store` هستند و
  rate limit و محدودیت اندازهٔ body دارند. در production بدون HTTPS رد می‌شود.
- کلید رمزگذاری هیچ‌جا ذخیره نمی‌شود: سرور آن را از رمزی که احراز کرده مشتق
  می‌کند و کلاینت از همان رمزی که کاربر تایپ کرده. پس باینری MAUI هیچ کلید
  دائمی ندارد.
- رمز اشتباه و کاربر ناشناخته هر دو از همان مسیر PBKDF2 (با hash ساختگی برای
  کاربر ناشناخته) عبور می‌کنند و پاسخ 401 یکسانی می‌گیرند.
- هیچ session، nonce، توکن یا principal موقت SQLی ساخته، ذخیره یا rotate
  نمی‌شود. خروج از حساب فقط پاک‌سازی محلی حافظه و pool است.

> لایهٔ قبلی (registry مشتری، nonce/session، loginهای موقت `tz_m_*` و RLS
> موبایل) با تصمیم مالک پروژه (۱۴۰۵/۰۵/۲۹) حذف شد. اسکریپت‌های SQL آن‌ها برای
> سازگاری با دیتابیس‌های موجود در migration باقی می‌مانند اما چون دیگر login
> `tz_m_` ساخته نمی‌شود، predicateهایشان عملاً غیرفعال‌اند.

## اتصال SQL از دید MAUI

- رشتهٔ اتصال از پاسخ API رمزگشایی و فقط در RAM نگه داشته می‌شود؛ برای هر اتصال
  با `Encrypt=true`، `TrustServerCertificate=true` و `PersistSecurityInfo=false`
  مصرف می‌شود (اعتبارسنجی گواهی طبق تصمیم ۱۴۰۵/۰۵/۲۹ غیرفعال است؛ رمزنگاری کانال
  حفظ می‌شود).
- MAUI نباید این رشته را در Preferences، SecureStorage، SQLite، فایل، log یا
  browser storage بنویسد. اسکنر `tools/security-regression-scan.py` این را در
  source و artifact بررسی می‌کند.
- رشتهٔ تحویل‌داده‌شده همان اتقالات سرور است؛ یعنی Data Source آن باید از دستگاه
  MAUI قابل‌رسیدگی باشد (برای توسعهٔ محلی localhost کافی است؛ برای دستگاه واقعی،
  اتصال سرور را روی DNS/IP قابل‌دسترس تنظیم کنید).

## پیکربندی و نگه‌داری secret

`Tarazin.Maui/appsettings.json` فقط `ServerEndpoint` عمومی HTTPS را دارد.

Web نیز secret واقعی را در فایل source-controlled ندارد:

- اتصال مدیریتی: secret استقرار (`TARAZIN_SQL_CONNECTION`) یا مقدار dev
  localhost در `appsettings.json`
- رمز مدیر اولیه: secret استقرار (`Tarazin__BootstrapAdminPassword`)
- license اختیاری گزارش‌ساز: فایل خارج از repository/web root که مسیرش با
  `TARAZIN_STIMULSOFT_LICENSE_PATH` داده می‌شود

هیچ bootstrap password پیش‌فرضی وجود ندارد. در دیتابیس خالی، نبودن secret رمز
باعث توقف امن initialization می‌شود.

## TLS و reverse proxy

- MAUI release فقط endpoint با scheme `https` را می‌پذیرد و از certificate
  validation عادی پلتفرم برای وب‌سرور استفاده می‌کند. callback یا تنظیم bypass
  گواهی برای endpoint وب وجود ندارد.
- credential SQL با `Encrypt=true` و `TrustServerCertificate=true` در همهٔ محیط‌ها
  مصرف می‌شود (تصمیم مالک پروژه ۱۴۰۵/۰۵/۲۹): رمزنگاری کانال الزامی می‌ماند ولی
  اعتبارسنجی گواهی SQL Server غیرفعال است تا گواهی خودامضای SQL محلی خطای TLS
  ایجاد نکند. پیامد: محرمانگی در برابر شنود حفظ می‌شود اما اصالت/هویت سرور SQL
  احراز نمی‌شود — برای استقرارهای حساس، این تصمیم را با ریسک‌پذیری شبکه مقایسه
  کنید.
- Web در production، HTTPS را enforce می‌کند؛ درخواست login MAUI بدون HTTPS رد می‌شود.
- در TLS termination، forwarded headers فقط وقتی فعال شوند که IP دقیق proxy
  بلافصل در `ReverseProxy:KnownProxies` ثبت شده باشد. trust list را خالی نکنید و
  headerهای forwarded از اینترنت را مستقیماً نپذیرید.
- Android cleartext traffic و application backup را غیرفعال می‌کند.

## logging و خطا

connection string، password، Authorization header، raw response body و
exception message خام نباید log یا در UI نمایش داده شوند. خطاهای سرویس اتصال
موبایل code/message محدود و امن دارند. لایهٔ داده exceptionهای SQL را به پیام
عمومی نگاشت می‌کند و logها فقط نام operation، نوع خطا و شماره‌های SQL را ثبت
می‌کنند.

## چک‌لیست تولید

- [ ] همهٔ secretها از secret manager تزریق شده و در فایل publish نیستند.
- [ ] endpoint عمومی API و SQL دارای نام DNS و گواهی معتبر هستند.
- [ ] proxy فقط با IP دقیق trusted پیکربندی شده است.
- [ ] Data Source اتصال سرور از دستگاه‌های MAUI مقصد reachable است.
- [ ] artifact نهایی MAUI با `tools/security-regression-scan.py --artifact-root ...`
      اسکن شده است.
- [ ] ورود معتبر/نامعتبر، packet loss شبکهٔ API، SQL unavailable و API
      unavailable در محیط staging اجرا شده‌اند.
- [ ] backup، monitoring و بازبینی audit عملیاتی هستند.

## وضعیت آزمون این تغییر

بازبینی و آزمون‌های static اضافه شده‌اند، اما در sandbox فعلی SDK .NET، MAUI
workload و SQL Server tooling موجود نبود. build، migration و آزمون‌های پویا باید
در CI/staging انجام و قبل از release سبز شوند؛ این تغییر بدون آن تأییدها آمادهٔ
production تلقی نمی‌شود.
