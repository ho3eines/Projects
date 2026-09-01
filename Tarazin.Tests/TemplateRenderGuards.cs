using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Tarazin.Models;
using Tarazin.Services;
using Xunit;

namespace Tarazin.Tests;

/// <summary>
/// دود تست موتور چاپ عمومی: برای همهٔ قالب‌های پیش‌فرض (چک‌ها، سند،
/// فهرست اسناد، انبار، حقوق، طلا، فروشگاه) PDF ساخته می‌شود تا:
///  ۱) هیچ قالب/ستونی باعث استثنای زمان ساخت نشود (باگ هدرِ بدون .Text
///     خاموش بود و فقط با بازرسی ساختاری (pymupdf) دیده می‌شد)،
///  ۲) خروجی برای بازرسی بصری/ساختاری برون‌ریزی شود.
/// </summary>
public class TemplateRenderGuards
{
    /// <summary>
    /// همهٔ قالب‌های سیستمی با دادهٔ واقعی نمونه هم از رندرر HTML (PrintSheetRenderer)
    /// و هم از رندرر QuestPDF (BuildTemplatePdf) باید بدون خطا رندر شوند؛ و html باید
    /// عنوان گزارش و همهٔ عنوان ستون‌ها را داشته باشد (نگهبان «هدر فراموش‌شده»).
    /// </summary>
    [Theory]
    [InlineData("treasury.cheques")]
    [InlineData("accounting.document")]
    [InlineData("accounting.documents")]
    [InlineData("inventory.balances")]
    [InlineData("inventory.card")]
    [InlineData("payroll.runs")]
    [InlineData("payroll.slips")]
    [InlineData("goldshop.sales")]
    [InlineData("goldshop.prices")]
    [InlineData("store.orders")]
    public void Template_renders_html_and_pdf(string id)
    {
        var svc = new PdfReportService();
        var tpl = PrintTemplates.Defaults.Get(id);
        var data = BuildSample(tpl);

        // ── رندرر HTML (پیش‌نمایش/چاپ مرورگر) ──
        var html = PrintSheetRenderer.BuildHtml(tpl, data);
        Assert.False(string.IsNullOrWhiteSpace(html), $"{id}: HTML empty");
        Assert.Contains(tpl.ReportTitle ?? "", html);   // عنوان گزارش حاضر است
        foreach (var col in tpl.Columns)
        {
            Assert.Contains(col.Title, html);           // هدرِ هر ستون حاضر است
        }

        // ── رندرر QuestPDF (سمت سرور/MAUI) ──
        var bytes = svc.BuildTemplatePdf(tpl, data);
        Assert.True(bytes.Length > 1000, $"{id}: PDF too small ({bytes.Length})");

        // برون‌ریزی برای بازرسی ساختاری/بصری (pymupdf)
        var dir = Path.Combine(Path.GetTempPath(), "tarazin-pdf", "all");
        Directory.CreateDirectory(dir);
        File.WriteAllBytes(Path.Combine(dir, id.Replace('.', '_') + ".pdf"), bytes);
    }

    private static PrintDataModel BuildSample(PrintTemplateDef tpl)
    {
        var data = new PrintDataModel
        {
            Title = tpl.ReportTitle,
            Subtitle = tpl.ReportSubtitle,
            RangeText = "از 1405/05/07 تا 1405/06/07",
            CompanyName = "ترازین — سامانه یکپارچه مدیریت کسب‌وکار",
            CompanyAddress = "تهران، خیابان آزادی",
            MetaFields = tpl.MetaFields.Select(m => new PrintMetaField
            {
                Label = m.Label,
                Value = m.Label switch
                {
                    "بازه" => "1405/05/07 تا 1405/06/07",
                    "تعداد اقلام" => "5",
                    "تعداد فاکتور" => "16",
                    "تعداد دوره‌ها" => "1",
                    "تعداد سفارش" => "5",
                    "تعداد اسناد" => "18",
                    "جمع فروش" => "818,462,396,21",
                    "جمع مبلغ" => "354,000,000",
                    "جمع کل" => "2,100,000,000",
                    "انبار" => "انبار اصلی",
                    "شرکت" => "ترازین",
                    "وضعیت" => "در جریان",
                    _ => "—"
                }
            }).ToList(),
            FooterFields = new List<PrintMetaField>()
        };

        for (var i = 1; i <= 4; i++)
        {
            var row = new PrintRow();
            foreach (var col in tpl.Columns)
            {
                row[col.Key] = SampleValue(col.Key, i);
            }
            data.Rows.Add(row);
        }
        return data;
    }

    private static object SampleValue(string key, int i) => key switch
    {
        "ChequeNumber" => $"CHQ-{i:00000}",
        "BankName" => "بانک صادرات ایران",
        "Direction" => "دریافتی",
        "StatusTitle" => "در انتظار",
        "DueDate" => "1405/06/02",
        "AlertTitle" => "سررسیدشده",
        "Amount" => 500000000m + i,
        "SourceReference" => "دستی",
        "AccountCode" => $"10{i}0",
        "Title" => "عنوان نمونه",
        "Debit" => 1000000m * i,
        "Credit" => 1000000m * i,
        "DocumentNumber" => $"0000000{i}",
        "DocumentDate" => "1405/06/02",
        "DocumentType" => "سند روزنامه",
        "CounterPartyName" => "مشتری نمونه",
        "TotalAmount" => 25000000m * i,
        "ItemCode" => $"ITM-{i}",
        "ItemTitle" => "کالای نمونه",
        "Unit" => "عدد",
        "WarehouseName" => "انبار اصلی",
        "SubWarehouseName" => "انبارک ۱",
        "StockQty" => 10m * i,
        "UnitPrice" => 50000m,
        "StockValue" => 500000m * i,
        "MovementDate" => "1405/06/02",
        "MovementNumber" => $"MV-{i}",
        "MovementType" => "دریافت",
        "InQty" => 5m * i,
        "OutQty" => 2m * i,
        "CostPrice" => 100000m,
        "BalanceQty" => 3m * i,
        "BalanceValue" => 300000m * i,
        "Description" => "شرح نمونه",
        "Period" => "1405-04",
        "EmployeeCount" => 3,
        "NetTotal" => 281400000m,
        "CreatedAt" => "1405/06/07",
        "EmployeeId" => "EMP-001",
        "EmployeeName" => "کارمند نمونه",
        "NetPay" => 93800000m,
        "InvoiceNumber" => $"GINV-{i:00000}",
        "InvoiceDate" => "1405/06/03",
        "CustomerName" => "مشتری طلا",
        "WeightGram" => 4.5m,
        "Workmanship" => 2500000m,
        "Profit" => 1800000m,
        "Tax" => 450000m,
        "PricePerGram" => 32500000m,
        "UpdatedAt" => "1405/06/07",
        "OrderNumber" => $"ORD-{i:00000}",
        "OrderDate" => "1405/06/06",
        "ItemCount" => 2,
        _ => "—"
    };
}
