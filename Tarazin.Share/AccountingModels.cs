namespace Tarazin.Models;

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

/// <summary>دفتر روزنامه — ردیف‌های سند در بازهٔ تاریخ.</summary>
public class DailyBookRow
{
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
