using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Tarazin.Data;
using Xunit;

namespace Tarazin.Tests;

/// <summary>
/// زیرساخت مشترک تست‌های DBدار — اتصال، بازکردن با Skip، تقسیم بچ‌های `GO` و
/// اطمینان از اسکیمای ماژول چاپ. طوری که هر تست DBدار این‌ها را تکرار نکند.
///
/// Skip پویا با پکیج «xunit.skippablefact»: تست‌های DBدار باید `[SkippableFact]`
/// باشند (نه `[Fact]`) و وقتی SQL Server در دسترس نیست `Xunit.SkipException`
/// پرتاب می‌شود → تست Skipped می‌شود نه Fail.
/// </summary>
public static class TestDb
{
    /// <summary>
    /// اتصال به دیتابیس واقعی تست (همان String که هاست استفاده می‌کند).
    /// با env var «TARAZIN_TEST_CONN» قابل بازنویسی است — CI با SQL Server
    /// کانتینری (رمز قوی) آن را ست می‌کند؛ پیش‌فرض = سرور محلی توسعه.
    /// </summary>
    public static string ConnectionString =>
        Environment.GetEnvironmentVariable("TARAZIN_TEST_CONN")
        ?? "Server=localhost;Database=TarazinMaster;User Id=sa;Password=123456;TrustServerCertificate=True;Encrypt=False";

    /// <summary>
    /// بازکردن اتصال به SQL Server؛ اگر در دسترس نبود (مثلاً CI)
    /// <see cref="Xunit.SkipException"/> پرتاب می‌شود تا تست Skip شود نه Fail.
    /// </summary>
    public static async Task<SqlConnection> OpenOrSkipAsync()
    {
        var cn = new SqlConnection(ConnectionString);
        try { await cn.OpenAsync(); }
        catch (Exception ex)
        {
            await cn.DisposeAsync();
            throw new SkipException($"SQL Server در دسترس نیست: {ex.Message}");
        }
        return cn;
    }

    /// <summary>
    /// تقسیم اسکریپت به بچ‌ها روی خط‌های خالص `GO` — چون SqlCommand/Dapper
    /// جداکنندهٔ بچِ SQL Server را نمی‌فهمد و _Ensure ها شامل `GO` هستند.
    /// </summary>
    public static IEnumerable<string> SplitBatches(string sql)
    {
        var lines = sql.Split('\n');
        var current = new StringBuilder();
        foreach (var line in lines)
        {
            var trimmed = line.TrimEnd('\r').Trim();
            if (string.Equals(trimmed, "GO", StringComparison.OrdinalIgnoreCase))
            {
                if (current.Length > 0) { yield return current.ToString(); current.Clear(); }
            }
            else
            {
                current.AppendLine(line);
            }
        }
        if (current.Length > 0) yield return current.ToString();
    }

    /// <summary>اجرای idempotentِ اسکریپتِ واقعی <c>printing._Ensure</c> (اسکیما + مهاجرت‌ها).</summary>
    public static async Task EnsurePrintingAsync(SqlConnection cn)
    {
        var catalog = new ScriptCatalog();
        Assert.True(catalog.TryGet("printing", "_Ensure", out var ensure), "printing._Ensure script not found");
        foreach (var batch in SplitBatches(ensure))
            await cn.ExecuteAsync(batch);
    }
}
