namespace Tarazin.Services;

/// <summary>
/// ستون جدول PDF عمومی (خط لولهٔ مشترک همهٔ گزارش‌ها — اسکیل tarazin-reporting).
/// صفحهٔ گزارش ستون‌ها را تعریف و ردیف‌ها را به رشتهٔ آماده تبدیل می‌کند و
/// با <see cref="PdfReportService.BuildTablePdf"/> خروجی می‌گیرد.
/// </summary>
public sealed class TableReportColumn
{
    public required string Header { get; init; }

    /// <summary>ستون عددی → تراز راست. پیش‌فرض: راست.</summary>
    public bool AlignRight { get; init; } = true;
}
