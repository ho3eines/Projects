# عیب‌یابی اتصال MAUI

## معماری فعلی (ساده‌شده، ۱۴۰۵/۰۵/۲۹)

- **Web/API** اتصال SQL را از پیکربندی سمت سرور می‌خواند (secret استقرار
  `TARAZIN_SQL_CONNECTION` یا مقدار `ConnectionStrings:DefaultConnection` در
  `appsettings.json`؛ `ENC:` برای at-rest هم پشتیبانی می‌شود).
- **MAUI** فقط یک مقدار پیکربندی دارد: `ServerEndpoint` (نشانی عمومی HTTPS وب).
  هیچ connection string، کلید، token یا شناسهٔ مشتری در بستهٔ اپ نیست.

ورود MAUI: نام کاربری/رمز با HTTPS به `POST /api/mobile/login` می‌رود؛ سرور آن
را دقیقاً مثل ورود وب با PBKDF2 روی `[central].[Users]` بررسی می‌کند و پس از
ورود موفق رشتهٔ اتصال خودش را رمزگذاری‌شده (AES-256 با کلید مشتق از همان رمز)
برمی‌گرداند. MAUI در حافظه رمزگشایی می‌کند و همان مسیر مستقیم `DbService` را
اجرا می‌کند. بنابراین: **اگر ورود وب سالم است و API در دسترس است، ورود MAUI نیز
باید سالم باشد.**

> connection string، رمز SQL، پاسخ API یا متن خام exception را در issue،
> screenshot، log، command history یا فایل پیکربندی MAUI قرار ندهید.

## چرا ورود Web موفق است ولی MAUI خطا می‌دهد؟

در این مدل فقط چند دلیل ممکن است:

1. **API از دستگاه MAUI در دسترس نیست** («سرویس ورود در دسترس نیست»): نشانی
   `ServerEndpoint`، DNS، پایداران/Up بودن Web و گواهی HTTPS وب را چک کنید. روی
   Android emulator مقدار `localhost` به خود emulator اشاره می‌کند نه ویندوز —
   از IP شبکهٔ همان ماشین (همراه گواهی معتبر برای آن نام) استفاده کنید.
2. **HTTPS در production نیست** («برای ورود، اتصال امن HTTPS لازم است»).
3. **تعداد تلاش‌ها زیاد است** (rate limit ثابت ۵ تلاش در دقیقه برای هر IP).
4. **زیرساخت SQL سمت سرور** («سرویس اتصال موقتاً در دسترس نیست»): همان لحظه در
   کنسول Web خط `Mobile connection login failed (ErrorType, SqlNumber=...,
   SqlNumbers=...)` ثبت می‌شود؛ شماره‌ها دلیل دقیق را می‌گویند.
5. **پاسخ قابل رمزگشایی نیست** («پاسخ سرویس اتصال معتبر نیست»): معمولاً یعنی
   باینری MAUI از نسخهٔ همین شاخه rebuild نشده است.
6. **SQL از دستگاه MAUI reachable نیست:** بعد از ورود، MAUI مستقیماً به
   `Data Source` همان رشته وصل می‌شود؛ مقدار `localhost` فقط روی همان ماشین
   درست است. در استقرار واقعی اتصال سرور را روی نام/IP قابل‌دسترس دستگاه‌ها
   تنظیم کنید و firewall را باز آزمایش کنید.

## پیکربندی Web و SQL

برای همهٔ محیط‌ها:

- اتصال SQL همیشه رمزنگاری می‌شود (`Encrypt=true`)، اما اعتبارسنجی گواهی طبق
  تصمیم مالک پروژه (۱۴۰۵/۰۵/۲۹) غیرفعال است (`TrustServerCertificate=true`)؛
  بنابراین گواهی خودامضای پیش‌فرض SQL Server محلی مشکلی ایجاد نمی‌کند. برای این
  تصمیم و پیامدهایش `docs/SECURITY.md` و `docs/adr/ADR-004-maui-blazor-hybrid.md`
  را ببینید.
- اگر TLS در reverse proxy خاتمه می‌یابد، `ReverseProxy:Enabled` را فعال و IP دقیق
  proxy بلافصل را در `ReverseProxy:KnownProxies` ثبت کنید. forwarded header از
  proxy ناشناخته پذیرفته نمی‌شود.

## پیکربندی MAUI

`Tarazin.Maui/appsettings.json` فقط endpoint عمومی را دارد:

```json
{
  "ServerEndpoint": "https://api.example.invalid/"
}
```

در build غیر-Debug، endpoint غیر HTTPS رد می‌شود (استثنا فقط HTTP روی loopback
در DEBUG). Android نیز cleartext traffic و application backup را صریحاً
غیرفعال می‌کند. برای override در استقرار: متغیر محیطی `TARAZIN_SERVER_ENDPOINT`.

## خطاها و اقدام مناسب

| وضعیت نمایشی | بررسی سمت اپراتور |
|---|---|
| نام کاربری یا رمز عبور صحیح نیست | همان کاربر/رمز در ورود وب هم تست شود؛ کاربر فعال و حذف‌نشده باشد. |
| سرویس ورود در دسترس نیست | HTTPS endpoint، DNS، proxy، گواهی وب و دسترسی شبکهٔ دستگاه MAUI. |
| سرویس اتصال موقتاً در دسترس نیست | خط console مربوط به همان لحظه (`Mobile connection login failed`) را بخوانید؛ سلامت SQL و پیکربندی اتصال سرور را کنترل کنید. |
| برای ورود، اتصال امن HTTPS لازم است | endpoint را HTTPS کنید یا `ASPNETCORE_ENVIRONMENT=Development` برای توسعه. |
| تعداد تلاش‌ها زیاد است | یک دقیقه صبر و تلاش مجدد. |
| پاسخ سرویس اتصال نامعتبر است | Web و MAUI را از یک commit rebuild کنید. |
| اتصال امن پایگاه داده آماده نیست | هنوز ورود انجام نشده یا نشست محلی پاک شده؛ دوباره وارد شوید. |
| عملیات پایگاه داده انجام نشد (بعد از ورود) | دسترسی شبکهٔ دستگاه به `Data Source` رشتهٔ اتصال را چک کنید (firewall/port). |

برای رخداد production فقط نوع خطا، شماره‌های SQL و زمان را ثبت کنید. متن خام
exceptionهای SQL/HTTP و headerهای Authorization نباید log شوند.
