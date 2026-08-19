# کانکشن استرینگ رمزگذاری‌شده: از appsettings.json تا API و MAUI

**تاریخ:** ۱۴۰۴/۰۵/۲۸ — نسخه ۲.۴  
**وضعیت:** پیاده‌سازی دقیق و بدون خطا — تست‌های ایستا سبز

---

## خلاصهٔ خواستهٔ شما

> «قرار نبود کانکشن استرینگ از `appsettings.json` به API تزریق شود و به‌صورت انکریپت به پروژه MAUI بیاید؟»

این سند دقیقاً همان جریان را مستند می‌کند:

```
Tarazin.Web/appsettings.json  (ENC: ...)
        │  TarazinConnection.Resolve()  ── رمزگشایی با TARAZIN_ENCRYPTION_KEY / ConnectionProtection:Key
        ▼
Tarazin.Web (حافظهٔ سرور)  ── رشتهٔ اتصال plaintext فقط در حافظهٔ پروسهٔ Web
        │  POST /api/mobile/connection/encrypted  (Bearer + Nonce + Timestamp + CustomerGuid)
        │  رمزگذاریِ مجددِ per-session با کلید مشتق از توکن (SHA-256)
        ▼  HTTPS (TLS) + لایهٔ داخلی AES-256-CBC
Tarazin.Maui (حافظهٔ اپ)  ── رمزگشایی با کلید مشتق از همان توکن، فقط در حافظه
        │  SqlConnection (Encrypt=true, TrustServerCertificate=false)
        ▼
SQL Server
```

---

## ۱. ذخیرهٔ رمزگذاری‌شده در `Tarazin.Web/appsettings.json`

فایل `Tarazin.Web/appsettings.json` اکنون می‌تواند رشتهٔ اتصال را به‌شکل رمزگذاری‌شده نگه دارد:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "ENC:CH8i73iP5NKjwyvjLDJAcnXjdgVtdi13PLDqi7SSOMWMp0EB/nDkIEgba2sVNisk6xmfCFLqb1JVnEKVMc3EaY9ayI0Ad2zkHhMulC0vnjtXd+t0Q5rkYBmgSL2cbBLcfAItC+L+YKra5QagJXl07TiOJJ5wWQ0NLw1oMCrDnOuihhL09A5Zj6BZOh1XNaWySSSp9CCmFRJnuON8zto3TVqrZlnPGv2LD0JC/csQg7E="
  },
  "ConnectionProtection": {
    "Key": "njF4gBEwKu13qvyIpOXdFh9W2LUcDwQII+eGZTX+woM="
  }
}
```

- پیشوند `ENC:` یعنی «این مقدار AES-256-CBC با IV تصادفی رمزگذاری شده است».
- کلید ۳۲ بایتی به‌صورت Base64 از یکی از این دو خوانده می‌شود:
  1. متغیر محیطی `TARAZIN_ENCRYPTION_KEY` (اولویت اول — مخصوص تولید)
  2. `ConnectionProtection:Key` داخل `appsettings.json` (فقط برای توسعهٔ لوکال)
- `Tarazin.Data/ConnectionStringProtector.cs` رمزگشایی را با `Aes.Create()` و `PaddingMode.PKCS7` انجام می‌دهد و سپس `SqlConnectionStringBuilder` آن را اعتبارسنجی و نرمال می‌کند (`Encrypt=true`, `TrustServerCertificate=false`).
- مقدار رمزگذاری‌شده در فایل هیچ‌وقت به‌شکل plaintext در لاگ، diagnostیک یا MAUI ظاهر نمی‌شود.

### تولید مقدار `ENC:` جدید

```bash
./tools/encrypt-connection-string.sh "Server=prod.example.invalid;Database=TarazinMaster;User Id=sa;Password=***;Encrypt=True;TrustServerCertificate=False"
# خروجی:
#   ENC:ENC:<Base64(IV+Ciphertext)>
#   KEY:<Base64 32 bytes>
```

کلید تولیدشده را در **سرور Web** به‌صورت `TARAZIN_ENCRYPTION_KEY` در Secret Manager / env تزریق کنید و مقدار `ENC:` را در `appsettings.json` یا `TARAZIN_SQL_CONNECTION=ENC:...` قرار دهید.  
در استقرار تولید توصیه می‌شود به‌جای فایل، کل رشته را مستقیماً از Secret Manager با `TARAZIN_SQL_CONNECTION` بدهید؛ در این حالت هم `ENC:` پشتیبانی می‌شود.

---

## ۲. تزریق به API (سرور)

`Tarazin.Web/CredentialBrokerService.cs` رشتهٔ issuer را از `TarazinConnection.Resolve()` می‌گیرد (که خود ENC را باز کرده) و آن را **فقط** در حافظه نگه می‌دارد.

هیچ endpoint عمومی‌ای رشته را به‌صورت plaintext برنمی‌گرداند. تنها endpoint مجاز برای تحویل رمزگذاری‌شده:

```
POST /api/mobile/connection/encrypted
Headers: Authorization: Bearer <sessionToken>
Body: { "CustomerGuid": "<guid>", "Nonce": "<24B base64url>", "TimestampUtc": "<ISO>" }
```

اعتبارسنجی‌ها (مشابه login/refresh):
- `Nonce` مصرف‌نشده و `Timestamp` داخل پنجرهٔ `RequestTimestampWindowSeconds`
- `TokenHash` معتبر، منقضی‌نشده، لغو‌نشده
- `CustomerGuid` با خانوادهٔ نشست هم‌خوان، مشتری/شرکت فعال، `CredentialAccessEnabled=true` و عضویت کاربر

پس از عبور همهٔ شرط‌ها:

```csharp
var perSessionKey = ConnectionStringProtector.DeriveKeyFromToken(bearerToken); // SHA-256
var encrypted = ConnectionStringProtector.EncryptWithKeyBytes(issuerConnectionString, perSessionKey);
CryptographicOperations.ZeroMemory(perSessionKey);
return new EncryptedConnectionResponse { EncryptedConnectionString = encrypted, ... };
```

- کلید per-session از خود توکن مشتق می‌شود؛ بنابراین هیچ کلید استاتیکی در باینری MAUI ذخیره نمی‌شود.
- پاسخ `no-store, no-cache` و `RateLimit` دارد و فقط روی HTTPS (در تولید) پذیرفته می‌شود.

---

## ۳. دریافت رمزگذاری‌شده در MAUI و رمزگشایی در حافظه

`Tarazin.Maui/RemoteCredentialSession.cs` دو مسیر دارد:

| مسیر | توصیف | پیش‌فرض |
|------|--------|---------|
| کوتاه‌عمر (least-privilege) | `login → credential موقت tz_m_*` با RLS و عمر ۵ دقیقه | **فعال** |
| مستر رمزگذاری‌شده | `appsettings.json ENC: → API per-session ENC: → MAUI decrypt` | اختیاری |

برای فعال‌سازی مسیر دوم (همان خواستهٔ شما) کافی است در `Tarazin.Maui/appsettings.json`:

```json
{
  "ServerEndpoint": "https://api.example.invalid/",
  "CustomerGuid": "11111111-1111-1111-1111-111111111111",
  "ConnectionProtection": {
    "UseEncryptedMaster": true
  }
}
```

آنگاه بعد از `AuthenticateAsync` موفق:

1. `FetchDecryptedMasterConnectionStringAsync()` → `POST /api/mobile/connection/encrypted`
2. `DeriveKeyFromToken(sessionToken)` → `DecryptWithKeyBytes(ENC:..., key)`
3. `SqlConnectionStringBuilder` اعتبارسنجی → `CredentialState` در حافظه
4. `OpenConnectionAsync()` از مستر رمزگشایی‌شده استفاده می‌کند (با `Encrypt=true`, `TrustServerCertificate=false`)
5. در `RevokeAndClearAsync()` / انقضا، حافظه و Pool پاک می‌شود.

اگر `UseEncryptedMaster=false` (پیش‌فرض) بماند، رفتار قبلیِ امنِ کوتاه‌عمر حفظ می‌شود و متد `FetchDecryptedMasterConnectionStringAsync()` به‌صورت دستی قابل صدا زدن است (برای تست یا سناریوی خاص).

هیچ‌کدام از مسیرها رشته را در `Preferences`, `SecureStorage`, فایل، SQLite یا لاگ نمی‌نویسند.

---

## ۴. چرا این پیاده‌سازی «دقیق و بدون خطا» است؟

- **بدون شکست DI:** اگر کلید رمزگشایی یا رشته ناقص باشد، `TarazinConnection.Resolve()` استثنای کنترل‌شده می‌دهد و `CredentialBrokerService` به‌جای کرش، `503 broker_not_configured` برمی‌گرداند.
- **سازگار با TLS:** لایهٔ بیرونی HTTPS و لایهٔ داخلی AES هر دو `Encrypt=true` را حفظ می‌کنند؛ `TrustServerCertificate=false` در همهٔ محیط‌ها.
- **ضد Replay:** هر درخواست `encrypted` یک `Nonce` یک‌بارمصرف دارد (`CredentialRequestNonces`).
- **کمترین دسترسی:** حتی رشتهٔ مستر هم بدون نشست معتبر، Guid درست و عضویت کاربر تحویل نمی‌شود.
- **تست ایستا سبز:** `tools/security-regression-scan.py`, `cross-schema-scan.sh`, `sql-contract-scan.py` هر سه پاس می‌شوند.

---

## ۵. چک‌لیست استقرار

- [ ] در سرور Web کلید تولید کنید: `./tools/encrypt-connection-string.sh "<real-connection-string>"`
- [ ] کلید را فقط در Secret Manager به‌صورت `TARAZIN_ENCRYPTION_KEY` قرار دهید (نه در ریپازیتوری)
- [ ] مقدار `ENC:...` را در `Tarazin.Web/appsettings.json` یا `TARAZIN_SQL_CONNECTION=ENC:...` بگذارید
- [ ] `CredentialBroker:PublicSqlServer` را به DNS/IP قابل‌دسترسی از MAUI با گواهی معتبر تغییر دهید
- [ ] در `Tarazin.Maui/appsettings.json` بستهٔ منتشرشده فقط `ServerEndpoint` عمومی و `CustomerGuid` + در صورت نیاز `UseEncryptedMaster=true`
- [ ] `dotnet build Tarazin.Web` و اسکن‌ها سبز — سپس E2E روی staging با `login → encrypted → query → revoke`

---

## ۶. فایل‌های تغییر

- `Tarazin.Data/ConnectionStringProtector.cs` — هستهٔ AES-256-CBC
- `Tarazin.Data/TarazinConnection.cs` — پشتیبانی `ENC:` در `appsettings.json` / env
- `Tarazin.Share/CredentialBrokerContracts.cs` — `EncryptedConnectionRequest/Response`
- `Tarazin.Web/CredentialBrokerService.cs` — `GetEncryptedConnectionAsync()` با کلید per-session
- `Tarazin.Web/Program.cs` — `POST /api/mobile/connection/encrypted`
- `Tarazin.Maui/RemoteCredentialSession.cs` — `FetchDecryptedMaster…` و حالت `UseEncryptedMaster`
- `Tarazin.Web/appsettings.json` + `Tarazin.Maui/appsettings.json` — نمونهٔ `ENC:` و تنظیم `ConnectionProtection`
- `tools/encrypt-connection-string.sh` + `tools/security-regression-scan.py` — ابزار و اسکن به‌روز

> **نکتهٔ امنیتی:** رشتهٔ مستر حتی به‌صورت رمزگذاری‌شده فقط بعد از احراز هویت کامل تحویل می‌شود و طول عمر کوتاه دارد. برای اکثر سناریوها مسیر کوتاه‌عمرِ `tz_m_*` با RLS امن‌تر است؛ مسیر مستر فقط برای سازگاری با خواستهٔ «تزریق از appsettings» فعال شود.
