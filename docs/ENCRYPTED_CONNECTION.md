# کانکشن استرینگ رمزگذاری‌شده: از appsettings.json به API و MAUI

**تاریخ:** ۱۴۰۵/۰۵/۲۹ — نسخه ۳ (مدل ساده‌شده به درخواست مالک پروژه)  
**وضعیت:** پیاده‌سازی ساده: یک endpoint ورود، رمزگذاری در API، رمزگشایی در MAUI

---

## جریان کلی

```
Tarazin.Web/appsettings.json  ── رشته درست و plain (یا ENC: اختیاری برای at-rest)
        │  TarazinConnection.Resolve()  (اعتبارسنجی + Encrypt/TrustServerCertificate)
        ▼
Tarazin.Web (حافظهٔ سرور)  ── plaintext فقط در RAM سرور
        │  POST /api/mobile/login  { username, password }
        │  ۱) بررسی PBKDF2 روی [central].[Users] — دقیقاً همان ورود وب
        │  ۲) **اینجا** رمزگذاری با AES-256-CBC، کلید = SHA-256(رمز ورود)
        ▼  HTTPS (TLS) + بدنهٔ ENC:Base64(IV+Ciphertext)
Tarazin.Maui (حافظهٔ اپ)  ── کلید = SHA-256(همان رمز تایپ‌شده) ← رمزگشایی فقط در RAM
        │  هیچ کلید یا شناسه‌ای در بستهٔ اپ ذخیره نمی‌شود
        ▼
UI / DbService / SqlConnection (Encrypt=true, TrustServerCertificate=true) → SQL Server
```

هیچ session، nonce، توکن، registry مشتری یا principal موقت SQL (`tz_m_*`) وجود
ندارد؛ MAUI پس از ورود با همان هویت اتصالِ سرور کار می‌کند و خروج از حساب فقط
پاک‌سازی محلی حافظه و connection pool است.

---

## ۱. ذخیره در `Tarazin.Web/appsettings.json`

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=TarazinMaster;User Id=sa;Password=<secret>;Encrypt=True;TrustServerCertificate=True;Application Name=Tarazin"
  }
}
```

- در تولید می‌توانید همان رشته را با متغیر محیطی `TARAZIN_SQL_CONNECTION` تزریق
  کنید؛ `TarazinConnection.Resolve()` اول env را می‌خواند، سپس فایل.
- اگر بخواهید فایل را هم رمزگذاری کنید، با `./tools/encrypt-connection-string.sh`
  مقدار را به `ENC:...` تبدیل و کلید را در `TARAZIN_ENCRYPTION_KEY` بگذارید —
  کد هر دو حالت plain و ENC را می‌فهمد.

نکتهٔ مهم برای دستگاه‌های غیر Windows امتحانی: MAUI مستقیماً به
`Server`/`Data Source` همان رشته وصل می‌شود؛ پس در استقرار واقعی باید به
DNS/IPای اشاره کند که از دستگاه MAUI reachable باشد.

---

## ۲. سمت API (`Tarazin.Web/MobileConnectionService.cs` + Program.cs)

`POST /api/mobile/login` با بدنهٔ `{ "username": "...", "password": "..." }`:

1. `PasswordHasher.Verify` روی hash ذخیره‌شده (برای کاربر ناشناخته یک hash
   ساختگی تأیید می‌شود تا timing یکسان بماند). کاربر غیرفعال/رمز اشتباه →
   پاسخ `401` با کد `invalid_credentials`.
2. پس از احراز موفق:
   ```csharp
   var key = ConnectionStringProtector.DeriveKeyFromSecret(request.Password); // SHA-256
   var encrypted = ConnectionStringProtector.EncryptWithKeyBytes(connectionString, key);
   CryptographicOperations.ZeroMemory(key);
   ```
   پاسخ: `{ user, encryptedConnectionString, database }` — hash رمز هرگز در
   پاسخ نیست.
3. endpoint: `no-store`، rate limit ثابت، سقف body ۸KB، و در production فقط
   HTTPS (`426 https_required`).

هیچ چیز server-side ذخیره نمی‌شود؛ نه نشست، نه توکن، نه لاگ شامل
credential/connection.

---

## ۳. سمت MAUI (`Tarazin.Maui/ApiConnectionSession.cs`)

پیکربندی اپ فقط این است (`Tarazin.Maui/appsettings.json`):

```json
{ "ServerEndpoint": "https://localhost:65220/" }
```

(در production می‌توان با متغیر محیطی `TARAZIN_SERVER_ENDPOINT` فقط همین نشانی
غیرمحرمانه را override کرد.)

بعد از ورود موفق:

1. کلید را از همان رمز تایپ‌شده مشتق می‌کند (`DeriveKeyFromSecret`)،
2. `DecryptWithKeyBytes(ENC:...)` → رشتهٔ اتصال،
3. با `SqlConnectionStringBuilder` اعتبارسنجی می‌کند و سیاست سرور را تحمیل
   می‌کند (`Encrypt=true`، `TrustServerCertificate=true`،
   `PersistSecurityInfo=false`)،
4. نتیجه فقط در RAM می‌ماند و `OpenConnectionAsync` از همان برای `DbService`
   و UI استفاده می‌کند؛ در خروج از حساب پاک می‌شود.

پیام‌های امن: رمز اشتباه → «نام کاربری یا رمز عبور صحیح نیست.»؛ قطع‌بودن API →
«سرویس ورود در دسترس نیست.»؛ خطای زیرساخت سرور → «سرویس اتصال موقتاً در دسترس
نیست.»؛ پاسخ خراب/رمزگشایی ناموفق → «پاسخ سرویس اتصال معتبر نیست.».

---

## ۴. چرا این مدل «بدون وابستگی اضافه» است

- **بدون کلید استاتیک در MAUI:** کلید از خود رمز ورود مشتق می‌شود؛ دیکامپایل
  بسته چیزی برای دیکریپت لو نمی‌دهد.
- **بدون state سرور:** نکتهٔ شکستِ زنجیرهٔ صدور/rotation/revoke وجود ندارد؛ اگر
  ورود وب کار می‌کند، ورود MAUI با همان دیتابیس و همان کاربر کار می‌کند.
- **تست ایستا سبز:** `security-regression-scan.py`، `cross-schema-scan.sh` و
  `sql-contract-scan.py` هر سه PASSED.
