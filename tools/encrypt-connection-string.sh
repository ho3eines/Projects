#!/usr/bin/env bash
# encrypt-connection-string.sh — تولید مقدار ENC: برای appsettings.json
# استفاده:
#   ./tools/encrypt-connection-string.sh "Server=example.invalid;Database=TarazinMaster;User Id=sa;Password=changeme;Encrypt=True"
#   یا بدون آرگومان، رشته را از ورودی می‌خواند.
# (مثال بالا عمداً از example.invalid و changeme استفاده می‌کند تا اسکن امنیتی آن را placeholder حساب کند)
#
# خروجی: یک خط ENC:<Base64(IV+Ciphertext)> که مستقیماً در
#   Tarazin.Web/appsettings.json → ConnectionStrings:DefaultConnection
#   قرار می‌گیرد و با کلید  TARAZIN_ENCRYPTION_KEY  یا  ConnectionProtection:Key
#   (Base64 ‎۳۲ بایتی) رمزگشایی می‌شود.
# کلید اگر داده نشود، یک کلید تصادفی ۳۲ بایتی می‌سازد و نمایش می‌دهد.
set -euo pipefail

if [ $# -ge 2 ]; then
  echo "Usage: $0 [connection-string]" >&2
  exit 1
fi

if [ $# -eq 1 ]; then
  PLAINTEXT="$1"
else
  echo -n "Connection string: "
  IFS= read -r PLAINTEXT
fi

if [ -z "${PLAINTEXT}" ]; then
  echo "connection string is empty" >&2
  exit 1
fi

# کلید: اگر TARAZIN_ENCRYPTION_KEY در محیط باشد همان، وگرنه بساز
if [ -n "${TARAZIN_ENCRYPTION_KEY:-}" ]; then
  KEY_B64="$TARAZIN_ENCRYPTION_KEY"
  echo "Using key from TARAZIN_ENCRYPTION_KEY" >&2
else
  KEY_B64="$(openssl rand -base64 32)"
  echo "Generated ephemeral key (store it as TARAZIN_ENCRYPTION_KEY or ConnectionProtection:Key):" >&2
  echo "  $KEY_B64" >&2
  echo "" >&2
fi

KEY_HEX="$(echo -n "$KEY_B64" | base64 -d | od -An -tx1 2>/dev/null | tr -d ' \n' || python3 -c "import base64,sys;print(base64.b64decode(sys.argv[1]).hex())" "$KEY_B64")"
IV_HEX="$(openssl rand -hex 16)"

# رمزگذاری AES-256-CBC PKCS7 با IV تصادفی (سازگار با Tarazin.Data.ConnectionStringProtector)
PLAINTEXT_FILE="$(mktemp)"
CIPHER_FILE="$(mktemp)"
trap 'rm -f "$PLAINTEXT_FILE" "$CIPHER_FILE"' EXIT
printf "%s" "$PLAINTEXT" > "$PLAINTEXT_FILE"
openssl enc -aes-256-cbc -in "$PLAINTEXT_FILE" -out "$CIPHER_FILE" -K "$KEY_HEX" -iv "$IV_HEX" -nosalt

# ترکیب IV + ciphertext و Base64
ENC_B64="$(python3 - <<PY
import base64
iv = bytes.fromhex("$IV_HEX")
with open("$CIPHER_FILE","rb") as f:
    ct = f.read()
import base64
print(base64.b64encode(iv+ct).decode())
PY
)"
ENC_VALUE="ENC:$ENC_B64"

echo ""
echo "ENC value (put in appsettings.json):"
echo "$ENC_VALUE"
echo ""
echo "Key (Base64 32 bytes):"
echo "$KEY_B64"
echo ""
echo "Quick verify (decrypt):"
python3 - <<PY
import base64, subprocess, tempfile, os
key_b64="$KEY_B64"
key_hex="$KEY_HEX"
enc_b64="$ENC_B64"
import base64, subprocess, tempfile
iv = base64.b64decode(enc_b64)[:16]
ct = base64.b64decode(enc_b64)[16:]
import tempfile, subprocess
with tempfile.NamedTemporaryFile(delete=False) as cf:
    cf.write(ct)
    ct_path=cf.name
out=tempfile.mktemp()
subprocess.run(["openssl","enc","-d","-aes-256-cbc","-in",ct_path,"-out",out,"-K",key_hex,"-iv",iv.hex(),"-nosalt"], check=True)
with open(out,"rb") as pf:
    print(pf.read().decode())
PY
