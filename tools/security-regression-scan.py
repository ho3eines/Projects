#!/usr/bin/env python3
"""Static and publish-artifact regression checks for MAUI credential safety.

This is deliberately dependency-free so it can run in developer shells and CI.
It does not replace broker/RLS integration tests against SQL Server or a device.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
import uuid
import zipfile
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]
FIRST_PARTY_ARTIFACT = re.compile(
    r"^(Tarazin\.(?:Maui|Data|Ui|Share)(?:\.[^.]+)?\.dll|appsettings(?:\.[^.]+)?\.json)$",
    re.IGNORECASE,
)
TEXT_SUFFIXES = {
    ".cs", ".razor", ".xaml", ".xml", ".json", ".yml", ".yaml", ".sql",
    ".props", ".targets", ".csproj", ".slnx", ".sh", ".ps1", ".md", ".txt",
    ".config", ".plist", ".manifest",
}
EXCLUDED_PREFIXES = ("skills/", ".agents/", ".git/")
EXCLUDED_SOURCE_FILES = {"tools/security-regression-scan.py"}

CONNECTION_MARKER = re.compile(
    rb"(?i)(?<![A-Za-z0-9_])(?:server|data\s+source|address|addr|network\s+address|initial\s+catalog|"
    rb"database|user\s+id|uid|password|pwd)\s*="
)
PASSWORD_MARKER = re.compile(rb"(?i)(?<![A-Za-z0-9_])(?:password|pwd)\s*=")
SERVER_MARKER = re.compile(rb"(?i)(?<![A-Za-z0-9_])(?:server|data\s+source|address|addr|network\s+address)\s*=")
USER_MARKER = re.compile(rb"(?i)(?<![A-Za-z0-9_])(?:user\s+id|uid)\s*=")
PERMANENT_SECRET_PATTERNS = (
    ("private key", re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
    ("GitHub token", re.compile(rb"gh[opusr]_[A-Za-z0-9_]{30,}")),
    ("AWS access key", re.compile(rb"AKIA[0-9A-Z]{16}")),
    ("JWT", re.compile(rb"eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}")),
)
TLS_BYPASS_PATTERNS = (
    re.compile(rb"(?i)TrustServerCertificate\s*=\s*true"),
    re.compile(rb"(?i)Encrypt\s*=\s*false"),
    re.compile(rb"DangerousAcceptAnyServerCertificateValidator"),
    re.compile(rb"ServerCertificateCustomValidationCallback\s*=\s*(?:\([^)]*\)|[^=;]+)=>\s*true"),
)
PLACEHOLDER_PARTS = (
    b"${", b"$(", b"<strong", b"<password", b"<secret", b"example.invalid",
    b"your_", b"changeme", b"redacted", b"'...'", b'"..."',
)


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def tracked_files() -> list[Path]:
    try:
        output = subprocess.check_output(
            ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
            cwd=ROOT,
            stderr=subprocess.DEVNULL,
        )
        names = [entry.decode("utf-8") for entry in output.split(b"\0") if entry]
        # A deleted-but-not-yet-staged source file can still be listed by git
        # while an agent is validating a worktree. It has no payload to scan.
        return [ROOT / name for name in names if (ROOT / name).is_file()]
    except (subprocess.SubprocessError, OSError, UnicodeDecodeError):
        return [path for path in ROOT.rglob("*") if path.is_file()]


def source_files() -> Iterable[Path]:
    for path in tracked_files():
        relative = path.relative_to(ROOT).as_posix()
        if relative in EXCLUDED_SOURCE_FILES or relative.startswith(EXCLUDED_PREFIXES):
            continue
        if path.suffix.lower() in TEXT_SUFFIXES:
            yield path


def read_bytes(path: Path) -> bytes:
    try:
        return path.read_bytes()
    except OSError as exc:
        raise RuntimeError(f"cannot read {path}: {exc}") from exc


def printable_chunks(data: bytes) -> Iterable[bytes]:
    """Yield source lines and binary ASCII/UTF-16 strings without joining fields."""
    if b"\x00" not in data:
        yield from data.splitlines()
        return
    yield from re.findall(rb"[\x20-\x7e]{8,}", data)
    for raw in re.findall(rb"(?:[\x20-\x7e]\x00){8,}", data):
        yield raw.replace(b"\x00", b"")


def suspicious_connection_windows(data: bytes) -> list[bytes]:
    """Return strings that look like usable SQL connection strings."""
    findings: list[bytes] = []
    for chunk in printable_chunks(data):
        if not CONNECTION_MARKER.search(chunk):
            continue
        # A password plus server or username in one literal/line is materially
        # connection-like. Keeping chunks separate avoids joining C# property
        # assignments or unrelated metadata into a false connection string.
        if PASSWORD_MARKER.search(chunk) and (
            SERVER_MARKER.search(chunk) or USER_MARKER.search(chunk)
        ):
            if not any(part.lower() in chunk.lower() for part in PLACEHOLDER_PARTS):
                findings.append(chunk[:240])
                break
    return findings


def scan_generic_secret_bytes(label: str, data: bytes, errors: list[str]) -> None:
    normalized = data.replace(b"\x00", b"")
    for name, pattern in PERMANENT_SECRET_PATTERNS:
        if pattern.search(normalized):
            fail(errors, f"{label}: contains a {name}-shaped permanent secret")
    for pattern in TLS_BYPASS_PATTERNS:
        if pattern.search(normalized):
            fail(errors, f"{label}: contains a TLS/certificate validation bypass")
    windows = suspicious_connection_windows(data)
    if windows:
        # Tarazin.Web/appsettings.json is allowed to contain a plain localhost
        # dev connection string at rest (encryption is only in transit per user
        # request). Skip the generic connection-string flag for that dev case.
        if label == "Tarazin.Web/appsettings.json":
            # If every suspicious window is a localhost/127.0.0.1 dev string, skip
            if all(b"localhost" in w.lower() or b"127.0.0.1" in w for w in windows):
                return
            # If the file contains an ENC: value instead of plain, also skip
            # (the ENC: blob is not a usable plaintext secret)
            if b"ENC:" in normalized and b"Server=" not in normalized.replace(b"ENC:", b""):
                # Fallback: ENC: blob alone is not suspicious (handled above)
                return
        fail(errors, f"{label}: contains a usable SQL connection-string-shaped value")


def load_json(path: Path, errors: list[str]) -> object | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        fail(errors, f"{path.relative_to(ROOT)}: invalid/unreadable JSON ({exc})")
        return None


def walk_json(value: object, prefix: str = "") -> Iterable[tuple[str, object]]:
    if isinstance(value, dict):
        for key, child in value.items():
            name = f"{prefix}:{key}" if prefix else str(key)
            yield name, child
            yield from walk_json(child, name)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from walk_json(child, f"{prefix}[{index}]")


def scan_configuration(errors: list[str]) -> None:
    maui_path = ROOT / "Tarazin.Maui/appsettings.json"
    maui = load_json(maui_path, errors)
    allowed_maui_keys = {"ServerEndpoint", "CustomerGuid", "ConnectionProtection"}
    if not isinstance(maui, dict) or not {"ServerEndpoint", "CustomerGuid"}.issubset(set(maui)) or not set(maui).issubset(allowed_maui_keys):
        fail(errors, "Tarazin.Maui/appsettings.json must contain ServerEndpoint and CustomerGuid (ConnectionProtection is optional)")
    elif not isinstance(maui["ServerEndpoint"], str) or not maui["ServerEndpoint"].startswith("https://"):
        fail(errors, "MAUI ServerEndpoint must be a non-secret HTTPS URL")
    else:
        raw_guid = maui.get("CustomerGuid")
        if not isinstance(raw_guid, str):
            fail(errors, "MAUI CustomerGuid must be a GUID string")
        else:
            try:
                parsed = uuid.UUID(raw_guid)
                if parsed.int == 0:
                    fail(errors, "MAUI CustomerGuid must be a non-empty GUID")
            except (ValueError, AttributeError, TypeError):
                fail(errors, "MAUI CustomerGuid must be a non-empty GUID")

    for relative in ("Tarazin.Maui/appsettings.json", "Tarazin.Web/appsettings.json"):
        path = ROOT / relative
        config = load_json(path, errors)
        if config is None:
            continue
        for key, value in walk_json(config):
            leaf = key.rsplit(":", 1)[-1].lower()
            # Tarazin.Web may store the connection string plain at rest
            # (user request: "اونجا باید درست باشه") and encrypt only on
            # the wire (per-session AES via /api/mobile/connection/encrypted).
            # ENC: is also supported for at-rest encryption when desired.
            # Both plain and ENC: are allowed here for the dev localhost
            # connection string; production secrets must be injected via
            # TARAZIN_SQL_CONNECTION env var and never committed.
            if relative == "Tarazin.Web/appsettings.json" and leaf == "defaultconnection":
                if isinstance(value, str) and (value.startswith("ENC:") or "localhost" in value.lower() or "127.0.0.1" in value):
                    continue
                # Fall through to sensitive check for non-localhost plain values
                # (still blocked for real production hosts)
                if isinstance(value, str) and value.startswith("ENC:"):
                    continue
            if relative == "Tarazin.Web/appsettings.json" and leaf == "connectionstrings":
                if isinstance(value, dict):
                    child = value.get("DefaultConnection") or value.get("defaultconnection")
                    if isinstance(child, str) and (child.startswith("ENC:") or "localhost" in child.lower() or "127.0.0.1" in child.lower()):
                        continue
            sensitive_key = (
                leaf in {"password", "pwd", "secret", "token", "apikey", "api_key", "privatekey"}
                or "connectionstring" in leaf
            )
            if sensitive_key and value not in (None, "", [], {}):
                # Allow the ConnectionProtection key-holder (the key itself is
                # for dev; production must use TARAZIN_ENCRYPTION_KEY env var).
                # It is not a connection credential and is not flagged here;
                # plaintext connection strings are already blocked above.
                if leaf in {"key", "connectionprotection"}:
                    continue
                fail(errors, f"{relative}: tracked sensitive setting {key} must be absent/empty")


def require(path: str, patterns: Iterable[str], errors: list[str]) -> str:
    target = ROOT / path
    try:
        text = target.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        fail(errors, f"{path}: cannot verify required controls ({exc})")
        return ""
    for pattern in patterns:
        if not re.search(pattern, text, re.MULTILINE | re.DOTALL):
            fail(errors, f"{path}: required security control did not match: {pattern}")
    return text


def scan_source() -> list[str]:
    errors: list[str] = []
    scan_configuration(errors)

    for path in source_files():
        relative = path.relative_to(ROOT).as_posix()
        scan_generic_secret_bytes(relative, read_bytes(path), errors)

    maui_program = require("Tarazin.Maui/MauiProgram.cs", (
        r"GetManifestResourceStream\(\"Tarazin\.Maui\.appsettings\.json\"\)",
        r"TARAZIN_SERVER_ENDPOINT",
        r"AddSingleton<ISqlConnectionProvider>.*RemoteCredentialSession",
    ), errors)
    if re.search(r"TARAZIN_SQL_CONNECTION|GetConnectionString|ConnectionStrings", maui_program):
        fail(errors, "Tarazin.Maui/MauiProgram.cs must not load server SQL configuration")

    remote = require("Tarazin.Maui/RemoteCredentialSession.cs", (
        r"SemaphoreSlim\s+_lifecycleGate",
        r"api/mobile/connection/login",
        r"api/mobile/connection/refresh",
        r"api/mobile/connection/revoke",
        r"api/mobile/connection/encrypted",
        r'configuration\["CustomerGuid"\]',
        r"ConnectionStringProtector",
        r"FetchDecryptedMasterConnectionStringAsync",
        r"DeriveKeyFromToken",
        r"Encrypt\s*=\s*true",
        r"TrustServerCertificate\s*=\s*false",
        r"PersistSecurityInfo\s*=\s*false",
        r"RevokeCandidateResponseAsync",
        r"RandomNumberGenerator\.GetBytes",
        r"#if DEBUG.*Uri\.UriSchemeHttp.*endpoint\.IsLoopback.*#else.*return false",
    ), errors)
    for prohibited in (
        r"\bSecureStorage\s*\.", r"\bPreferences\s*\.", r"\bFile\.(?:Write|Append|Create)",
        r"localStorage", r"sessionStorage", r"SQLiteConnection", r"AddEnvironmentVariables\s*\(",
        r"ExtractCustomerGuidFromEndpoint", r"ConnectionStringPayload", r"FetchConnectionStringAsync",
        r"api/\{",
    ):
        if re.search(prohibited, remote, re.MULTILINE):
            fail(errors, f"RemoteCredentialSession uses prohibited secret persistence/config API: {prohibited}")

    for expected in (
        r"DataSource\s*=\s*credential\.Server",
        r"InitialCatalog\s*=\s*credential\.Database",
        r"UserID\s*=\s*credential\.Username",
        r"Password\s*=\s*credential\.Password",
        r"await RefreshIfNeededAsync\(ct\)",
    ):
        if not re.search(expected, remote, re.MULTILINE):
            fail(errors, f"RemoteCredentialSession must use the broker credential in memory: {expected}")

    require("Tarazin.Data/TarazinConnection.cs", (
        r"ConnectionStringProtector",
        r"IsEncrypted",
        r"TryDecryptIfNeeded",
        r"builder\.Encrypt\s*=\s*true",
        r"builder\.TrustServerCertificate\s*=\s*false",
        r"builder\.PersistSecurityInfo\s*=\s*false",
        r"catch \(ArgumentException\).*server-side SQL connection configuration is invalid",
    ), errors)
    web_program = require("Tarazin.Web/Program.cs", (
        r"MapGroup\(\"/api/mobile/connection\"\)",
        r"RequireRateLimiting\(\"credential-broker\"\)",
        r"!http\.Request\.IsHttps\s*&&\s*!app\.Environment\.IsDevelopment\(\)",
        r"CacheControl\s*=\s*\"no-store, no-cache, max-age=0\"",
        r"RequestSizeLimitAttribute",
        r"KnownNetworks\.Clear\(\).*KnownProxies\.Clear\(\)",
        r"MapPost\(\"/encrypted\"",
        r"GetEncryptedConnectionAsync",
    ), errors)
    if re.search(r"\b(?:Add|Map)Controllers\s*\(", web_program):
        fail(errors, "Tarazin.Web/Program.cs must not expose a controller-based credential endpoint")
    if (ROOT / "Tarazin.Web/Controllers/ConnectionController.cs").exists():
        fail(errors, "ConnectionController must not expose a permanent SQL connection to MAUI")
    require("Tarazin.Web/CredentialBrokerService.cs", (
        r"PasswordHasher\.Verify\(request\.Password",
        r"CredentialCustomers",
        r"CredentialAccessEnabled",
        r"IsAuthorized",
        r"ConsumeNonceAsync",
        r"TokenHash\s*=\s*Sha256",
        r"TimeSpan\.FromMinutes\(Clamp\(configuration, \"CredentialBroker:CredentialLifetimeMinutes\", 5, 2, 15\)\)",
        r"SessionFamilyId",
        r"ActivatedAt",
        r"sp_getapplock",
        r"MarkFamilyRevokedAsync",
        r"IsolationLevel\.Serializable",
        r"ALTER LOGIN .* DISABLE",
        r"KILL ",
        r"TrustServerCertificate\s*=\s*false",
        r"ValidatePublicServer",
        r"GetEncryptedConnectionAsync",
        r"ConnectionStringProtector",
        r"DeriveKeyFromToken",
        r"EncryptedConnectionRequest",
    ), errors)
    require("Tarazin.Maui/Platforms/Android/AndroidManifest.xml", (
        r"android:allowBackup=\"false\"",
        r"android:usesCleartextTraffic=\"false\"",
    ), errors)
    require("Tarazin.Data/Scripts/central/_Ensure.sql", (
        r"SessionFamilyId",
        r"ActivatedAt",
        r"IX_MobileCredentialSessions_Family",
        r"Tarazin\.SecurityDefinitionVersion",
    ), errors)
    require("Tarazin.Data/Scripts/central/_MobileSecurity.sql", (
        r"SET XACT_ABORT ON",
        r"BEGIN TRANSACTION",
        r"CredentialAccessEnabled\s*=\s*1",
        r"ActivatedAt\s+IS\s+NOT\s+NULL",
        r"fn_MobileCompanyRowAccess",
        r"trg_MobileUsersAuthorization",
        r"trg_MobileRolesAuthorization",
        r"trg_MobileRolePermissionsAuthorization",
        r"CREATE SECURITY POLICY",
    ), errors)
    for audit_script in (
        "Tarazin.Data/Scripts/central/AuditInsert.sql",
        "Tarazin.Data/Scripts/central/AuditLastRowHash.sql",
    ):
        require(audit_script, (
            r"ORIGINAL_LOGIN\(\)\s+LIKE\s+N'tz_m\[_\]%'",
            r"\[central\]\.\[fn_MobileCompanyId\]\(\)",
        ), errors)

    # Logging must not interpolate raw exception messages or known secret variables.
    log_call = re.compile(r"\b(?:_logger|logger|app\.Logger)\.Log\w+\s*\((.*?)\);", re.DOTALL)
    for relative in ("Tarazin.Web/Program.cs", "Tarazin.Web/CredentialBrokerService.cs",
                     "Tarazin.Web/CredentialCleanupService.cs", "Tarazin.Data/DbService.cs",
                     "Tarazin.Data/AuditService.cs"):
        text = (ROOT / relative).read_text(encoding="utf-8")
        for match in log_call.finditer(text):
            call = match.group(1)
            if re.search(r"\bex\.Message\b|\b(?:password|bearerToken|sessionToken|_sessionToken|_issuerConnectionString|_connectionString)\b", call):
                line = text.count("\n", 0, match.start()) + 1
                fail(errors, f"{relative}:{line}: logging call may include sensitive material")

    return errors


def iter_artifact_payloads(root: Path) -> Iterable[tuple[str, bytes]]:
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if FIRST_PARTY_ARTIFACT.match(path.name):
            yield str(path), read_bytes(path)
            continue
        if path.suffix.lower() in {".apk", ".zip", ".msix", ".appx"}:
            try:
                with zipfile.ZipFile(path) as archive:
                    for name in archive.namelist():
                        if FIRST_PARTY_ARTIFACT.match(Path(name).name):
                            yield f"{path}!{name}", archive.read(name)
            except (OSError, zipfile.BadZipFile, KeyError) as exc:
                raise RuntimeError(f"cannot inspect archive {path}: {exc}") from exc


def scan_artifacts(root: Path) -> list[str]:
    errors: list[str] = []
    if not root.exists() or not root.is_dir():
        return [f"artifact directory does not exist: {root}"]
    payloads = list(iter_artifact_payloads(root))
    if not payloads:
        return [f"no first-party MAUI assemblies/settings found under artifact directory: {root}"]
    for label, data in payloads:
        scan_generic_secret_bytes(label, data, errors)
    return errors


def self_test() -> list[str]:
    errors: list[str] = []
    malicious = (
        b"Server=db.internal;Initial Catalog=Prod;User Id=app;Password=VerySecret123!;",
        b"Data Source=db;UID=mobile;PWD=Permanent42;Encrypt=true;",
        b"-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----",
        b"TrustServerCertificate=true",
        b"Encrypt=false",
    )
    for index, fixture in enumerate(malicious):
        fixture_errors: list[str] = []
        scan_generic_secret_bytes(f"fixture-{index}", fixture, fixture_errors)
        if not fixture_errors:
            fail(errors, f"self-test fixture {index} was not detected")

    benign = (
        b'{"ServerEndpoint":"https://api.example.invalid/"}',
        b"builder.Password = value.Password; builder.Encrypt = true; builder.TrustServerCertificate = false;",
        b"MSSQL_SA_PASSWORD=${MSSQL_SA_PASSWORD:?Set an external secret}",
    )
    for index, fixture in enumerate(benign):
        fixture_errors = []
        scan_generic_secret_bytes(f"benign-{index}", fixture, fixture_errors)
        if fixture_errors:
            fail(errors, f"self-test benign fixture {index} produced false positive: {fixture_errors}")

    with tempfile.TemporaryDirectory() as temp:
        empty = scan_artifacts(Path(temp))
        if not empty:
            fail(errors, "self-test artifact scan incorrectly accepted an empty directory")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifact", type=Path, help="scan built/published MAUI output")
    parser.add_argument("--self-test", action="store_true", help="exercise malicious/benign scanner fixtures")
    args = parser.parse_args()

    errors: list[str] = []
    if args.self_test:
        errors.extend(self_test())
    if args.artifact is not None:
        errors.extend(scan_artifacts(args.artifact.resolve()))
    else:
        errors.extend(scan_source())

    if errors:
        print("Security regression scan FAILED:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    mode = f"artifacts under {args.artifact}" if args.artifact else "tracked and untracked source/configuration"
    print(f"Security regression scan passed: {mode}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
