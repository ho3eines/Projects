using System;
using System.Collections.Generic;
using System.Linq;

namespace Tarazin.Models;

/// <summary>یک ردیف چاپ پیشرفتهٔ سند — سطح ۰=کل، ۱=معین، ۲=تفصیل.</summary>
public class AdvancedPrintRow
{
    public int Level { get; set; }
    public string Code { get; set; } = "";
    public string Title { get; set; } = "";
    public int LineCount { get; set; }
    public decimal Debit { get; set; }
    public decimal Credit { get; set; }
}

/// <summary>
/// سازندهٔ ردیف‌های تودرتوی چاپ پیشرفتهٔ سند (کل ← معین ← تفصیل) — منبع واحدِ حقیقت
/// که هم دیالوگ (DocumentPrintDialog)، هم PDF (PdfReportService) و هم گاردهای تست
/// باید آن را صدا بزنند (نه کپی منطق). ترتیب هر ردیف — کل، سپس معین‌هایش به‌ترتیب کد،
/// سپس تفصیل‌های هر معین، بدون ردیف خارجی بینشان — و جمع هر سطح از اینجا می‌آید.
/// </summary>
public static class AdvancedDocRowsBuilder
{
    public static List<AdvancedPrintRow> Build(
        IEnumerable<AccountRollupRow>? kols,
        IEnumerable<AccountRollupRow>? moeins,
        IEnumerable<DocumentLineRow>? lines)
    {
        var result = new List<AdvancedPrintRow>();
        var allLines = (lines ?? Enumerable.Empty<DocumentLineRow>()).ToList();
        var kolList = kols?.ToList() ?? new List<AccountRollupRow>();
        var moeinList = moeins?.ToList() ?? new List<AccountRollupRow>();

        // اگر رول‌آپ کل خالی بود (عنوان‌ها از اسکریپت نیامده‌اند) از روی ردیف‌ها تجمیع کن.
        if (kolList.Count == 0)
        {
            kolList = allLines
                .GroupBy(l => l.AccountCode.Length >= 2 ? l.AccountCode[..2] : l.AccountCode)
                .Select(g => new AccountRollupRow
                {
                    Code = g.Key,
                    Title = g.First().Title,
                    Debit = g.Sum(x => x.Debit),
                    Credit = g.Sum(x => x.Credit),
                    LineCount = g.Count()
                }).ToList();
        }

        foreach (var kol in kolList.OrderBy(k => k.Code, StringComparer.Ordinal))
        {
            var moeinsOfKol = (moeinList.Count > 0 ? moeinList : new List<AccountRollupRow>())
                .Where(m => m.Code.Length >= 2 && m.Code.StartsWith(kol.Code, StringComparison.Ordinal))
                .OrderBy(m => m.Code, StringComparer.Ordinal).ToList();

            // اگر رول‌آپ معین هم خالی بود، از روی ردیف‌های زیر همین کل تجمیع کن.
            if (moeinsOfKol.Count == 0)
            {
                moeinsOfKol = allLines
                    .Where(l => l.AccountCode.StartsWith(kol.Code, StringComparison.Ordinal))
                    .GroupBy(l => l.AccountCode.Length >= 5 ? l.AccountCode[..5] : l.AccountCode)
                    .Select(g => new AccountRollupRow
                    {
                        Code = g.Key,
                        Title = g.First().Title,
                        Debit = g.Sum(x => x.Debit),
                        Credit = g.Sum(x => x.Credit),
                        LineCount = g.Count()
                    }).OrderBy(m => m.Code, StringComparer.Ordinal).ToList();
            }

            decimal kolDebit = 0, kolCredit = 0;
            int kolCount = 0;
            var moeinBlock = new List<AdvancedPrintRow>();

            foreach (var moein in moeinsOfKol)
            {
                var moeinLines = allLines
                    .Where(l => l.AccountCode.StartsWith(moein.Code, StringComparison.Ordinal))
                    .OrderBy(l => l.AccountCode, StringComparer.Ordinal).ToList();
                var mDebit = moeinLines.Sum(l => l.Debit);
                var mCredit = moeinLines.Sum(l => l.Credit);
                kolDebit += mDebit; kolCredit += mCredit; kolCount += moeinLines.Count;

                moeinBlock.Add(new AdvancedPrintRow
                {
                    Level = 1, Code = moein.Code, Title = moein.Title,
                    Debit = mDebit, Credit = mCredit, LineCount = moeinLines.Count
                });

                foreach (var line in moeinLines)
                {
                    moeinBlock.Add(new AdvancedPrintRow
                    {
                        Level = 2, Code = line.AccountCode,
                        Title = string.IsNullOrWhiteSpace(line.Description)
                            ? line.Title
                            : $"{line.Title} — {line.Description}",
                        Debit = line.Debit, Credit = line.Credit, LineCount = 0
                    });
                }
            }

            result.Add(new AdvancedPrintRow
            {
                Level = 0, Code = kol.Code, Title = kol.Title,
                Debit = kolDebit, Credit = kolCredit, LineCount = kolCount
            });
            result.AddRange(moeinBlock);
        }
        return result;
    }
}