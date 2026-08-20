# امنیت ترازین — Web + MAUI Blazor Hybrid

آخرین بازبینی: 2026-08-18

این سند مدل تهدید و الزامات عملیاتی معماری پنج‌پروژه‌ای را توضیح می‌دهد. جزئیات
عیب‌یابی استقرار در `docs/CONNECTION_TROUBLESHOOTING.md` و گزارش بازبینی امنیتی
در `docs/SECURITY_REMEDIATION_REPORT.md` است.

## مرزهای اعتماد

- **Web** یک پردازش مورد اعتماد سمت سرور است. رشتهٔ اتصال مدیریتی SQL و رمز
  bootstrap فقط از secret store محیط استقرار به Web تزریق می‌شوند.
- **MAUI** یک کلاینت غیرقابل‌اعتماد است. بسته، IL و حافظهٔ پردازش آن ممکن است
  توسط کاربر دستگاه بازرسی شود؛ بنابراین هیچ credential دائمی یا کلید دائمی در
  آن قرار نمی‌گیرد.
- `CustomerGuid` فقط یک selector عمومی است، نه هویت یا مجوز. هویت کاربر، وضعیت
  مشتری، شرکت، عضویت کاربر و نشست broker همگی سمت سرور بررسی می‌شوند.
- SQL Server آخرین مرز مجوز است. loginهای تولیدشده عمر کوتاه، مجوز محدود و RLS
  وابسته به مشتری دارند.

## مسیر ورود و داده

### Web

`Login → AuthService/PBKDF2 → UserSession → DbService → SQL Server`

Web با provider سمت سرور کار می‌کند. secret اتصال نه به مرورگر ارسال می‌شود و
نه در diagnostics یا log نمایش داده می‌شود.

### MAUI

`Login(username, password, CustomerGuid) → HTTPS broker → اعتبارسنجی مشتری/کاربر
→ credential کوتاه‌عمر → DbService و اسکریپت‌های نامدار موجود → SQL Server`

endpointهای broker:

- `POST /api/mobile/connection/login`
- `POST /api/mobile/connection/refresh`
- `POST /api/mobile/connection/revoke`

درخواست login و refresh شامل nonce تصادفی و timestamp محدود است. refresh/revoke
از bearer token در header استفاده می‌کنند؛ token در URL قرار نمی‌گیرد. پاسخ‌ها
`no-store` هستند و endpointها rate limit و محدودیت اندازهٔ body دارند.

broker قبل از صدور یا تمدید، موارد زیر را کنترل می‌کند:

1. nonce تکراری نباشد و timestamp داخل پنجرهٔ مجاز باشد؛
2. نام کاربری/رمز PBKDF2 معتبر و کاربر فعال باشد؛
3. `CredentialCustomers` شامل GUID درخواستی باشد؛
4. customer و شرکت متصل فعال و حذف‌نشده باشند و credential access فعال باشد؛
5. کاربر عضو همان شرکت باشد؛
6. در refresh، hash نشست معتبر، منقضی‌نشده، لغونشده و به همان customer متصل باشد.

پایگاه داده فقط hash token و nonce را نگه می‌دارد. SQL password و bearer token
plaintext در جداول ذخیره نمی‌شوند.

## credential موقت SQL

- نام login تصادفی با پیشوند کنترل‌شده ساخته می‌شود.
- credential پیش‌فرض پنج دقیقه عمر دارد و سقف تنظیم‌شدهٔ آن محدود است.
- مجوزها از RBAC کاربر ساخته می‌شوند؛ DDL، `master`، control-plane broker و hash
  رمز کاربران در دسترس mobile role نیستند.
- RLS، login تولیدشده را به session و customer فعال و credential-enabled متصل
  می‌کند و دسترسی مشتری دیگر را فیلتر/مسدود می‌کند.
- login/refresh ابتدا session را در حالت pending ثبت می‌کنند؛ این session تا
  ساخته‌شدن principal و activation نهایی از همهٔ predicateهای RLS رد می‌شود.
- refreshها با قفل family سری می‌شوند و revoke سلف و successor activation در یک
  تراکنش انجام می‌شود. revoke کل family را، حتی با token قدیمی، علامت می‌زند و
  موفقیتش وابسته به گرفتن قفل نیست.
- revoke ابتدا loginها را disable، سپس sessionهای SQL آن‌ها را kill و principalها
  را drop می‌کند. cleanup دوره‌ای backstop pending رهاشده، انقضا و قطع شبکه است.
- triggerهای دیتابیس روی Users/Roles/RolePermissions مانع self-promotion یا ساخت
  مجموعهٔ مجوز قوی‌تر توسط principal غیر-Admin می‌شوند.

credential ناگزیر برای مدت استفاده در حافظهٔ MAUI وجود دارد. HTTPS از آن در
انتقال محافظت می‌کند، اما هیچ رمزنگاری با کلید موجود در همان کلاینت نمی‌تواند
secret قابل‌استفاده را در برابر compromise همان پردازش غیرقابل‌استخراج کند.
کاهش خطر بر عمر کوتاه، least privilege، RLS، rotation و revoke متکی است.

## پیکربندی و نگه‌داری secret

`Tarazin.Maui/appsettings.json` فقط `ServerEndpoint` عمومی HTTPS و `CustomerGuid`
عمومی را دارد. `CustomerGuid` یک selector عمومی است، نه هویت یا مجوز، و فقط از
همین فایل خوانده می‌شود — نه از فرم ورود، نه از مسیر URL. MAUI نباید SQL
connection، password، bootstrap secret، token، license key یا کلید decrypt را در
source/configuration، Preferences، SecureStorage، SQLite، فایل یا browser storage
نگه دارد.

Web نیز secret واقعی را در فایل source-controlled ندارد:

- اتصال مدیریتی: secret استقرار (`TARAZIN_SQL_CONNECTION`)
- رمز مدیر اولیه: secret استقرار (`Tarazin__BootstrapAdminPassword`)
- license اختیاری گزارش‌ساز: فایل خارج از repository/web root که مسیرش با
  `TARAZIN_STIMULSOFT_LICENSE_PATH` داده می‌شود

## تحویل credential کوتاه‌عمر به MAUI

Web هیچ connection string کامل یا credential دائمی را به MAUI تحویل نمی‌دهد.
پس از validation کامل broker، پاسخ login/refresh فقط credential SQL تصادفی،
کوتاه‌عمر، customer-bound و قابل‌لغو همان session را دارد. MAUI آن را فقط در
حافظه نگه می‌دارد و برای هر اتصال با `Encrypt=true`،
`TrustServerCertificate=true` و `PersistSecurityInfo=false` بازسازی می‌کند
(اعتبارسنجی گواهی طبق تصمیم ۱۴۰۵/۰۵/۲۹ غیرفعال است؛ رمزنگاری کانال حفظ می‌شود).

- endpointهای broker فقط HTTPS و `no-store` هستند؛ GUID به‌تنهایی هیچ credentialی
  برنمی‌گرداند.
- `CredentialBroker:PublicSqlServer` تنها یک endpoint غیرمحرمانهٔ SQL است که باید
  از دستگاه MAUI reachable باشد؛ مقدار issuer connection string یا یک localhost
  خصوصی Web نباید به‌صورت ضمنی به client منتقل شود.
- مقدار اتصال issuer فقط از secret استقرار `TARAZIN_SQL_CONNECTION` گرفته می‌شود و
  `appsettings.json` مقدار connection string ندارد.
- هیچ bootstrap password پیش‌فرضی وجود ندارد. در دیتابیس خالی، نبودن secret رمز
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
- Web در production، HTTPS را enforce می‌کند؛ درخواست broker بدون HTTPS رد می‌شود.
- در TLS termination، forwarded headers فقط وقتی فعال شوند که IP دقیق proxy
  بلافصل در `ReverseProxy:KnownProxies` ثبت شده باشد. trust list را خالی نکنید و
  headerهای forwarded از اینترنت را مستقیماً نپذیرید.
- Android cleartext traffic و application backup را غیرفعال می‌کند.

## logging و خطا

connection string، password، bearer token، SQL credential، Authorization header،
raw response body و exception message خام نباید log یا در UI نمایش داده شوند.
خطاهای broker code/message محدود و امن دارند. لایهٔ داده exceptionهای SQL را به
پیام عمومی نگاشت می‌کند و logها فقط نام operation، نوع خطا و در broker شمارهٔ
SQL را ثبت می‌کنند.

## provisioning مشتری

هیچ customer پیش‌فرضی فعال نیست. operator باید پس از ساخت شرکت، یک GUID تصادفی
را server-side در `central.CredentialCustomers` به همان `CompanyId` متصل کند و
فقط پس از تأیید مالکیت، `CredentialAccessEnabled` را فعال کند. همان GUID در
`Tarazin.Maui/appsettings.json` بسته‌بندی می‌شود و کاربر آن را وارد نمی‌کند.
غیرفعال‌کردن customer یا شرکت، RLS را بلافاصله می‌بندد؛ cleanup سپس principalهای
باقی‌مانده را حذف می‌کند.

## چک‌لیست تولید

- [ ] همهٔ secretها از secret manager تزریق شده و در فایل publish نیستند.
- [ ] endpoint عمومی API و SQL دارای نام DNS و گواهی معتبر هستند.
- [ ] proxy فقط با IP دقیق trusted پیکربندی شده است.
- [ ] customer/company و عضویت کاربران قبل از enable شدن تأیید شده‌اند.
- [ ] lifetimeها کوتاه و cleanup فعال است.
- [ ] artifact نهایی MAUI با `tools/security-regression-scan.py --artifact-root ...`
      اسکن شده است.
- [ ] replay، expiry، revoke، GUID جعلی، customer غیرفعال، cross-customer، SQL
      unavailable و API unavailable در محیط staging اجرا شده‌اند.
- [ ] backup، rotation، monitoring و بازبینی audit عملیاتی هستند.

## وضعیت آزمون این تغییر

بازبینی و آزمون‌های static اضافه شده‌اند، اما در sandbox فعلی SDK .NET، MAUI
workload و SQL Server tooling موجود نبود. build، migration و آزمون‌های پویا باید
در CI/staging انجام و قبل از release سبز شوند؛ این تغییر بدون آن تأییدها آمادهٔ
production تلقی نمی‌شود.
