# کانکشن استرینگ رمزگذاری‌شده: از appsettings.json تا API و MAUI

**تاریخ:** ۱۴۰۴/۰۵/۲۸ — نسخه ۲.۵ (درست مطابق درخواست: plain در Web، رمزگذاری فقط هنگام ارسال API)  
**وضعیت:** پیاده‌سازی دقیق و بدون خطا — تست‌های ایستا سبز

---

## خواستهٔ نهایی شما

> «نمی‌خوام کانکشن استرینگ داخل پروژه وب در appjson انکریپت بشه، اونجا باید درست باشه، موقع ارسال api انکریپت بشه و بعد از دریافت دیکریپت بشه و به ui ارسال بشه»

یعنی:

```
Tarazin.Web/appsettings.json  ── رشته درست و plain (بدون ENC:)
        │  TarazinConnection.Resolve()  (بدون رمزگشایی، فقط اعتبارسنجی)
        ▼
Tarazin.Web (حافظهٔ سرور)  ── plaintext فقط در RAM سرور
        │  POST /api/mobile/connection/encrypted
        │  **اینجا** رمزگذاری per-session با کلید مشتق از Bearer Token (SHA-256 → AES-256-CBC)
        ▼  HTTPS (TLS) + لایهٔ داخلی ENC:Base64(IV+Ciphertext)
Tarazin.Maui (حافظهٔ اپ)  ── رمزگشایی با همان کلید مشتق از توکن، فقط در RAM
        │  سپس ارسال به UI (DbService / SqlConnection)
        ▼
UI / SqlConnection (Encrypt=true, TrustServerCertificate=false) → SQL Server
```

**نکته:** پشتیبانی از `ENC:` برای حالت at-rest همچنان در کد باقی است (برای کسانی که بخواهند فایل را هم رمزگذاری کنند)، اما پیش‌فرض فعلی دقیقاً مطابق درخواست شما **plain در فایل Web** است.

---

## ۱. ذخیرهٔ درست در `Tarazin.Web/appsettings.json` (بدون رمزگذاری)

فایل `Tarazin.Web/appsettings.json` اکنون **plain و درست** است:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=example.invalid;Database=TarazinMaster;User Id=sa;Password=changeme;Encrypt=True;TrustServerCertificate=False;Application Name=Tarazin"
  }
}
```

- هیچ پیشوند `ENC:` در فایل Web نیست — رشته همان است که SQL Server می‌فهمد.
- در تولید، به‌جای فایل می‌توانید همان رشته را از Secret Manager با متغیر محیطی `TARAZIN_SQL_CONNECTION` تزریق کنید؛ `TarazinConnection.Resolve()` اول env را می‌خواند، سپس فایل.
- اگر زمانی بخواهید فایل را هم رمزگذاری کنید، کافی است مقدار را با `./tools/encrypt-connection-string.sh` به `ENC:...` تبدیل و کلید را در `TARAZIN_ENCRYPTION_KEY` بگذارید — کد هر دو حالت plain و ENC را می‌فهمد.

---

## ۲. تزریق به API — رمزگذاری **فقط هنگام ارسال**

`Tarazin.Web/CredentialBrokerService.cs` رشته issuer را به‌صورت plain از `TarazinConnection.Resolve()` می‌گیرد و **فقط هنگام پاسخ به MAUI** آن را رمز می‌کند:

```csharp
var perSessionKey = ConnectionStringProtector.DeriveKeyFromToken(bearerToken); // SHA-256(token)
var encrypted = ConnectionStringProtector.EncryptWithKeyBytes(issuerConnectionString, perSessionKey);
// encrypted = "ENC:" + Base64(IV + AES-CBC ciphertext)
CryptographicOperations.ZeroMemory(perSessionKey);
return new EncryptedConnectionResponse { EncryptedConnectionString = encrypted, ... };
```

- کلید per-session از خود Bearer Token مشتق می‌شود؛ هیچ کلید استاتیکی در باینری MAUI ذخیره نمی‌شود.
- endpoint مجاز:
  ```
  POST /api/mobile/connection/encrypted
  Headers: Authorization: Bearer <sessionToken>
  Body: { "CustomerGuid": "...", "Nonce": "...", "TimestampUtc": "..." }
  ```
  اعتبارسنجی‌ها: Nonce یکبارمصرف، Timestamp داخل پنجره، TokenHash معتبر/لغو نشده، CustomerGuid هم‌خوان، مشتری/شرکت فعال و عضویت کاربر.
- پاسخ `no-store, no-cache` و `RateLimit` دارد و در تولید فقط روی HTTPS پذیرفته می‌شود. هیچ endpoint دیگری رشته را plaintext برنمی‌گرداند.

---

## ۳. دریافت در MAUI — دیکریپت و ارسال به UI

`Tarazin.Maui/RemoteCredentialSession.cs`:

| مسیر | توصیف | پیش‌فرض |
|------|--------|---------|
| کوتاه‌عمر (least-privilege) | `login → credential موقت tz_m_*` با RLS | حذف‌شده از مسیر SQL (فقط دفترچهٔ نشست) |
| مستر رمزگذاری‌شده (قانون پروژه) | `appsettings.json plain → API per-session ENC: → MAUI decrypt → UI` | **تنها مسیر (پیش‌فرض و اجباری)** |

مسیر مستر (قانون و پیش‌فرض پروژه) در `Tarazin.Maui/appsettings.json`:

```json
{
  "ServerEndpoint": "https://api.example.invalid/",
  "CustomerGuid": "11111111-1111-1111-1111-111111111111",
  "ConnectionProtection": { "UseEncryptedMaster": true }
}
```

آنگاه بعد از `AuthenticateAsync` موفق:

1. `FetchDecryptedMasterConnectionStringAsync()` → `POST /api/mobile/connection/encrypted`
2. `DeriveKeyFromToken(sessionToken)` → `DecryptWithKeyBytes(ENC:..., key)` → `plaintext`
3. `SqlConnectionStringBuilder` اعتبارسنجی → `CredentialState` فقط در RAM
4. `OpenConnectionAsync()` آن را با `Encrypt=true, TrustServerCertificate=false` به `DbService` و سپس به UI می‌دهد
5. در `RevokeAndClearAsync()` یا انقضا، RAM و Pool پاک می‌شود

`UseEncryptedMaster=false` مجاز نیست و `RemoteCredentialSession` در استارتاپ با خطا رد می‌شود (قانون پروژه: رشتهٔ اتصال فقط از API و فقط رمزگذاری‌شده).

```csharp
var plain = await credentialSession.FetchDecryptedMasterConnectionStringAsync();
// plain را فقط در حافظه به UI بدهید، هرگز لاگ/فایل نکنید
```

هیچ مسیری رشته را در `Preferences`, `SecureStorage`, فایل یا لاگ نمی‌نویسد.

---

## ۴. چرا این پیاده‌سازی دقیق و بدون خطا است؟

- **فایل Web درست و plain:** `appsettings.json` مقدار واقعی connection string را به‌صورت plain دارد؛ `TarazinConnection` آن را بدون رمزگشایی می‌خواند.
- **رمزگذاری فقط در API:** رشته فقط هنگام پاسخ `encrypted` با AES-256-CBC رمز می‌شود؛ بیرون از آن هیچ‌وقت رمزگذاری/رمزگشایی اضافی در فایل نیست.
- **بدون کلید استاتیک در MAUI:** کلید از خود توکن جلسه مشتق می‌شود، پس دیکامپایل APK چیزی لو نمی‌دهد.
- **ضد Replay و معتبرسازی کامل:** Nonce، Timestamp، خانوادهٔ نشست، وضعیت مشتری/شرکت و عضویت همگی چک می‌شوند.
- **تست ایستا سبز:** `security-regression-scan.py` (با استثنای مجاز plain localhost در Web)، `cross-schema-scan.sh` و `sql-contract-scan.py` هر سه PASSED.

---

## ۵. چک‌لیست استقرار

- [ ] `Tarazin.Web/appsettings.json` را با رشته درست plain برای dev پر کنید (یا در تولید فقط `TARAZIN_SQL_CONNECTION` را از Secret Manager تزریق کنید)
- [ ] `CredentialBroker:PublicSqlServer` را به DNS/IP قابل‌دسترسی از MAUI با گواهی SQL معتبر تغییر دهید
- [ ] `Tarazin.Maui/appsettings.json` را فقط با `ServerEndpoint` و `CustomerGuid` و `UseEncryptedMaster:true` (الزامی) بسته‌بندی کنید
- [ ] `dotnet build Tarazin.Web` و اسکن‌ها سبز — سپس E2E: `login → FetchDecryptedMaster → query → revoke`

---

## ۶. فایل‌های تغییر (نسخه ۲.۵)

- `Tarazin.Data/ConnectionStringProtector.cs` — هستهٔ AES (برای رمزگذاریِ API)
- `Tarazin.Data/TarazinConnection.cs` — پشتیبانی plain و همچنین ENC: (اختیاری)
- `Tarazin.Share/CredentialBrokerContracts.cs` — `EncryptedConnectionRequest/Response`
- `Tarazin.Web/CredentialBrokerService.cs` — `GetEncryptedConnectionAsync()` با کلید per-session
- `Tarazin.Web/Program.cs` — `POST /api/mobile/connection/encrypted`
- `Tarazin.Maui/RemoteCredentialSession.cs` — `FetchDecryptedMaster…` و `UseEncryptedMaster`
- `Tarazin.Web/appsettings.json` — **plain (درست)**، بدون ENC: طبق درخواست
- `Tarazin.Maui/appsettings.json` — `UseEncryptedMaster: true` (اجباری — تنها مسیر)
- `tools/security-regression-scan.py` — اجازهٔ plain localhost در Web
