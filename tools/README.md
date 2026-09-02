# ابزارهای تست و دادهٔ نمونه (tools/)

این پوشه شامل اسکریپت‌های کمکی برای توسعهٔ ترازین است. مهم‌ترین آن‌ها:

| اسکریپت | کاربرد |
|---------|--------|
| `seed-demo-data.sh` | **دادهٔ نمونه با یک دستور** — انبار، خزانه، چک و فاکتور طلا (این صفحه را ببینید) |
| `run-checks.sh` | گیت کامل: اسکن cross-schema + تست‌ها + بیلد + گارد stale + بازنویسی گزارش تست |
| `check-stale-build.sh` | گارد «سرور با کد قدیمی» — قبل از ریاستارت dev server اجرا کنید |
| `cross-schema-scan.sh` | اسکن وابستگی‌های بین اسکیم‌ها در `Tarazin.Data/Scripts` |
| `refresh-test-report.sh` | بازنویسی بخش خودکارِ `docs/testing-report.md` از خروجی واقعی تست — نیازمند خلاصهٔ `dotnet test` به‌عنوان `$1` |
| `fix-hossein-company-access.sql` | تعمیر یک‌بارهٔ دسترسی کاربر به شرکت فعال (برای این دیتابیس dev) |
| `start-dev-server.sh` | **راه‌اندازی سرور dev با ریاستارت خودکار** — `dotnet watch` + supervisor (این صفحه را ببینید) |
| `dev-server-watch.sh` | supervisor سرور dev — crash-heal و تک‌نمونه (توسط `start-dev-server.sh` اجرا می‌شود) |
| `check-server.sh` | بررسی سلامت سرور از `GET /api/health` — وضعیت/آپتایم/نسخه روی صفحه + گزارش به تلگرام (اختیاری) |
| `check-stale-build.ps1` | نسخهٔ Windows-native گارد build کهنه (معادل `check-stale-build.sh`) |
| `check-rtl-headers.sh` | تأیید هدر RTL روی PDFهای واقعی (لوگوی سمت راست‌ترین با pymupdf) — مکمل گارد xUnit |
| `compare-designer-downloads.sh` | مقایسهٔ لایوِ خروجی دیزاینر چاپ با بایت‌های مرجع `sha256.txt` تست‌ها |
| `preview-publish.sh` | انتشار هاست وب در مسیر بیرون از مخزن برای «سرور پیش‌نمایش» — جلوی قفل DLL بیلد |
| `fix-double-utf8.ps1` | تعمیر داده‌های با کدگذاری دوبل UTF-8 (cp1256→UTF-8 وارون) — `-Apply` برای اعمال |
| `telegram_bridge.py` | پل قدیمی تلگرام (inbox/send.json) — **جایگزین‌شده توسط `telegram_agent.py`** |
| `test_modules.py` | پیمایش ماژول‌ها، OCR هر صفحه و گرفتن اسکرین‌شات — تست UI از طریق MCP ویندوز |
| `windows_mcp_client.py` | کلاینت Streamable HTTP بدون وابستگی برای MCP صفحه‌نمایش ویندوز (مبنای ابزارهای اسکرین‌شات) |
| `nav.py` / `capture_to_file.py` / `ocr_text.py` / `fill_step.py` / `png_boxes.py` / `png_teal_scan.py` | کمکی‌های تست UI: ناوبری با هاتکی، اسکرین‌شات به فایل، OCR متن، پرکردن خودکار فرم‌ها، جعبه‌یابی/اسکن رنگ در PNG |

---

## 🖥 سرور dev با ریاستارت خودکار — `start-dev-server.sh` + `dev-server-watch.sh`

### چرا این ابزار؟

سرور dev قبلاً با `dotnet run --no-build` بالا می‌آمد و بعد از هر تغییر کد،
دستی باید ریاستارت می‌شد تا صفحهٔ جدید دیده شود. این دو اسکریپت آن را
خودکار می‌کنند:

- تغییر `.razor` (صفحه‌ها) → **هات‌ریلود فوری در ~۳ ثانیه، بدون ریاستارت**.
- تغییر `.cs` → هات‌ریلود یا توقف → build → ریاستارت خودکار.
- اگر `dotnet watch` بمیرد → supervisor دوباره بالا می‌آورد (crash-heal).

### چرا watchdog «رصد خروجی build» جواب نمی‌دهد؟

در ویندوز، فرایند در حال اجرا فایل‌های `Tarazin.Web.exe`/dll را **قفل** می‌کند —
`dotnet build` در حالی که سرور بالاست با خطای MSB3021 شکست می‌خورد. پس منتظر
ماندن برای build و ریاستارت بعد از آن غیرممکن است (build اصلاً تمام نمی‌شود).
راه درست: خودِ `dotnet watch` (بعد از توقف فرایند) rebuild می‌کند و ریاستارت
می‌شود — supervisor فقط آن را زنده نگه می‌دارد.

### اجرا و توقف

```bash
# راه‌اندازی (یا ری‌هیل اگر پایین است — idempotent)
bash tools/start-dev-server.sh

# ریاستارت کامل حتی اگر سالم باشد (بعد از تغییر Program.cs لازم است)
bash tools/start-dev-server.sh --force

# توقف فقط watch (سرویس وب را می‌کشد)
bash tools/dev-server-watch.sh --stop
```

### سنجش سلامت

هر دو اسکریپت سلامت را از endpoint اختصاصی `GET /api/health` می‌سنجند
(نه هر ۲۰۰ دلخواه) — فقط وقتی پاسخ `"status":"ok"` داشته باشد، سالم
محسوب می‌شود. این endpoint آپتایم واقعی فرایند + نسخهٔ build را هم
برمی‌گرداند:

```bash
curl -sk https://localhost:65220/api/health
# {"status":"ok","uptimeSeconds":64,"buildVersion":"1.0.0+...","buildTime":"...","environment":"Development","timestamp":"..."}
```

### رفتارها و نکته‌ها

| نکته | توضیح |
|------|--------|
| `start-dev-server.sh` بدون آرگومان | idempotent — اگر سرور سالم و supervisor زنده باشد فقط «nothing to do» و خروج (برای اجرای ۵ دقیقه‌ای Task Scheduler ضروری است) |
| `--force` | همیشه supervisorهای قدیمی و سرور قبلی را می‌کشد و از نو می‌سازد |
| `--stop` | فقط `dotnet watch` را می‌کشد (سرویس وب را هم — چون فرزند watch است) |
| تک‌نمونهٔ supervisor | از طریق pidfile (`/tmp/dev-server-watch.pid`)؛ نمونهٔ جدید اگر قبلی زنده باشد خارج می‌شود |
| ⚠️ route جدید در `Program.cs` | **هات‌ریلود آن را فعال نمی‌کند** — بعد از افزودن route/endpoint جدید، `start-dev-server.sh --force` بزنید |
| ⚠️ build دستی | در حالی که این سرور بالاست `dotnet build Tarazin.Web` نزنید (خطای قفل DLL) — کافی است `dotnet build Tarazin.Ui` بزنید؛ watch بقیه را خودش انجام می‌دهد |

### لاگ‌ها

| فایل | محتوا |
|------|--------|
| `/tmp/tarazin-watch.log` | خروجی کامل سرور + پیام‌های `dotnet watch` (هات‌ریلود/ریاستارت) |
| `/tmp/dev-server-watch.log` | وقایع supervisor (شروع/ری‌هیل/خروج تک‌نمونه) |

### Task Scheduler (`Tarazin\DevServer`)

بعد از ریاستارت ویندوز، این وظیفه سرور را خودکار بالا می‌آورد:

- **ورود ویندوز** → اجرای `start-dev-server.sh` (~۴۵ ثانیه تا بالا آمدن کامل).
- **هر ۵ دقیقه** → re-heal: فقط اگر سرور پایین است دوباره بالا می‌آورد
  (به‌خاطر idempotency، اجرای دوره‌ای ضرری ندارد).

قالب برای بازسازی مجدد: `tools/tarazin-devserver-task.xml`؛
لاگ اجرای task: `/tmp/tarazin-task.log`.

---

## 🤖 ربات تلگرام — `telegram_agent.py` + Task Scheduler

### این دیمن چیست؟

`tools/telegram_agent.py` یک **صف تسک محلی** برای فضای کاری Freebuff است — عمداً
هیچ LLM/شل/کد مخزن را اجرا نمی‌کند. فقط: پیام‌های مجاز تلگرام را دریافت می‌کند،
از آن‌ها رکورد Todo ماندگار می‌سازد و وضعیت صف/تأیید را تلگرام گزارش می‌دهد.
اجرای کارها همیشه توسط نشست فعال Freebuff انجام می‌شود (نه دیمن).

### فایل‌های مهم

| فایل | نقش |
|------|-----|
| `tools/telegram_agent.py` | دیمن اصلی — ترنسپورت دوگانه (webhook یا long-poll)، صف `queue.jsonl`، outbox با اولویت و backoff، `status.json` |
| `tools/start_telegram_agent.py` | نقطهٔ ورود Task Scheduler — idempotent (اگر agent زنده است فقط «nothing to do») |
| `tools/telegram_send.py` | ارسال یک‌بارهٔ پیام/گزارش به تلگرام (`--priority high` برای اولویت، `--help` برای راهنما) |
| `tools/telegram_queue.py` | کار با صف از خط فرمان (`list`/`next`/`has-notify`/`claim-next`/`claim`/`complete`/`fail`) |
| `tools/test_telegram_agent.py` | تست خودکار دیمن (۵۶ مورد — بدون شبکهٔ واقعی و بدون دست زدن به state واقعی) |
| `tools/telegram_agent_task.xml` | قالب وظیفهٔ Task Scheduler برای بازسازی مجدد |
| `tools/telegram_autopilot.py` | پل هر دقیقه: Taskهای `ready` صف تلگرام → `queue_items` ترد executor در Freebuff تا دکمهها بدون دخالت اجرا شوند (یکشات، idempotent) |
| `tools/telegram_autopilot_task.xml` | وظیفهی Task Scheduler `Tarazin\TelegramAutopilot` — هر ۱ دقیقه |

### Task Scheduler (`Tarazin\TelegramAgent`)

| تریگر | رفتار |
|-------|-------|
| **ورود ویندوز (LogonTrigger)** | اجرای `start_telegram_agent.py` → یک نمونهٔ detached از دیمن بالا می‌آید |
| **هر ۵ دقیقه (TimeTrigger)** | re-heal: فقط اگر دیمن مرده باشد دوباره راه می‌اندازد |

idempotency دو لایه دارد — اجرای ۵ دقیقه‌ای هیچ ضرری ندارد:
1. `start_telegram_agent.py`: اگر `~/.telegram-bridge/bridge.lock` به یک PID زنده
   اشاره کند، فوراً خارج می‌شود.
2. خودِ دیمن: قفل تک‌نمونه دارد — نمونه‌های هم‌زمان با خروج تمیز رد می‌شوند
   (بدون خطای 409 تلگرام).

بازسازی مجدد وظیفه (در صورت نیاز):

```bash
schtasks //create //tn "Tarazin\TelegramAgent" //xml "$(pwd -W)/tools/telegram_agent_task.xml" //f

### خودکارسازی اجرا: `Tarazin\TelegramAutopilot` (هر ۱ دقیقه)

دکمههای تلگرام Task `ready` در `queue.jsonl` میسازند، ولی Freebuff فقط صف خودش
(`queue_items` در `desktop-v2.db`) را اجرا میکند — نه `queue.jsonl` را. این پل دو
صف را به هم وصل میکند:

1. هر دقیقه `tools/telegram_autopilot.py` (Task Scheduler) چک میکند آیا Task `ready` وجود دارد.
2. اگر هست و دستور auto-run مشابهی هنوز در صف ترد executor **در انتظار/در حال اجرا** نباشد
   (dedupe با `skill_name=telegram-autopilot`)، یک `queue_items` با دستور
   «claim-next → اجرا → complete → گزارش تلگرام» به ترد فعال تزریق میکند.
3. اپ Freebuff آن را مثل هر تِرن خودکار اجرا میکند (مکانیزم اثباتشده — همین گفتگو با queue item شروع شده بود)
   و نشست executor صف تلگرام را خالی میکند.

- ترد هدف: `TELEGRAM_AUTOPILOT_THREAD_ID` یا خودکار (state در `~/.telegram-bridge/agent/autopilot-thread` ذخیره میشود).
  پیشفرض، ترد executor گفتگوهای زیرساخت تلگرام است.
- بدون دخالت دستی کار میکند؛ `claim`/`complete` هنوز اتمیک و توسط نشست Freebuff انجام میشود
  (reseed و تستهای خودکار همانجا صدا زده میشوند).
- بازسازی وظیفه در صورت نیاز:
```bash
schtasks //create //tn "Tarazin\TelegramAutopilot" //xml "$(pwd -W)/tools/telegram_autopilot_task.xml" //f
```

```

### وضعیت و سلامت

دیمن وضعیت کامل خود را در `~/.telegram-bridge/agent/status.json` می‌نویسد
(۱۵+ فیلد: mode/transport/proxy, webhook_url/webhook_registered، خطاهای پشت‌سرهم، outbox معوق، آخرین خطا/موفقیت،
آپتایم، pid...). نمای زندهٔ آن در برنامه: **مرکزی > سلامت ربات تلگرام**
(صفحهٔ «TelegramBotHealth» — هر ۳۰ ثانیه خودکار + نمودار روند ۲۴h/۷d/۳۰d).

### نحوهـ دریافت آپدیت: webhook یا long-poll

دیمن دو ترنسپورت دارد و انتخاب با `TELEGRAM_TRANSPORT` در `.telegram-agent.env` انجام می‌شود (پیش‌فرض `auto`):

| مقدار | رفتار |
|-------|-------|
| `auto` (پیش‌فرض) | اگر `TELEGRAM_WEBHOOK_URL` ست شده باشد webhook، وگرنه long-poll |
| `poll` | getUpdates با offset — fallback پایدار؛ از طریق پروکسی |
| `webhook` | setWebhook + گیرندهـ محلی — آپدیت‌ها فوری، بدون 409 |

کلیدهای وب‌هوک (در همان `.telegram-agent.env`):

| کلید | نقش |
|------|-----|
| `TELEGRAM_WEBHOOK_URL` | آدرس HTTPS عمومی که تلگرام به آن پست می‌کند (مثلاً تونل به این ماشین) |
| `TELEGRAM_WEBHOOK_SECRET` | secret_token — اگر خالی باشد خودکار ساخته و در config ذخیره می‌شود |
| `TELEGRAM_WEBHOOK_LISTEN` | پورت محلی گیرنده (پیش‌فرض `127.0.0.1:8443`) |

نکته‌ها:
- وب‌هوک **فقط با URL عمومی HTTPS** کار می‌کند؛ روی localhost بدون تونل بی‌اثر است، پس `auto` همان long-poll را نگه می‌دارد (پروکسی حفظ می‌شود).
- هنگام شروع `poll`، اگر webhook کهنه ثبت شده باشد خودکار حذف می‌شود تا getUpdates با 409 روبه‌رو نشود؛ و هنگام شروع `webhook`، خودش `setWebhook` می‌زند.
- تغییر `TELEGRAM_PROXY`/`TELEGRAM_TRANSPORT`/`TELEGRAM_WEBHOOK_URL` در فایل → ری‌استارت خودکار (مانند قبل).
- ارسال پیام (outbox) در هر دو حالت یکسان است: با پروکسی و backoff.

```bash
# وضعیت فوری از خط فرمان
cat ~/.telegram-bridge/agent/status.json

# صف فعلی (تسک‌های منتظر تأیید)
PYTHONIOENCODING=utf-8 python tools/telegram_queue.py list

# کامل‌کردن تسک → به‌صورت خودکار seed-demo-data.sh --reseed اجرا می‌شود
PYTHONIOENCODING=utf-8 python tools/telegram_queue.py complete T-XXXX "خلاصه"
# اگر دلیلی برای عدم reseed بود:
PYTHONIOENCODING=utf-8 python tools/telegram_queue.py complete T-XXXX "خلاصه" --no-reseed
# تست‌های خودکار انبار را هم خاموش کن (پیش‌فرض روشن):
PYTHONIOENCODING=utf-8 python tools/telegram_queue.py complete T-XXXX "خلاصه" --no-tests
```

> **رفع باگ**: دستور `claim` قبلاً تغییر را در دیسک ذخیره نمی‌کرد (هر حکم بعدی
> دوباره تسک را `ready` نشان می‌داد). اکنون `claim`، `complete` و `fail` همه
> امن اتمی ذخیره می‌شوند.

### reseed خودکار بعد از هر تسک

دستور `complete` در `telegram_queue.py` بعد از ثبت تسک، به‌صورت خودکار
`seed-demo-data.sh --reseed` را اجرا می‌کند تا دادهٔ نمونه همیشه بعد از هر
مرحله تازه بماند (قانون دائمی). ویژگی‌ها:
- **غیر-کشنده**: شکست reseed (مثلاً SQL Server در دسترس نباشد) هرگز تسک را
  fail نمی‌کند؛ نتیجه در `~/.telegram-bridge/agent/reseed.log` ثبت می‌شود.
- **هشدار به تلگرام هنگام شکست**: اگر reseed ناموفق باشد، یک پیام
  `priority=high` با rc و آخرین خطوط خروجی به تلگرام فرستاده می‌شود تا خطا
  دیده و رفع شود.
- خروجی آخرین اجرا همان‌جا دیده می‌شود: `tail -5 ~/.telegram-bridge/agent/reseed.log`
- خاموش‌کردن موردی: `--no-reseed`

### تست خودکار انبار بعد از هر تسک

علاوه بر reseed، `complete` حالا تست‌های انبار را هم اجرا می‌کند
(قانون دائمی — تابع `run_auto_inventory_tests`):
- **هر کلاس جداگانه** اجرا می‌شود (اجرای ترکیبی به دلیل DB مشترک زنده با
  هم‌زمانی xUnit تایم‌اوت می‌شود — مشکل شناخته‌شده) + **retry یک‌بار** برای
  نوسان contention بیرونی (مثل dev server در حال اجرا).
- نتیجه در `~/.telegram-bridge/agent/tests.log` ثبت می‌شود؛ شکستِ علّی واقعی
  → هشدار `priority=high` به تلگرام.
- کلاس‌ها: `InventoryPhase5Tests`, `InventoryMovementInsertTests`,
  `InventoryAdjustmentTests`, `LotSerialTests`, `ItemPickerDbTests`,
  `SeedCleanupTests`, `GoldItemLinkTests` (۲۲ تست).
- خاموش‌کردن موردی: `--no-tests`

### نکته‌ها

| نکته | توضیح |
|------|--------|
| ⚠️ مسیر شبکه | اگر با پروکسی به تلگرام وصل است، تغییر `TELEGRAM_PROXY` در `.telegram-agent.env` با ریاستارت خودکار دیمن همراه است (watcher داخل دیمن) |
| اتصال ناپایدار | outbox پایدار است — پیام‌های معوق با backoff تحویل می‌شوند؛ تأییدها/پاسخ دکمه‌ها (priority=high) قبل از گزارش‌های عادی می‌روند |
| هشدارها | خطاهای پشت‌سرهم ≥۵ یا صف ارسال >۱۰ → هشدار جداگانه به تلگرام؛ سقف سخت صف ۵۰ |
| توقف دستی | فایل `~/.telegram-bridge/agent/agent.stop` را بسازید تا دیمن خودش متوقف شود |

---

## 🧪 دادهٔ نمونه با یک دستور — `seed-demo-data.sh`

### چرا این ابزار؟

صفحه‌های خانهٔ انبار/خزانه/طلافروشی فیلتر پیش‌فرض «۳۰ روز اخیر» دارند؛ اگر دیتابیس
حرکتی در این بازه نداشته باشد، جدول‌ها خالی می‌مانند و تست UI/گزارش‌ها سخت می‌شود.
این اسکریپت دادهٔ واقعی امروز را از **همان اسکریپت‌های تولیدی پروژه** وارد می‌کند
(نه INSERT دستی) تا مسیر تولید دقیقاً تمرین شود.

### پیش‌نیازها

- **SQL Server** در دسترس (محلی یا از طریق `TARAZIN_TEST_CONN`).
- **`sqlcmd`** در PATH یا در مسیرهای استاندارد SQL Server Tools.
- دیتابیس از قبل ساخته/بروز شده باشد (`_Ensure`ها اجرا شده باشند).
- شرکت هدف و سال مالی فعال آن در دیتابیس وجود داشته باشد.

### اجرا

```bash
# پیش‌فرض: شرکت ۳ (شرکت فعال دمو) + سال مالی ۴ (۱۴۰۵)
bash tools/seed-demo-data.sh

# اگر قبلاً اجرا شده و می‌خواهید پاک+نو کنید (idempotent — بدون ردیف تکراری)
bash tools/seed-demo-data.sh --reseed

# صرفاً نادیده‌گرفتن گارد و تکرار (تکرار = ردیف تکراری؛ کمتر توصیه می‌شود)
bash tools/seed-demo-data.sh --force

# شرکت/سال دیگر
bash tools/seed-demo-data.sh --company 6 --fiscal-year 12

# اتصال از طریق کانکشن‌استرینگ (همان قرارداد CI)
TARAZIN_TEST_CONN="Server=localhost;Database=TarazinMaster;User Id=sa;Password=...;TrustServerCertificate=True;Encrypt=False" \
  bash tools/seed-demo-data.sh
```

گزینه‌ها: `--company <id>`، `--fiscal-year <id>`، `--force`، `--reseed`،
`--server`، `--db`، `--user`، `--password`، `-h/--help`. در صورت تنظیم
`TARAZIN_TEST_CONN`، گزینه‌های اتصال را نادیده می‌گیرد (همان رفتار `TestDb.cs`).

### `--reseed` چگونه کار می‌کند؟

`--reseed` اول `tools/seed-cleanup.sql` را اجرا می‌کند (پاک‌سازی فقط دادهٔ خودِ
نمونه‌ها با نشانگرهای اختصاصی: توضیحات «نمونه»، حرکت «حواله بابت GINV-»، چک
`CHQ-SAMPLE%`، فاکتور طلا با قلم `XAU-24`، صندوق/بانک `GoldInvoice:%`) و در
ترتیب امن FK حذف می‌کند؛ تعادل صندوق/بانک را برمی‌گرداند، لایه‌های FIFO مصرف‌شده
را پاک می‌کند و `Items.StockQty` را از لایه‌های باقی‌مانده بازمحاسبه می‌کند.
سپس سه مرحلهٔ سید از نو اجرا می‌شود. دادهٔ سید اصلی (`_Seed.sql`) دست نمی‌خورد
— نشانگرها طوری انتخاب شده‌اند که فقط خروجیِ خودِ `tools/sample-*.sql` را بگیرند
(مثلاً فاکتور sample همیشه `XAU-24` می‌فروشد، در حالی که سید اصلی فقط `XAU-18`
و `GINV-00001` می‌سازد). سه بار اجرای پیاپی `--reseed` = دقیقاً یک نسخه از هر
نمونه (تست‌شده روی دیتابیس زنده).

### چه داده‌ای ساخته می‌شود؟

| مرحله | اسکریپت | داده |
|-------|---------|------|
| ۱ | `sample-inventory-treasury.sql` | رسید ۱۰۰ گرم GOLD-18 + حواله ۱۰ گرم + دریافت صندوق ۱۵۰M + پرداخت بانک ۴۵M + چک ۶۰M (سررسید ۱۵ روز بعد) |
| ۲ | `sample-gold-receipt.sql` | رسید ۵۰ گرم GOLD-24 (لایهٔ FIFO برای فاکتور) |
| ۳ | `sample-gold-invoice.sql` | فاکتور فروش طلا: ۲ گرم XAU-24، پرداخت بانکی ۷۹M |
| ۰ (در `--reseed`) | `seed-cleanup.sql` | پاک‌سازی idempotent نمونه‌های قبلی (فقط دادهٔ خودِ sample) |

پوشش تست خودکار: `SeedCleanupTests` در `Tarazin.Tests` (روی دیتابیس زنده) تأیید
می‌کند که cleanup فقط نمونه‌ها را حذف می‌کند و سید اصلی دست‌نخورده می‌ماند و
`StockQty` از لایه‌های باقی‌مانده بازمحاسبه می‌شود:
`dotnet test --filter FullyQualifiedName~SeedCleanupTests`

نکته‌ها:

- تاریخ همهٔ حرکات **امروز** است تا در فیلترهای پیش‌فرض دیده شوند.
- اتصال حسابداری خزانه فعال است → برای دریافت/پرداخت، **سند حسابداری خودکار**
  ساخته می‌شود (شواهد زندهٔ یکپارچگی).
- اتصال حسابداری انبار به‌صورت موقت خاموش می‌شود چون حساب‌های انبار در این
  دیتابیس NULL هستند؛ بعد از پایان دوباره همان وضعیت قبلی برگردانده می‌شود.

### ایمنی و idempotency

- اسکریپت‌ها idempotent **نیستند** — هر اجرا ردیف‌های جدید می‌سازد.
- گارد داخلی: اگر چک `CHQ-SAMPLE-001` از قبل وجود داشته باشد، بدون `--force`
  اجرا متوقف می‌شود (جلوی تکرار تصادفی).
- همهٔ اسکریپت‌ها با `sqlcmd -I -b` اجرا می‌شوند: `-I` برای QUOTED_IDENTIFIER ON
  (الزامی — ایندکس‌های فیلترشدهٔ چند اسکیم بدون آن ساخته/استفاده نمی‌شوند)
  و `-b` تا هر خطایی با خروجی غیرصفر متوقف شود.

### خطاهای رایج

- **`Invalid object name`** → دیتابیس هنوز schema ندارد؛ `_Ensure`ها را اجرا کنید
  یا روی دیتابیس تازهٔ ساخته‌شده توسط برنامه اجرا کنید.
- **`sqlcmd not found`** → SQL Server Command Line Tools نصب نیست یا خارج از
  مسیرهای جستجو است؛ مسیر `sqlcmd.exe` را در PATH بگذارید.
- **خطای موجودی کافی نیست (51003/51077)** → شرکت هدف برای کالای موردنظر در
  انبار هدف، لایه/موجودی ندارد؛ ابتدا یک رسید (Receipt) دستی ثبت کنید یا از
  `--company` استفاده کنید.
- **خطای 51027 (سال مالی)** → برای `--company` موردنظر، سال مالی فعال وجود
  ندارد؛ مقدار `--fiscal-year` را با سال مالی همان شرکت بدهید.
