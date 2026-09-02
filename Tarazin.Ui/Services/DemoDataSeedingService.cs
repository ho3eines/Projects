using System.Diagnostics;
using System.Text;

namespace Tarazin.Services;

/// <summary>
/// اجرای اسکریپت seed-demo-data.sh --reseed از داخل برنامه (خلاصه‌نویسیِ مسیر
/// اختصاصی‌سازی: پاک‌سازی sample + سید مجدد idempotent). دادهٔ سید اصلی لمس نمی‌شود.
/// </summary>
public sealed class DemoDataSeedingService
{
    private static readonly object Gate = new();

    /// <summary>اجرای هم‌زمانِ `seed-demo-data.sh --reseed` و برگرداندن نتیجه برای نمایش.</summary>
    public async Task<ReseedResult> RunReseedAsync(CancellationToken ct = default)
    {
        lock (Gate)
        {
            string repo = FindRepoRoot();
            var script = Path.Combine(repo, "tools", "seed-demo-data.sh");
            if (!File.Exists(script))
                return new ReseedResult { Ok = false, Output = $"seed script not found: {script}" };

            var psi = new ProcessStartInfo
            {
                FileName = "bash",
                WorkingDirectory = repo,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            psi.ArgumentList.Add("tools/seed-demo-data.sh");
            psi.ArgumentList.Add("--reseed");

            using var proc = Process.Start(psi);
            if (proc is null)
                return new ReseedResult { Ok = false, Output = "cannot start seed script" };

            string stdout = proc.StandardOutput.ReadToEnd();
            string stderr = proc.StandardError.ReadToEnd();
            proc.WaitForExit(240_000);
            string output = (stdout + stderr).Trim();
            return new ReseedResult
            {
                Ok = proc.ExitCode == 0 && stdout.Contains("Demo data seeded"),
                ExitCode = proc.ExitCode,
                Output = output
            };
        }
    }

    private static string FindRepoRoot()
    {
        string current = Directory.GetCurrentDirectory();
        // ۱) از ریشهٔ solution اجرا شده
        if (Directory.Exists(Path.Combine(current, "Tarazin.Web")) && Directory.Exists(Path.Combine(current, "tools")))
            return current;
        // ۲) داخل پوشهٔ Tarazin.Web اجرا شده → والد
        if (File.Exists(Path.Combine(current, "Tarazin.Web.csproj")))
        {
            string parent = Path.GetDirectoryName(current) ?? current;
            if (Directory.Exists(Path.Combine(parent, "tools")))
                return parent;
        }
        // ۳) fallback: چند سطح بالا برو
        var dir = new DirectoryInfo(current);
        for (int i = 0; i < 5 && dir is not null; i++, dir = dir.Parent)
        {
            if (Directory.Exists(Path.Combine(dir.FullName, "tools")))
                return dir.FullName;
        }
        return current;
    }
}

public sealed class ReseedResult
{
    public bool Ok { get; set; }
    public int ExitCode { get; set; }
    public string Output { get; set; } = "";
    public DateTimeOffset Timestamp { get; set; } = DateTimeOffset.Now;
}