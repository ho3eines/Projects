#!/usr/bin/env python3
"""
sql-contract-scan.py — قرارداد بین «اسکریپت‌های نامدار TSQL» و «فراخوان‌های C#/Razor»
را به‌صورت ایستا بررسی می‌کند.

چرا لازم است؟ لایهٔ داده در ترازین با Dapper و اسکریپت‌های نامدار کار می‌کند و
هیچ کامپایلری این قرارداد را چک نمی‌کند. یک پارامتر جاافتاده تا زمان اجرا
(و اغلب داخل try/catch) پنهان می‌ماند. این اسکریپت همان کلاس باگ‌هایی را می‌گیرد
که باعث شده بود «افزودن گره» و «ساخت جداول» بی‌صدا شکست بخورند.

بررسی‌ها:
  1. MISSING_SCRIPT   — اسکریپتی که فراخوانی شده ولی وجود ندارد.
  2. MISSING_PARAM    — پارامتری که اسکریپت لازم دارد ولی فرستاده نشده
                        (خطای SQL «Must declare the scalar variable»).
  3. COLLISION        — پارامتری که داخل خود اسکریپت DECLARE شده
                        (خطای SQL Msg 134 → کل عملیات شکست می‌خورد).
  4. ALWAYS_TRUE_NULL — «DECLARE @x INT = 0 … IF @x IS NOT NULL» که همیشه true است
                        (دقیقاً باگ BaseDetilLinkUpsert که INSERT را مرده می‌کرد).
  5. BATCH_HAZARD     — افزودن ستون با ALTER و استفاده از همان ستون در همان batch
                        بدون GO (خطای کامپایل → شکست کامل EnsureSchema).
  6. STALE_INDEX_HINT — WITH (INDEX(x)) روی ایندکسی که ممکن است وجود نداشته باشد.

خروجی: کد ۱ در صورت وجود خطا (مناسب CI).
"""
from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "Tarazin.Data", "Scripts")
METHODS = (
    "QueryAsync",
    "QueryFirstOrDefaultAsync",
    "ExecuteAsync",
    "ExecuteReturningAsync",
    "ScalarAsync",
)
BUILTIN = {"rowcount", "error", "identity", "version", "trancount", "spid", "fetch_status"}


# ───────────────────────── SQL side ─────────────────────────
def strip_sql(sql: str) -> str:
    sql = re.sub(r"/\*.*?\*/", " ", sql, flags=re.S)
    sql = re.sub(r"--[^\n]*", " ", sql)
    return re.sub(r"N?'(?:[^']|'')*'", "''", sql)


def declared_vars(s: str) -> set[str]:
    out: set[str] = set()
    for m in re.finditer(r"\bDECLARE\b", s, re.I):
        i, depth, seg = m.end(), 0, ""
        while i < len(s):
            ch = s[i]
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            elif ch == ";" and depth == 0:
                break
            elif ch == "\n" and depth == 0:
                nxt = s[i:i + 40].strip()
                if re.match(r"^(SELECT|INSERT|UPDATE|DELETE|IF|BEGIN|WITH|SET|EXEC|THROW"
                            r"|CREATE|ALTER|DROP|MERGE|RETURN|PRINT)\b", nxt, re.I):
                    break
            seg += ch
            i += 1
        depth, cur, items = 0, "", []
        for ch in seg:
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            if ch == "," and depth == 0:
                items.append(cur)
                cur = ""
                continue
            cur += ch
        items.append(cur)
        for it in items:
            m2 = re.match(r"\s*@(\w+)", it)
            if m2:
                out.add(m2.group(1).lower())
    return out


def load_scripts() -> dict:
    scripts = {}
    for dirpath, _, files in os.walk(SCRIPTS):
        for f in sorted(files):
            if not f.endswith(".sql"):
                continue
            schema, name = os.path.basename(dirpath).lower(), f[:-4]
            raw = open(os.path.join(dirpath, f), encoding="utf-8").read()
            s = strip_sql(raw)
            dec = declared_vars(s)
            used = {x.lower() for x in re.findall(r"@(\w+)", s)} - BUILTIN
            scripts[f"{schema}/{name.lower()}"] = {
                "required": sorted(used - dec),
                "declared": dec,
                "path": os.path.join(dirpath, f),
                "raw": raw,
                "stripped": s,
            }
    return scripts


# ───────────────────────── C# / Razor side ─────────────────────────
def find_calls(text: str):
    out = []
    for m in re.finditer(r"\.\s*(" + "|".join(METHODS) + r")\s*(<)?", text):
        i = m.end()
        if m.group(2):
            depth = 1
            while i < len(text) and depth:
                if text[i] == "<":
                    depth += 1
                elif text[i] == ">":
                    depth -= 1
                i += 1
        while i < len(text) and text[i] in " \t\r\n":
            i += 1
        if i >= len(text) or text[i] != "(":
            continue
        depth, j, instr, inverb = 0, i, False, False
        while j < len(text):
            ch = text[j]
            if instr:
                if ch == "\\" and not inverb:
                    j += 2
                    continue
                if ch == '"':
                    if inverb and j + 1 < len(text) and text[j + 1] == '"':
                        j += 2
                        continue
                    instr = inverb = False
            else:
                if ch == '"':
                    instr = True
                    inverb = j > 0 and text[j - 1] == "@"
                elif ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                    if depth == 0:
                        break
            j += 1
        out.append((text[i + 1:j], m.start()))
    return out


def split_args(s: str):
    parts, depth, cur, instr = [], 0, "", False
    i = 0
    while i < len(s):
        ch = s[i]
        if instr:
            if ch == "\\":
                cur += s[i:i + 2]
                i += 2
                continue
            if ch == '"':
                instr = False
            cur += ch
            i += 1
            continue
        if ch == '"':
            instr = True
            cur += ch
            i += 1
            continue
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
            i += 1
            continue
        cur += ch
        i += 1
    if cur.strip():
        parts.append(cur)
    return parts


def anon_props(arg: str):
    a = arg.strip()
    if not re.match(r"^new\s*(?:\w+)?\s*\{", a, re.S):
        return None
    j, depth, body = a.find("{"), 0, None
    for k in range(j, len(a)):
        if a[k] == "{":
            depth += 1
        elif a[k] == "}":
            depth -= 1
            if depth == 0:
                body = a[j + 1:k]
                break
    if body is None:
        return None
    props = []
    for p in split_args(body):
        p = re.sub(r"//[^\n]*", "", p).strip()
        if not p:
            continue
        m = re.match(r"^(\w+)\s*=(?!=)", p) or re.match(r"^([A-Za-z_]\w*)$", p) \
            or re.match(r"^[A-Za-z_][\w\.]*\.(\w+)$", p)
        if m:
            props.append(m.group(1))
    return props


def main() -> int:
    scripts = load_scripts()
    errors, warnings = [], []

    # ---- 4. always-true NULL guards ----
    for key, sc in scripts.items():
        s = sc["stripped"]
        init = {}
        for m in re.finditer(r"DECLARE\s+@(\w+)\s+[\w()\,\s]*?=\s*([^,;\n]+)", s):
            init[m.group(1).lower()] = m.group(2).strip()
        for m in re.finditer(r"IF\s+@(\w+)\s+IS\s+(NOT\s+)?NULL", s, re.I):
            v = m.group(1).lower()
            if v in init and init[v].upper() != "NULL" and "(" not in init[v]:
                errors.append(
                    f"ALWAYS_TRUE_NULL {key}: «IF @{m.group(1)} IS "
                    f"{'NOT ' if m.group(2) else ''}NULL» ولی مقدار اولیه {init[v]} است")

    # ---- 5. batch hazards ----
    for key, sc in scripts.items():
        if not key.endswith("/_ensure"):
            continue
        for bi, b in enumerate(re.split(r"(?im)^\s*GO\s*$", sc["stripped"])):
            for m in re.finditer(r"ALTER\s+TABLE\s+(\[?\w+\]?\.\[?\w+\]?)\s+ADD\s+(?!CONSTRAINT)\[?(\w+)\]?",
                                 b, re.I):
                col, after = m.group(2), b[m.end():]
                if re.search(r"FOREIGN\s+KEY\s*\(\s*" + re.escape(col) + r"\s*\)", after, re.I):
                    errors.append(
                        f"BATCH_HAZARD {key} [batch {bi}]: ستون {col} اضافه شده و در همان "
                        f"batch در FOREIGN KEY استفاده شده — یک GO لازم است")

    # ---- 7. seed ordering (INSERT reads a table that is seeded later) ----
    for key, sc in scripts.items():
        if not key.endswith("/_seed"):
            continue
        s = sc["stripped"]
        stmts = []
        for m in re.finditer(r"INSERT\s+INTO\s+\[(\w+)\]\.\[(\w+)\]", s, re.I):
            i, d = m.end(), 0
            while i < len(s):
                if s[i] == "(":
                    d += 1
                elif s[i] == ")":
                    d -= 1
                elif s[i] == ";" and d == 0:
                    break
                i += 1
            stmts.append((m.start(), f"{m.group(1)}.{m.group(2)}".lower(), s[m.start():i]))
        first: dict[str, int] = {}
        for pos, t, _ in stmts:
            first.setdefault(t, pos)
        seen = set()
        for pos, t, body in stmts:
            for mm in re.finditer(r"(?:FROM|JOIN)\s+\[(\w+)\]\.\[(\w+)\]", body, re.I):
                src = f"{mm.group(1)}.{mm.group(2)}".lower()
                if src != t and src in first and first[src] > pos and (t, src) not in seen:
                    seen.add((t, src))
                    errors.append(
                        f"SEED_ORDER {key}: «INSERT INTO {t}» از {src} می‌خواند ولی "
                        f"{src} بعداً seed می‌شود → صفر ردیف درج می‌شود")

    # ---- 6. stale index hints ----
    ensure_all = "\n".join(sc["raw"] for k, sc in scripts.items() if k.endswith("/_ensure"))
    guarded = set(re.findall(r"sys\.indexes\s+WHERE\s+name\s*=\s*N'(\w+)'", ensure_all))
    for key, sc in scripts.items():
        for m in re.finditer(r"INDEX\((\w+)\)", sc["raw"]):
            if m.group(1) not in guarded:
                warnings.append(f"STALE_INDEX_HINT {key}: hint به {m.group(1)} که تضمین‌شده ساخته نمی‌شود")

    # ---- 1/2/3. call-site contract ----
    for dirpath, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in (".git", "bin", "obj", "node_modules")]
        for f in files:
            if not (f.endswith(".razor") or f.endswith(".cs")):
                continue
            path = os.path.join(dirpath, f)
            rel = os.path.relpath(path, ROOT)
            text = open(path, encoding="utf-8", errors="replace").read()
            const_schema = re.search(r'const\s+string\s+Schema\s*=\s*"([^"]+)"', text)
            for args, pos in find_calls(text):
                parts = split_args(args)
                if len(parts) < 2:
                    continue
                m0 = re.match(r'^"([^"]+)"$', parts[0].strip())
                m1 = re.match(r'^"([^"]+)"$', parts[1].strip())
                if not m1:
                    continue
                schema = m0.group(1) if m0 else (const_schema.group(1) if const_schema else None)
                if not schema:
                    continue
                key = f"{schema.lower()}/{m1.group(1).lower()}"
                line = text[:pos].count("\n") + 1
                if key not in scripts:
                    errors.append(f"MISSING_SCRIPT {rel}:{line} → {key}")
                    continue
                props = anon_props(parts[2]) if len(parts) >= 3 else []
                if props is None:
                    continue
                sup = {p.lower() for p in props}
                for miss in sorted(set(scripts[key]["required"]) - sup):
                    errors.append(f"MISSING_PARAM {rel}:{line} [{key}] → @{miss}")
                for col in sorted(sup & scripts[key]["declared"]):
                    errors.append(f"COLLISION {rel}:{line} [{key}] → @{col} داخل اسکریپت DECLARE شده")

    print(f"اسکریپت‌ها: {len(scripts)}")
    for w in warnings:
        print(f"  ⚠ {w}")
    for e in errors:
        print(f"  ✖ {e}")
    if errors:
        print(f"\nنتیجه: {len(errors)} خطا")
        return 1
    print(f"\nنتیجه: قرارداد سالم است ({len(warnings)} هشدار)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
