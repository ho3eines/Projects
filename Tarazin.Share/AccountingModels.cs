namespace Tarazin.Models;

/// <summary>
/// وضعیت‌های سند حسابداری (چرخهٔ حیات سند).
///
/// مقادیر ذخیره‌شده در ستون <c>[accounting].[Documents].Status</c> همان مقادیر
/// تاریخیِ پروژه‌اند تا داده و گزارش‌های موجود (BI با <c>Posted</c> و بستن دوره
/// با <c>Closed</c>) نشکنند؛ فقط عنوان فارسی و ترتیب چرخه به آن‌ها اضافه شده است:
///   یادداشت (Note) → سند موقت (Draft) → تأیید شده (Posted) → تأیید نهایی (Closed)
/// </summary>
public static class AccountingDocumentStatus
{
    public const string Note = "Note";        // یادداشت
    public const string Draft = "Draft";      // سند موقت
    public const string Confirmed = "Posted"; // تأیید شده
    public const string Finalized = "Closed"; // تأیید نهایی

    /// <summary>ترتیب چرخهٔ وضعیت (از پایین به بالا).</summary>
    public static readonly string[] Ordered = [Note, Draft, Confirmed, Finalized];

    /// <summary>عنوان فارسی وضعیت.</summary>
    public static string Title(string? status) => Normalize(status) switch
    {
        Note => "یادداشت",
        Draft => "سند موقت",
        Confirmed => "تأیید شده",
        Finalized => "تأیید نهایی",
        _ => status ?? ""
    };

    /// <summary>مقدار معتبر وضعیت؛ مقادیر ناشناخته «سند موقت» در نظر گرفته می‌شوند.</summary>
    public static string Normalize(string? status)
    {
        var s = (status ?? "").Trim();
        foreach (var known in Ordered)
        {
            if (string.Equals(known, s, StringComparison.OrdinalIgnoreCase))
                return known;
        }
        return Draft;
    }

    /// <summary>ویرایش سند فقط در «یادداشت» و «سند موقت» مجاز است.</summary>
    public static bool IsEditable(string? status)
    {
        var s = Normalize(status);
        return s is Note or Draft;
    }

    /// <summary>وضعیت بعدی در چرخه (NULL اگر آخرین وضعیت باشد).</summary>
    public static string? Next(string? status)
    {
        var idx = Array.IndexOf(Ordered, Normalize(status));
        return idx >= 0 && idx < Ordered.Length - 1 ? Ordered[idx + 1] : null;
    }

    /// <summary>وضعیت قبلی در چرخه (NULL اگر اولین وضعیت باشد).</summary>
    public static string? Previous(string? status)
    {
        var idx = Array.IndexOf(Ordered, Normalize(status));
        return idx > 0 ? Ordered[idx - 1] : null;
    }

    /// <summary>
    /// دسترسی لازم برای رفتن از <paramref name="from"/> به <paramref name="to"/>.
    /// NULL یعنی این انتقال اصلاً مجاز نیست.
    /// </summary>
    public static string? PermissionFor(string? from, string? to)
    {
        var f = Normalize(from);
        var t = Normalize(to);
        if (f == t) return null;

        // پیشروی در چرخه — هر گام دسترسی خودش را دارد.
        if (t == Next(f))
        {
            return t switch
            {
                Draft => TarazinPermissions.DocumentDraft,
                Confirmed => TarazinPermissions.DocumentConfirm,
                Finalized => TarazinPermissions.DocumentFinalize,
                _ => null
            };
        }

        // برگشت یک گام — با دسترسی «برگشت وضعیت».
        if (t == Previous(f))
            return TarazinPermissions.DocumentRevert;

        return null;
    }
}

/// <summary>یک ردیف (بدهکار/بستانکار) در فرم ثبت سند روزنامه.</summary>
public class JournalLineRow
{
    public int AccountId { get; set; }
    public string AccountCode { get; set; } = "";
    public string AccountTitle { get; set; } = "";
    public string Description { get; set; } = "";
    public decimal Debit { get; set; }
    public decimal Credit { get; set; }
    /// <summary>نتیجهٔ انتخاب حساب از AccountPicker (برای استفاده در UI).</summary>
    public AccountPickerResult? PickedAccount { get; set; }
}

/// <summary>نتیجهٔ انتخاب از Account Picker (در Share تا در UI و Data قابل‌استفاده باشد).</summary>
public class AccountPickerResult
{
    public int Id { get; set; }
    public string Code { get; set; } = "";
    public string AccountCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string NodeType { get; set; } = "";
    public int? DetilEntityId { get; set; }
    public int? LinkId { get; set; }
    public int? MoeinId { get; set; }
}

/// <summary>یک ردیف ذخیره‌شدهٔ سند (از [accounting].[DocumentLines]).</summary>
public class DocumentLineRow
{
    public int DocumentLineId { get; set; }
    public int DocumentId { get; set; }
    public int AccountId { get; set; }
    public string AccountCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string? Description { get; set; }
    public decimal Debit { get; set; }
    public decimal Credit { get; set; }
}

/// <summary>دفتر روزنامه — ردیف‌های سند در بازهٔ تاریخ.</summary>
public class DailyBookRow
{
    public int DocumentLineId { get; set; }
    public int DocumentId { get; set; }
    public DateTime DocumentDate { get; set; }
    public string DocumentNumber { get; set; } = "";
    public string? DocumentType { get; set; }
    public string? CounterPartyName { get; set; }
    public string AccountCode { get; set; } = "";
    public string AccountTitle { get; set; } = "";
    public string? Description { get; set; }
    public decimal Debit { get; set; }
    public decimal Credit { get; set; }
    public decimal Balance { get; set; }
    public string? Status { get; set; }
}

/// <summary>دفتر کل — جمع و ماندهٔ هر حساب.</summary>
public class GeneralLedgerRow
{
    public int AccountId { get; set; }
    public string AccountCode { get; set; } = "";
    public string AccountTitle { get; set; } = "";
    public decimal Debit { get; set; }
    public decimal Credit { get; set; }
    public decimal Balance { get; set; }
}

/// <summary>تراز آزمایشی — ماندهٔ همهٔ حساب‌ها.</summary>
public class TrialBalanceRow
{
    public string AccountCode { get; set; } = "";
    public string AccountTitle { get; set; } = "";
    public string? AccountType { get; set; }
    public decimal Debit { get; set; }
    public decimal Credit { get; set; }
    public decimal Balance { get; set; }
}

/// <summary>یک سطح از گزارش سلسله‌مراتبی کل ← معین ← تفصیلی.</summary>
public class AccountingHierarchyRow
{
    public int NodeId { get; set; }
    public int Level { get; set; }
    public string Code { get; set; } = "";
    public string Title { get; set; } = "";
    public string NodeType { get; set; } = "";
    public int? ColId { get; set; }
    public int? MoeinId { get; set; }
    public int? DetilId { get; set; }
    public int? LinkId { get; set; }
    public string AccountCode { get; set; } = "";
    public string? AccountNature { get; set; }
    public decimal Debit { get; set; }
    public decimal Credit { get; set; }
    public decimal Balance { get; set; }
}

/// <summary>خلاصهٔ گردش یک تفصیلی در مسیر دقیق انتخاب‌شده.</summary>
public class DetailAccountSummaryRow
{
    public int DetilId { get; set; }
    public int LinkId { get; set; }
    public string AccountCode { get; set; } = "";
    public string DetilCode { get; set; } = "";
    public string DetilTitle { get; set; } = "";
    public int ColId { get; set; }
    public string ColCode { get; set; } = "";
    public string ColTitle { get; set; } = "";
    public int MoeinId { get; set; }
    public string MoeinCode { get; set; } = "";
    public string MoeinTitle { get; set; } = "";
    public decimal OpeningBalance { get; set; }
    public decimal Debit { get; set; }
    public decimal Credit { get; set; }
    public decimal FinalBalance { get; set; }
}

/// <summary>یک گردش بدهکار/بستانکار تفصیلی با ماندهٔ تجمعی.</summary>
public class DetailAccountTransactionRow
{
    public int DocumentLineId { get; set; }
    public int DocumentId { get; set; }
    public DateTime DocumentDate { get; set; }
    public string DocumentNumber { get; set; } = "";
    public string? DocumentType { get; set; }
    public string? DocumentDescription { get; set; }
    public string? LineDescription { get; set; }
    public string AccountCode { get; set; } = "";
    public string AccountTitle { get; set; } = "";
    public decimal Debit { get; set; }
    public decimal Credit { get; set; }
    public decimal Balance { get; set; }
    public string? Status { get; set; }
    public long TotalRows { get; set; }
}
