# عیب‌یابی اتصال امن

## معماری فعلی

دو مسیر پیکربندی عمداً از هم جدا هستند:

- **Web/API** تنها در سمت سرور، تنظیم اتصال SQL را از پیکربندی استقرار یا secret store دریافت می‌کند.
- **MAUI** هیچ تنظیم، رمز یا کلید SQL ندارد. `Tarazin.Maui/appsettings.json` فقط `ServerEndpoint`، یعنی نشانی غیرمحرمانهٔ HTTPS وب/API، را نگه می‌دارد.

در ورود MAUI، برنامه نام کاربری، رمز ورود و GUID مشتری را از طریق HTTPS به broker (`/api/mobile/connection/login`) می‌فرستد. broker اعتبار کاربر، مشتری، شرکت و مجوز را بررسی می‌کند و پس از موفقیت، MAUI رشتهٔ اتصال SQL را از کنترلر `api/{guid}` دریافت می‌کند (تصمیم محصول: رشتهٔ اتصال کامل). رشتهٔ اتصال و session فقط در حافظهٔ فرایند MAUI نگه‌داری می‌شوند و با خروج پاک/لغو می‌شوند.

> مقدار اتصال SQL، رمز، bearer token یا پاسخ broker را در issue، screenshot، log، command history یا فایل پیکربندی MAUI قرار ندهید.

## راه‌اندازی SQL محلی

Compose دیگر رمز پیش‌فرض ندارد. پیش از اجرا یک رمز قوی و صرفاً محلی در محیط shell قرار دهید:

```bash
export MSSQL_SA_PASSWORD='<strong local-only value>'
docker compose up -d
docker compose ps
bash tools/test-connection.sh
```

اسکریپت تست credential را چاپ نمی‌کند، مقدار پیش‌فرض ندارد و خطای خام driver را نیز بازنشر نمی‌کند. برای login توسعه‌ای غیر از `sa` می‌توان `TARAZIN_SQL_USER` و `TARAZIN_SQL_PASSWORD` را فقط در محیط همان فرایند تنظیم کرد.

## پیکربندی Web/API

اتصال Web از `ConnectionStrings:DefaultConnection` در `Tarazin.Web/appsettings.json` یا (ترجیحاً) environment secret با نام `TARAZIN_SQL_CONNECTION` خوانده می‌شود؛ `TARAZIN_SQL_CONNECTION` اولویت دارد. مقدار واقعی را در `appsettings.json` source-controlled ننویسید؛ آنجا فقط یک placeholder توسعهٔ محلی (`changeme`) است که در production override می‌شود.

Web اتصال را به MAUI از طریق کنترلر `api/{guid}` می‌دهد (تصمیم محصول: رشتهٔ اتصال کامل). این endpoint فقط HTTPS می‌پذیرد، پاسخ `no-store` دارد و هرگز رشتهٔ اتصال را log نمی‌کند. برای production توصیهٔ قوی: آن را با bearer secret یا IP allow-list گیت کنید.

حساب issuer سمت سرور باید فقط مجوزهای لازم برای bootstrap پایگاه داده و ایجاد/لغو principalهای موقت broker را داشته باشد. MAUI نباید credential این حساب را دریافت کند.

برای production:

- SQL encryption و اعتبارسنجی عادی گواهی باید فعال باشند.
- bypass اعتبارسنجی گواهی فقط در محیط توسعهٔ کاملاً محلی مجاز است و نباید به production منتقل شود.
- اگر TLS در reverse proxy خاتمه می‌یابد، `ReverseProxy:Enabled` را فعال و IP دقیق proxy بلافصل را در `ReverseProxy:KnownProxies` تنظیم کنید. forwarded header از proxy ناشناخته پذیرفته نمی‌شود.

## پیکربندی MAUI

`Tarazin.Maui/appsettings.json` باید فقط endpoint باشد:

```json
{
  "ServerEndpoint": "https://api.example.invalid/"
}
```

در build غیر Debug، endpoint غیر HTTPS رد می‌شود. Android نیز cleartext traffic و application backup را صریحاً غیرفعال می‌کند. هیچ connection string، SQL password، decryption key یا token را به این فایل یا platform resourceها اضافه نکنید.

## خطاهای امن و اقدام مناسب

| وضعیت نمایشی | بررسی سمت اپراتور |
|---|---|
| مشتری یافت نشد یا مجاز نیست | ثبت server-side مشتری، فعال بودن شرکت و اتصال کاربر به شرکت را بررسی کنید. |
| مشتری غیرفعال است | وضعیت مشتری، شرکت و `CredentialAccessEnabled` را در control plane بررسی کنید. |
| نشست منقضی/لغو شده است | دوباره وارد شوید؛ token قبلی نباید reuse شود. |
| سرویس ورود در دسترس نیست | HTTPS endpoint، proxy، DNS و سلامت Web/API را بدون چاپ secret بررسی کنید. |
| SQL در دسترس نیست | شبکه، گواهی SQL، مجوز issuer و cleanup principalها را سمت سرور بررسی کنید. |
| authentication/query محلی ناموفق است | credential استقرار را در secret store اصلاح کنید؛ آن را در chat یا log کپی نکنید. |

برای خطاهای production فقط نوع خطا، request/correlation ID غیرمحرمانه و زمان را ثبت کنید. متن خام exceptionهای SQL/HTTP و headerهای Authorization نباید log شوند.
