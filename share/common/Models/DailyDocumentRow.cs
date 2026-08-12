namespace Share.Models;

public class DailyDocumentRow
{
    public int DocumentId { get; set; }
    public string DocumentNumber { get; set; } = "";
    public DateTime DocumentDate { get; set; }
    public string? DocumentType { get; set; }
    public string? CounterPartyName { get; set; }
    public decimal TotalAmount { get; set; }
    public string? CurrencyCode { get; set; }
    public string? Status { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class UserRow
{
    public int UserId { get; set; }
    public string Username { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public string Role { get; set; } = "";
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
}
