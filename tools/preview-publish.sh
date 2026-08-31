#!/usr/bin/env bash
# انتشار هاست وب در مسیری بیرون از مخزن، برای «سرور پیش‌نمایش» عامل.
#
# چرا جدا؟ اگر سرور از Tarazin.Web/bin اجرا شود، DLLها قفل می‌شوند و
# بیلد/تست بعدی با MSB3021/MSB3027 می‌شکند (و توسعه‌دهنده هم‌زمان نمی‌تواند
# بیلد بگیرد). انتشار در مسیر جدا این تداخل را کامل حذف می‌کند و کپی منتشرشده
# دیگر به staticwebassets manifest مخزن وابسته نیست.
#
# استفاده:  bash tools/preview-publish.sh
# سپس سرور را با پیکربندی «tarazin-web» در .claude/launch.json بالا بیاور
# (همان مسیر خروجی این اسکریپت را اجرا می‌کند).
#
# پورت‌ها: سرورِ پیش‌نمایشِ عامل روی 65320/65321 اجرا می‌شود تا با پورت‌های
# 65220/65221 که توسعه‌دهنده خودش با آن‌ها کار می‌کند تداخل نداشته باشد.
# نکته: `Tarazin:HttpsPort` در appsettings.json روی 65220 است، پس در خط فرمان
# باید override شود؛ وگرنه redirect از HTTP به پورتِ توسعه‌دهنده می‌رود.
set -euo pipefail

OUT="${TARAZIN_PREVIEW_DIR:-D:/Hermes/tarazin-preview/web}"

echo "=== Publishing Tarazin.Web → $OUT ==="
dotnet publish Tarazin.Web/Tarazin.Web.csproj -c Debug -o "$OUT" --nologo

echo
echo "✅ منتشر شد: $OUT"
echo "   اجرا: \"$OUT/Tarazin.Web.exe\" --environment Development --contentRoot \"$OUT\" --urls \"https://localhost:65320;http://localhost:65321\" --Tarazin:HttpsPort=65320"
