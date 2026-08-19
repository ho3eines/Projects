# عیب‌یابی اتصال امن MAUI

## معماری فعلی

دو مسیر پیکربندی عمداً جدا هستند:

- **Web/API** فقط در سمت سرور، اتصال SQL issuer را از secret store یا متغیر
  `TARAZIN_SQL_CONNECTION` می‌گیرد.
- **MAUI** هیچ connection string، رمز، token دائمی یا کلید SQL ندارد.
  `Tarazin.Maui/appsettings.json` فقط `ServerEndpoint` (نشانی عمومی HTTPS وب) و
  `CustomerGuid` عمومی همان استقرار را نگه می‌دارد. شناسه از فرم ورود، URL یا
  environment خوانده نمی‌شود.

در ورود MAUI، برنامه نام کاربری، رمز و GUID بسته‌بندی‌شده را با HTTPS به broker
`/api/mobile/connection/login` می‌فرستد. broker کاربر، customer، شرکت، عضویت و
nonce را بررسی می‌کند، سپس یک SQL principal کوتاه‌عمر و customer-bound صادر
می‌کند. MAUI فقط همان credential کوتاه‌عمر را در حافظه نگه می‌دارد، پیش از انقضا
refresh می‌کند و در logout آن را revoke می‌کند. endpoint عمومی برای تحویل
connection string کامل وجود ندارد.

> connection string، رمز SQL، bearer token، پاسخ broker یا متن خام exception را در
> issue، screenshot، log، command history یا فایل پیکربندی MAUI قرار ندهید.

## چرا ورود Web موفق است ولی MAUI خطا می‌دهد؟

ورود Web فقط اتصال issuer و query اعتبار کاربر را آزمایش می‌کند. ورود MAUI علاوه
بر آن باید بتواند nonce و session را در control plane ثبت کند، login کوتاه‌عمر SQL
بسازد، user/database آن را grant کند و در پایان revoke/cleanup کند. بنابراین
موفق‌بودن login وب، به‌تنهایی مجوزهای broker برای صدور principal موقت را ثابت
نمی‌کند.

اگر MAUI پیام **«سرویس اتصال موقتاً در دسترس نیست»** نشان می‌دهد، درخواست به
broker رسیده اما broker در مرحلهٔ زیرساخت SQL ناموفق بوده است. لاگ امن Web فقط
`Operation`، `ErrorType` و `SqlNumber` را ثبت می‌کند؛ همان سه مقدار و زمان رخداد
را بررسی کنید، نه متن خام exception یا هیچ credentialی را.

رایج‌ترین علت‌ها:

1. migrationهای `central._Ensure` و `central._MobileSecurity` کامل اجرا نشده‌اند
   و جدول‌های `CredentialRequestNonces` / `MobileCredentialSessions` یا registry
   مشتری آماده نیستند؛
2. issuer سمت Web فقط حق query عادی دارد و حق ساخت/لغو principal کوتاه‌عمر SQL را
   ندارد؛
3. SQL Server یا `master` از Web در دسترس نیست، یا سرویس SQL از دستگاه MAUI قابل
   دسترس نیست؛
4. `CredentialBroker:PublicSqlServer` برای دستگاه MAUI تنظیم نشده یا به localhost
   اشتباه اشاره می‌کند.

## پیکربندی Web و SQL

اتصال issuer را فقط با secret injection سکوی استقرار فراهم کنید؛ برای نمونه با
`TARAZIN_SQL_CONNECTION` یا provider امن پیکربندی ASP.NET. مقدار واقعی را در
repository، `appsettings*.json`، Compose، CI YAML یا مستندات ننویسید.

`CredentialBroker:PublicSqlServer` credential نیست؛ این مقدار فقط نام DNS/IP و
port SQL است که **کلاینت MAUI** باید بتواند به آن برسد. مقدار source-controlled
`localhost` تنها برای توسعهٔ محلی Windows مناسب است. در استقرار واقعی آن را با
نام DNS/IP قابل‌دسترسی از دستگاه و دارای گواهی SQL معتبر جایگزین کنید. برای
Android emulator معمولاً loopback دستگاه با loopback Windows یکی نیست؛ از آدرس
شبکه/adapter مناسب همان emulator استفاده کنید. برای دستگاه واقعی، DNS/IP شبکه و
گواهی باید با نام مقصد سازگار باشند.

issuer سمت سرور باید با حداقل اختیار لازم، امکان ایجاد، grant، disable و drop
کردن principalهای `tz_m_*` و پاک‌سازی sessionهای آن‌ها را داشته باشد. با DBA
هماهنگ کنید؛ بسته به SQL Server معمولاً مجوزهای server-level برای مدیریت login و
session و مجوزهای database-level برای user/role/grant لازم است. این مجوزها فقط
برای هویت server-side Web هستند و هرگز به MAUI داده نمی‌شوند.

برای همهٔ محیط‌ها:

- SQL encryption و اعتبارسنجی عادی گواهی الزامی است؛ bypass گواهی اضافه نکنید.
  **تنها استثنا:** توسعهٔ محلی که SQL Server با گواهی خودامضای پیش‌فرض اجرا می‌شود.
  در این حالت فقط در محیط `Development` و فقط با set کردن صریح
  `TARAZIN_SQL_TRUST_SERVER_CERTIFICATE=1` اعتبارسنجی گواهی سمت سرور وب غیرفعال
  می‌شود (`TrustServerCertificate=true`). این متغیر در هیچ محیط دیگری (Staging/Production)
  اثر ندارد و اتصال issuer همچنان `Encrypt=true` می‌ماند. برای استقرار واقعی گواهی
  معتبر نصب کنید و این متغیر را set نکنید.
- اگر TLS در reverse proxy خاتمه می‌یابد، `ReverseProxy:Enabled` را فعال و IP دقیق
  proxy بلافصل را در `ReverseProxy:KnownProxies` ثبت کنید. forwarded header از
  proxy ناشناخته پذیرفته نمی‌شود.
- پیش از تحویل MAUI، در firewall مسیر SQL از دستگاه هدف به
  `CredentialBroker:PublicSqlServer` را باز و با گواهی معتبر آزمایش کنید.

## پیکربندی MAUI

`Tarazin.Maui/appsettings.json` باید فقط endpoint و شناسهٔ مشتری عمومی باشد:

```json
{
  "ServerEndpoint": "https://api.example.invalid/",
  "CustomerGuid": "11111111-1111-1111-1111-111111111111"
}
```

`CustomerGuid` را با GUID ثبت‌شده در `[central].[CredentialCustomers]` عوض کنید و
فقط پس از تأیید customer/company، `CredentialAccessEnabled` را فعال کنید. GUID از
فرم ورود یا مسیر URL خوانده نمی‌شود.

## چرا /diag در MAUI می‌گوید «اتصال موقت از سرویس وب آماده نیست»؟

این پیام یعنی فرایند MAUI هنوز credential کوتاه‌عمر در حافظه ندارد؛ لزوماً به این
معنی نیست که SQL قطع است. زمان آزمون بسیار کوتاه نشان می‌دهد که هنوز تلاش شبکه‌ای
برای SQL انجام نشده است.

زنجیرهٔ آماده‌سازی فقط با ورود موفق کامل می‌شود:

1. MAUI نام کاربری/رمز را به broker می‌فرستد؛ broker کاربر، customer، شرکت و مجوز
   را بررسی می‌کند.
2. broker SQL credential کوتاه‌عمر را صادر می‌کند و MAUI آن را فقط در حافظه اعمال
   می‌کند.
3. از این لحظه `/diag` می‌تواند اتصال را باز و تست کند.

پس وجود رکورد در `CredentialCustomers` شرط لازم است اما به‌تنهایی اتصال را آماده
نمی‌کند. دکمهٔ «آزمون اتصال» credential جدید صادر نمی‌کند. با خروج یا بستن اپ،
اعتبار حافظه پاک می‌شود و ورود مجدد لازم است.

**اقدام:** Web را روی `ServerEndpoint` بالا بیاورید، ابتدا login MAUI را کامل کنید
(پیام «خوش آمدید») و سپس `/diag` را تست کنید. در build غیر-Debug، endpoint غیر
HTTPS رد می‌شود. Android نیز cleartext traffic و application backup را صریحاً
غیرفعال می‌کند.

## خطاهای امن و اقدام مناسب

| وضعیت نمایشی | بررسی سمت اپراتور |
|---|---|
| مشتری یافت نشد یا مجاز نیست | GUID را در registry server-side، فعال‌بودن شرکت و عضویت کاربر در همان شرکت بررسی کنید. |
| مشتری غیرفعال است | وضعیت customer، شرکت و `CredentialAccessEnabled` را بررسی کنید. |
| سرویس ورود MAUI روی سرور پیکربندی نشده است | `TARAZIN_SQL_CONNECTION` و `CredentialBroker:PublicSqlServer` را فقط در تنظیمات امن server بررسی کنید. |
| سرویس ورود MAUI روی سرور آماده نشده است | اجرای کامل startup migrationهای Web، از جمله جدول‌های nonce/session و migration امنیت موبایل را بررسی کنید. |
| سرویس ورود MAUI مجوز صدور اتصال موقت را ندارد | DBA باید مجوز issuer برای ایجاد/grant/revoke principal موقت و cleanup آن را بررسی کند. |
| سرویس اتصال موقتاً در دسترس نیست | لاگ امن Web را با زمان رخداد بررسی کنید؛ migration control plane، سلامت SQL و مجوز issuer را کنترل کنید. |
| سرویس ورود در دسترس نیست | HTTPS endpoint، DNS، proxy، گواهی وب و دسترسی شبکهٔ دستگاه MAUI را بررسی کنید. |
| نشست منقضی/لغو شده است | دوباره وارد شوید؛ token قبلی نباید reuse شود. |
| authentication/query محلی ناموفق است | credential استقرار یا گواهی/شبکهٔ SQL را در secret store و زیرساخت اصلاح کنید؛ آن را در chat یا log کپی نکنید. |

برای رخداد production فقط نوع خطا، request/correlation ID غیرمحرمانه و زمان را
ثبت کنید. متن خام exceptionهای SQL/HTTP و headerهای Authorization نباید log شوند.
