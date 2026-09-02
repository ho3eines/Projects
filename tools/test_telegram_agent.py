#!/usr/bin/env python3
"""تست خودکار رفتارهای حیاتی ربات تلگرام (بدون شبکهٔ واقعی).

اجرا:
    python tools/test_telegram_agent.py

پوشش:
  ۱) ارسال → صف → تحویل (شبیه‌سازی قطعی و بهبود)
  ۲) هشدارهای سلامت (گذر از آستانه، یک‌بار، بهبود، idempotent)
  ۳) هشدار و سقف outbox (۱۰ رکورد → هشدار؛ ۵۰ → رد ارسال جدید)
  ۴) ری‌استارت config (watcher: تغییر TELEGRAM_PROXY ↔ فایل) — بدون spawn واقعی
  ۵) اولویت‌بندی (high قبل از normal)
  ۶) ثبت/نگهداشت history.jsonl (_append_history_sample + _prune_history_file)
  ۷) قرارداد ساخت SVG نمودار (آینهٔ دقیق BuildChart صفحهٔ TelegramBotHealth.razor)
  ۸) ترنسپورت: انتخاب webhook/poll (auto با/بدون URL) + پارامترهای setWebhook
  ۹) گیرندهٔ وب‌هوک: 403 بدون secret، 200 با secret و پردازش update
  ۱۰) پاک‌سازی webhook کهنه قبل از long-poll (جلوگیری از 409)

همهٔ فایل‌ها به یک پوشهٔ موقت هدایت می‌شوند — به صف/لاگ/config واقعی دست نمی‌زند.
"""

import json
import math
import os
import shutil
import sys
import tempfile
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import telegram_agent as tg  # noqa: E402

TMP = tempfile.mkdtemp(prefix="tg-agent-test-")
_PASSED = []
_FAILED = []


def _reset(tmp_path=None):
    """هدایت همهٔ فایل‌های وضعیت به پوشهٔ موقت + پاک‌سازی بین تست‌ها + ریست state."""
    for name, fn in (
        ("OUTBOX_FILE", "outbox.jsonl"),
        ("QUEUE_FILE", "queue.jsonl"),
        ("STATUS_FILE", "status.json"),
        ("OFFSET_FILE", "agent-offset"),
        ("LOG_FILE", "agent.log"),
        ("AUTO_FILE", "auto-mode"),
        ("STOP_FILE", "agent.stop"),
        ("HISTORY_FILE", "history.jsonl"),
    ):
        path = os.path.join(TMP, fn)
        if os.path.exists(path):
            os.remove(path)
        setattr(tg, name, path)
    tg.LOCK_FILE = os.path.join(TMP, "bridge.lock")
    if tmp_path is not None:
        tg.CONFIG_FILE = os.path.join(TMP, "test.env")
        if os.path.exists(tg.CONFIG_FILE):
            os.remove(tg.CONFIG_FILE)
    tg._consecutive_failures = 0
    tg._health_degraded = False
    tg._outbox_warned = False
    tg._last_error = ""
    tg._last_error_ts = 0.0
    tg._last_success_ts = 0.0
    tg._last_history_ts = 0.0


def _outbox_records():
    if not os.path.exists(tg.OUTBOX_FILE):
        return []
    return [json.loads(l) for l in open(tg.OUTBOX_FILE, encoding="utf-8") if l.strip()]


def _check(name, condition, detail=""):
    if condition:
        _PASSED.append(name)
        print(f"  ✅ {name}")
    else:
        _FAILED.append(name)
        print(f"  ❌ {name} {detail}")


# ── ۱) ارسال → صف → تحویل ─────────────────────────────
def test_send_queue_delivery():
    print("\n[۱] ارسال → صف → تحویل")
    _reset()
    delivered = []

    # قطعی: ارسال باید در صف بماند (تلاش فوری ناموفق — در delivered ثبت نمی‌شود)
    tg._deliver = lambda r: False
    tg.send("پیام معوق")
    _check("send در قطعی، رکورد را در صف می‌گذارد",
           len(_outbox_records()) == 1, f"got {len(_outbox_records())}")

    # بهبود: send_pending تحویل می‌دهد و صف را خالی می‌کند
    delivered = []
    tg._deliver = lambda r: delivered.append(r["text"]) or True
    tg.send_pending()
    _check("send_pending بعد از بهبود، صف را خالی می‌کند",
           len(_outbox_records()) == 0, f"got {len(_outbox_records())}")
    _check("پیام تحویل‌شده همان متن است", delivered == ["پیام معوق"], str(delivered))

    # مسیر فوری: با شبکهٔ سالم، send همان لحظه تحویل می‌دهد و صف خالی می‌ماند
    tg.send("پیام فوری")
    _check("send با شبکهٔ سالم → تحویل فوری و صف خالی",
           len(_outbox_records()) == 0, f"got {len(_outbox_records())}")


# ── ۲) هشدارهای سلامت ─────────────────────────────────
def test_health_alerts():
    print("\n[۲] هشدارهای سلامت")
    _reset()
    tg._deliver = lambda r: False

    for n in range(1, 7):
        tg._consecutive_failures = n
        tg.health_check()
    alerts = [r for r in _outbox_records() if "هشدار سلامت" in r["text"]]
    _check("گذر از آستانهٔ ۵ → دقیقاً یک هشدار", len(alerts) == 1, f"got {len(alerts)}")
    _check("فلگ degraded روشن شد", tg._health_degraded)

    tg._consecutive_failures = 9
    tg.health_check()
    alerts = [r for r in _outbox_records() if "هشدار سلامت" in r["text"]]
    _check("تکرار بالای آستانه → هشدار تکراری صفر (idempotent)",
           len(alerts) == 1, f"got {len(alerts)}")

    tg._consecutive_failures = 0
    tg.health_check()
    records = _outbox_records()
    _check("بهبود → هشدار کهنه حذف شد",
           not any("هشدار سلامت" in r["text"] for r in records))
    _check("بهبود → پیام «عادی برگشت» ثبت شد",
           any("به حالت عادی" in r["text"] for r in records))
    _check("فلگ degraded خاموش شد", not tg._health_degraded)


# ── ۳) هشدار و سقف outbox ─────────────────────────────
def test_outbox_warn_and_cap():
    print("\n[۳] هشدار و سقف outbox")
    _reset()
    tg._deliver = lambda r: False

    for i in range(11):
        tg.send(f"معوق {i}", priority="normal")
    tg.send_pending()
    warns = [r for r in _outbox_records() if "هشدار صف ارسال" in r["text"]]
    _check("۱۱ رکورد معوق → یک هشدار صف", len(warns) == 1, f"got {len(warns)}")

    tg.send_pending()
    warns = [r for r in _outbox_records() if "هشدار صف ارسال" in r["text"]]
    _check("سیکل دوم → هشدار تکراری صفر", len(warns) == 1, f"got {len(warns)}")

    # سقف سخت
    _reset()
    tg._deliver = lambda r: False
    for i in range(tg.OUTBOX_HARD_CAP):
        tg.send(f"cap {i}", priority="normal")
    before = len(_outbox_records())
    refused = tg.send("باید رد شود", priority="normal")
    _check("سقف ۵۰ → ارسال جدید رد می‌شود", refused is False and len(_outbox_records()) == before,
           f"refused={refused} count={len(_outbox_records())}")


# ── ۴) ری‌استارت config (watcher) ─────────────────────
def test_config_watcher():
    print("\n[۴] watcher تغییر TELEGRAM_PROXY")
    _reset(tmp_path=True)
    # config موقت با همان مقدار در حال اجرای ماژول (تا حالت «برابر» شبیه‌سازی شود)
    with open(tg.CONFIG_FILE, "w", encoding="utf-8") as f:
        f.write(f"TELEGRAM_BOT_TOKEN=test-token\nTELEGRAM_PROXY={tg.PROXY or ''}\n")
    _check("فایل برابر با حافظه → تغییری تشخیص داده نمی‌شود", not tg._config_proxy_changed())

    tg.set_proxy_config(False)
    _check("set_proxy_config(False) → خالی می‌شود", tg._config_proxy_value() == "")
    _check("watcher تغییر را تشخیص می‌دهد (→ ری‌استارت)", tg._config_proxy_changed())

    tg.set_proxy_config(True)
    _check("set_proxy_config(True) → پروکسی 3067 برمی‌گردد",
           tg._config_proxy_value() == "http://127.0.0.1:3067")
    _check("بعد از ری‌استارت (حافظه == فایل) → پایدار", not tg._config_proxy_changed())

    # خطوط دیگر (توکن) دست‌نخورده می‌مانند
    content = open(tg.CONFIG_FILE, encoding="utf-8").read()
    _check("خط توکن هنگام تغییر پروکسی حفظ می‌شود", "TELEGRAM_BOT_TOKEN=test-token" in content)


# ── ۵) اولویت‌بندی ────────────────────────────────────
def test_priority_ordering():
    print("\n[۵] اولویت‌بندی outbox")
    _reset()
    order = []
    tg._deliver = lambda r: order.append(r["text"]) or True

    tg.enqueue_outbox("گزارش عادی ۱ (قدیمی‌تر)")
    tg.enqueue_outbox("گزارش عادی ۲")
    tg.send("پاسخ کلیک ۱", priority="high")
    tg.send("پاسخ کلیک ۲", priority="high")
    tg.send_pending()

    expected = ["پاسخ کلیک ۱", "پاسخ کلیک ۲", "گزارش عادی ۱ (قدیمی‌تر)", "گزارش عادی ۲"]
    _check("ترتیب تحویل: high اول، سپس normal به‌ترتیب زمان",
           order == expected, str(order))


# ── ۶) ثبت/نگهداشت history.jsonl ─────────────────────────────
def _history_rows():
    if not os.path.exists(tg.HISTORY_FILE):
        return []
    rows = []
    for line in open(tg.HISTORY_FILE, encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except ValueError:
            rows.append(None)   # خط خراب به‌عنوان None می‌آید
    return rows


def _write_history(rows):
    with open(tg.HISTORY_FILE, "w", encoding="utf-8") as h:
        for r in rows:
            if isinstance(r, str):
                h.write(r + "\n")
            else:
                h.write(json.dumps(r) + "\n")


def test_history_recording():
    print("\n[۶] ثبت نمونه‌های history.jsonl")
    _reset()
    tg._consecutive_failures = 4
    tg._health_degraded = True
    tg._last_history_ts = 0.0

    tg._append_history_sample(3)
    rows = _history_rows()
    _check("نمونه با ts/failures/outbox/degraded ثبت شد",
           len(rows) == 1 and rows[0]["failures"] == 4 and rows[0]["outbox"] == 3
           and rows[0]["degraded"] == 1 and rows[0]["ts"] > 0, str(rows))

    tg._append_history_sample(9)   # بلافاصله → throttle
    _check("داخل پنجرهٔ ۶۰ ثانیه → نمونهٔ تکراری صفر", len(_history_rows()) == 1)

    tg._last_history_ts = time.time() - 120
    tg._append_history_sample(9)
    rows = _history_rows()
    _check("بعد از گذشت پنجره → نمونهٔ جدید اضافه شد",
           len(rows) == 2 and rows[1]["outbox"] == 9, str(rows))


def test_history_prune():
    print("\n[۶ب] prune/نگهداشت دو سطحی history")
    _reset()

    # الف) زیر سقف → دست‌نخورده
    _write_history([{"ts": 1000 + i * 60, "failures": 0, "outbox": 0, "degraded": 0}
                    for i in range(10)])
    tg._prune_history_file()
    _check("زیر سقف → فایل بدون تغییر", len(_history_rows()) == 10)

    # ب) بالای سقف → ۲۴ ساعت آخر با ۶۰s + قدیمی‌ترها به باکت ۶۰۰s
    now = time.time()
    hot = [{"ts": int(now) - (1439 - i) * 60, "failures": 0, "outbox": 0, "degraded": 0}
           for i in range(1440)]
    old = [{"ts": int(now) - 24 * 3600 - (i + 1) * 60, "failures": 0, "outbox": 0, "degraded": 0}
           for i in range(5 * 1440)]
    old[500]["failures"] = 9   # یک باکت قدیمی مقدار بد دارد
    _write_history(hot + old)
    tg._prune_history_file()
    pruned = _history_rows()
    _check("پس از prune ≤ سقف ۶۰۰۰",
           len(pruned) <= tg.HISTORY_MAX_LINES, f"got {len(pruned)}")
    cutoff = pruned[-1]["ts"] - 24 * 3600
    hot_kept = [r for r in pruned if r["ts"] >= cutoff]
    _check("۲۴ ساعت آخر با رزولوشن ۶۰ ثانیه حفظ شد",
           len(hot_kept) == 1440, f"got {len(hot_kept)}")
    cold = [r for r in pruned if r["ts"] < cutoff]
    _check("قدیمی‌ترها به باکت ۶۰۰ ثانیه فشرده شدند",
           len(cold) > 0 and all(r["ts"] % 600 == 0 for r in cold), f"got {len(cold)}")
    _check("بدترین مقدار هر باکت حفظ می‌شود (failures=9)",
           max(r["failures"] for r in cold) == 9)

    # ج) خط خراب در فایل بالای سقف → بدون خطا حذف می‌شود
    now = time.time()
    many = [{"ts": int(now) - (6000 - i) * 60, "failures": 0, "outbox": 0, "degraded": 0}
            for i in range(6100)]
    lines = []
    for r in many:
        lines.append(r)
        if len(lines) == 3000:
            lines.append("not-json{{broken")
    _write_history(lines)
    tg._prune_history_file()
    rows = _history_rows()
    _check("خط خراب باعث خطا نمی‌شود و حذف می‌شود",
           len(rows) > 0 and all(r is not None for r in rows), f"got {len(rows)}")


# ── ۷) قرارداد ساخت SVG نمودار (آینهٔ TelegramBotHealth.razor) ──
def _build_svg_contract(rows, range_days, now_ts):
    """آینهٔ دقیق LoadHistoryAndChartAsync + BuildChart صفحهٔ TelegramBotHealth.razor:
    فیلتر پنجره → باکت (۹۰۰/۳۶۰۰/۱۰۸۰۰) با بدترین مقدار → نقاط SVG.
    سازندهٔ واقعی در C# است؛ این تابع همان ریاضی را بازتولید می‌کند تا قرارداد
    داده/ریاضی نمودار با تست محافظت شود."""
    window = now_ts - range_days * 86400
    raw = [r for r in rows if r["ts"] >= window]
    bucket = 900 if range_days == 1 else (3600 if range_days == 7 else 10800)
    groups = {}
    for r in raw:
        b = int(r["ts"] // bucket) * bucket
        prev = groups.get(b)
        if prev is None or (r["failures"], r["outbox"], r["degraded"]) > \
                (prev["failures"], prev["outbox"], prev["degraded"]):
            groups[b] = r
    hist = [groups[k] for k in sorted(groups)]
    if len(hist) < 2:
        return None, 0, 0, 0

    peak_f = max(h["failures"] for h in hist)
    peak_o = max(h["outbox"] for h in hist)
    chart_max = max(5.0, float(peak_f), float(peak_o))
    chart_max = math.ceil(chart_max / 5.0) * 5.0

    inner_w, inner_h = 742.0, 182.0   # 800-46-12 و 220-12-26
    n = len(hist)

    def X(i):
        return 46.0 + (i / (n - 1)) * inner_w

    def Y(v):
        return 12.0 + inner_h - (v / chart_max) * inner_h

    f_pts = " ".join(f"{X(i):.1f},{Y(h['failures']):.1f}" for i, h in enumerate(hist))
    o_pts = " ".join(f"{X(i):.1f},{Y(h['outbox']):.1f}" for i, h in enumerate(hist))

    svg = '<svg viewBox="0 0 800 220" style="width:100%;height:auto" role="img">'
    for v in (0.0, chart_max / 2, chart_max):
        svg += f"<line x1='46' y1='{Y(v):.1f}' x2='788' y2='{Y(v):.1f}' stroke='#00000022'/>"
        svg += f"<text x='4' y='{Y(v) + 4:.1f}'>{v:.0f}</text>"
    svg += f"<polyline points='{o_pts}' fill='none' stroke='#2B6B7A' stroke-width='2' />"
    svg += f"<polyline points='{f_pts}' fill='none' stroke='#C62828' stroke-width='2' />"
    for t in range(4):
        idx = int(round(t * (n - 1) / 3.0))
        svg += f"<text x='{X(idx) - 12:.1f}' y='210'>{idx}</text>"
    svg += "</svg>"
    return svg, peak_f, peak_o, n


def _seed_30d():
    """دادهٔ مصنوعی ۳۰ روزه: ۲۴ ساعت آخر با ۶۰s + قدیمی‌ترها با ۶۰۰s و چند رخداد."""
    now = time.time()
    rows = []
    base = int(now // 60) * 60
    # ۲۴ ساعت آخر: آرام + قطعی ۳۰ دقیقه‌ای (اوج failures=5, outbox=2)
    for k in range(1440):
        ts = base - (1439 - k) * 60
        f = o = d = 0
        if 1000 <= k < 1030:
            f = min(1 + (k - 1000), 5)
            o, d = 2, 1
        rows.append({"ts": ts, "failures": f, "outbox": o, "degraded": d})
    # روزهای ۲ تا ۳۰ با ۶۰۰s + دو رخداد (اوج ۷/۴ و ۶/۳)
    incident3 = now - 3 * 86400      # ۳ روز پیش
    incident15 = now - 15 * 86400    # ۱۵ روز پیش
    for i in range(1, 28 * 144 + 1):
        ts = base - 24 * 3600 - i * 600
        f = o = d = 0
        if incident3 - 3600 <= ts <= incident3:
            f, o, d = 7, 4, 1
        elif incident15 - 3600 <= ts <= incident15:
            f, o, d = 6, 3, 1
        rows.append({"ts": ts, "failures": f, "outbox": o, "degraded": d})
    return rows, base


def test_svg_chart_contract():
    print("\n[۷] قرارداد ساخت SVG نمودار (آینهٔ C# BuildChart)")
    rows, base = _seed_30d()
    now = base

    expected = {1: (5, 2, 90, 98), 7: (7, 4, 160, 172), 30: (7, 4, 230, 245)}
    for days in (1, 7, 30):
        svg, pf, po, n = _build_svg_contract(rows, days, now)
        lo, hi = expected[days][2], expected[days][3]
        _check(f"{days:>2}d: اوج درست (F={expected[days][0]} O={expected[days][1]})",
               pf == expected[days][0] and po == expected[days][1], f"got F={pf} O={po}")
        _check(f"{days:>2}d: تعداد نقاط در بازهٔ منطقی [{lo},{hi}]",
               svg is not None and lo <= n <= hi, f"got {n}")
        _check(f"{days:>2}d: ساختار SVG (viewBox + رنگ‌ها + polyline ها)",
               svg is not None
               and svg.startswith('<svg viewBox="0 0 800 220"')
               and svg.endswith('</svg>')
               and "stroke='#C62828'" in svg and "stroke='#2B6B7A'" in svg
               and svg.count("<polyline") == 2, "structure")
        _check(f"{days:>2}d: نقاط polyline عددی معتبرند",
               all(len(p.split(',')) == 2 for p in _f_pts_of(svg).split())
               and all(_is_float(x) for x in _f_pts_of(svg).replace(',', ' ').split()),
               "points")


def _is_float(s):
    try:
        float(s)
        return True
    except ValueError:
        return False


def _f_pts_of(svg):
    import re
    m = re.search(r"points='([^']+)' fill='none' stroke='#C62828'", svg)
    return m.group(1) if m else ""


# ── ۸) ترنسپورت: انتخاب webhook/poll + setWebhook ───────────────
def test_transport_selection_and_webhook_params():
    print("\n[۸] ترنسپورت webhook/poll + پارامترهای setWebhook")
    _reset()
    saved_url, saved_transport = tg.WEBHOOK_URL, tg.TRANSPORT
    try:
        tg.WEBHOOK_URL, tg.TRANSPORT = "", "auto"
        _check("auto بدون URL → poll (fallback)", tg.resolve_transport() == "poll")
        tg.WEBHOOK_URL, tg.TRANSPORT = "https://example.com/hook", "auto"
        _check("auto با URL → webhook", tg.resolve_transport() == "webhook")
        tg.WEBHOOK_URL, tg.TRANSPORT = "", "webhook"
        _check("webhook صریح بدون URL → poll (fallback امن)", tg.resolve_transport() == "poll")
        tg.WEBHOOK_URL, tg.TRANSPORT = "https://example.com/hook", "poll"
        _check("poll صریح حتی با URL → poll", tg.resolve_transport() == "poll")

        # پارامترهای setWebhook
        captured = {}
        tg.api = lambda method, params, timeout=25: captured.update(method=method, params=params) or {}
        tg.WEBHOOK_URL, tg.TRANSPORT, tg.WEBHOOK_SECRET = "https://example.com/hook", "webhook", "tz-secret-123"
        tg.register_webhook()
        p = captured["params"]
        _check("setWebhook با url درست", captured["method"] == "setWebhook" and p["url"] == "https://example.com/hook")
        _check("setWebhook با secret_token و allowed_updates",
               p.get("secret_token") == "tz-secret-123" and "callback_query" in p.get("allowed_updates", ""))
        _check("drop_pending_updates حروف کوچک (urlencode امن)", p.get("drop_pending_updates") == "false")

        # deleteWebhook
        captured.clear()
        tg.unregister_webhook()
        _check("deleteWebhook صدا زده می‌شود", captured["method"] == "deleteWebhook")
    finally:
        tg.WEBHOOK_URL, tg.TRANSPORT = saved_url, saved_transport
        tg.WEBHOOK_SECRET = ""


# ── ۹) گیرندهٔ وب‌هوک: اعتبارسنجی secret + پردازش ────────────────
def test_webhook_receiver():
    print("\n[۹] گیرندهٔ وب‌هوک (secret + پردازش update)")
    _reset()
    saved_secret, saved_listen = tg.WEBHOOK_SECRET, tg.WEBHOOK_LISTEN
    tg.WEBHOOK_SECRET = "tz-secret-abc"
    tg.WEBHOOK_LISTEN = "127.0.0.1:0"  # پورت آزاد برای تست
    processed = []
    tg.process_update = lambda update: processed.append(update)
    try:
        server = tg.start_webhook_server()
        port = server.server_address[1]
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        import urllib.request
        import urllib.error
        body = b'{"update_id": 42, "message": {"chat": {"id": 76937621}, "text": "/status"}}'
        base = f"http://127.0.0.1:{port}/"

        # بدون secret → 403 و بدون پردازش
        try:
            urllib.request.urlopen(urllib.request.Request(base, data=body, method="POST"), timeout=5)
            code = 200
        except urllib.error.HTTPError as exc:
            code = exc.code
        _check("بدون secret → 403", code == 403, f"got {code}")
        _check("بدون secret → update پردازش نشد", len(processed) == 0)

        # با secret درست → 200 و پردازش شد
        req = urllib.request.Request(base, data=body, method="POST",
                                     headers={"X-Telegram-Bot-Api-Secret-Token": "tz-secret-abc"})
        try:
            resp = urllib.request.urlopen(req, timeout=5)
            code = resp.status
        except urllib.error.HTTPError as exc:
            code = exc.code
        _check("با secret درست → 200", code == 200, f"got {code}")
        _check("update پردازش شد", len(processed) == 1 and processed[0].get("update_id") == 42)

        # GET → 200 (healthcheck تلگرام/پراکسی)
        try:
            resp = urllib.request.urlopen(base, timeout=5)
            code = resp.status
        except urllib.error.HTTPError as exc:
            code = exc.code
        _check("GET → 200", code == 200, f"got {code}")
        server.shutdown()
    finally:
        tg.WEBHOOK_SECRET, tg.WEBHOOK_LISTEN = saved_secret, saved_listen


# ── ۱۰) پاک‌سازی webhook کهنه قبل از long-poll ───────────────────
def test_stale_webhook_cleanup():
    print("\n[۱۰] پاک‌سازی webhook کهنه قبل از poll")
    _reset()
    calls = []

    def fake_api(method, params, timeout=25):
        calls.append(method)
        if method == "getWebhookInfo":
            return {"url": "https://old.example.com/hook"}
        return {}

    tg.api = fake_api
    tg._ensure_no_stale_webhook()
    _check("webhook کهنه → deleteWebhook صدا زده شد",
           calls == ["getWebhookInfo", "deleteWebhook"], str(calls))

    calls.clear()
    tg.api = lambda method, params, timeout=25: calls.append(method) or {"url": ""}
    tg._ensure_no_stale_webhook()
    _check("بدون webhook → فقط getWebhookInfo (بدون delete)", calls == ["getWebhookInfo"], str(calls))


def run():
    _reset()
    test_send_queue_delivery()
    test_health_alerts()
    test_outbox_warn_and_cap()
    test_config_watcher()
    test_priority_ordering()
    test_history_recording()
    test_history_prune()
    test_svg_chart_contract()
    test_transport_selection_and_webhook_params()
    test_webhook_receiver()
    test_stale_webhook_cleanup()

    print("\n" + "═" * 50)
    print(f"نتیجه: {len(_PASSED)} پاس / {len(_FAILED)} شکست")
    if _FAILED:
        print("شکست‌ها:", ", ".join(_FAILED))
        shutil.rmtree(TMP, ignore_errors=True)
        return 1
    shutil.rmtree(TMP, ignore_errors=True)
    print("✅ همهٔ تست‌ها پاس شدند.")
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
