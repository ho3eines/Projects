using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Dapper;
using Tarazin.Data;
using Tarazin.Models;
using Tarazin.Services;
using Xunit;

namespace Tarazin.Tests;

public sealed class DumpLiveDocPdf
{
    [SkippableFact]
    public async Task Dump_doc519_advanced_pdf()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        var catalog = new ScriptCatalog();
        const int docId = 519;

        var cid = await cn.ExecuteScalarAsync<int>(
            "SELECT TOP 1 CompanyId FROM accounting.Documents WHERE DocumentId=@id;", new { id = docId });
        var fid = await cn.ExecuteScalarAsync<int?>(
            "SELECT TOP 1 FiscalYearId FROM central.FiscalYears WHERE CompanyId=@c ORDER BY [FromDate] DESC;",
            new { c = cid });

        string Sql(string schema, string name)
        {
            Assert.True(catalog.TryGet(schema, name, out var sql), $"{schema}/{name} not found");
            return sql!;
        }

        var doc = await cn.QueryFirstOrDefaultAsync<LiveDoc>(Sql("accounting", "DocumentById"),
            new { DocumentId = docId, CompanyId = cid, FiscalYearId = fid });
        var lines = (await cn.QueryAsync<DocumentLineRow>(Sql("accounting", "DocumentLines"),
            new { DocumentId = docId, CompanyId = cid, FiscalYearId = fid })).ToList();
        var rollup = (await cn.QueryAsync<DocumentRollupTitleRow>(Sql("accounting", "DocumentPrintRollup"),
            new { DocumentId = docId, CompanyId = cid })).ToList();
        var settings = await cn.QueryFirstOrDefaultAsync<CompanyAccountSettingsRow>(
            Sql("accounting", "CompanyAccountSettingsGet"), new { CompanyId = cid });

        var model = new AccountingDocumentPrintModel
        {
            DocumentId = docId,
            DocumentNumber = doc?.DocumentNumber ?? docId.ToString(),
            DocumentDate = doc?.DocumentDate ?? DateTime.Today,
            DocumentType = doc?.DocumentType,
            CounterPartyName = doc?.CounterPartyName,
            TotalAmount = doc?.TotalAmount ?? lines.Sum(l => l.Debit),
            BrandName = settings?.CompanyName,
            QrBaseUrl = settings?.QrBaseUrl,
            Lines = lines,
            Advanced = true,
            KolRows = rollup.Where(r => r.Level == "Kol")
                .Select(r => new AccountRollupRow { Code = r.Code, Title = r.Title ?? "—", LineCount = r.LineCount, Debit = r.Debit, Credit = r.Credit })
                .ToList(),
            MoeinRows = rollup.Where(r => r.Level == "Moein")
                .Select(r => new AccountRollupRow { Code = r.Code, Title = r.Title ?? "—", LineCount = r.LineCount, Debit = r.Debit, Credit = r.Credit })
                .ToList(),
        };

        var pdf = new PdfReportService();
        var bytes = pdf.BuildDocumentPdf(model, "A4");
        var dir = Path.Combine(Path.GetTempPath(), "tarazin-pdf");
        Directory.CreateDirectory(dir);
        File.WriteAllBytes(Path.Combine(dir, "live-doc519-advanced-A4.pdf"), bytes);

        model.Advanced = false;
        var simple = pdf.BuildDocumentPdf(model, "A4");
        File.WriteAllBytes(Path.Combine(dir, "live-doc519-simple-A4.pdf"), simple);

        File.WriteAllText(Path.Combine(dir, "live-doc519-rollup.txt"),
            string.Join("\n", rollup.Select(r => $"{r.Level}|{r.Code}|{r.Title}|{r.Debit}|{r.Credit}")));

        Assert.True(bytes.Length > 1000);
    }

    private sealed class LiveDoc
    {
        public string? DocumentNumber { get; set; }
        public DateTime DocumentDate { get; set; }
        public string? DocumentType { get; set; }
        public string? CounterPartyName { get; set; }
        public decimal TotalAmount { get; set; }
    }
}