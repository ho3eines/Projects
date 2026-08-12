namespace WebApi.Models;

public class ModalModel
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public Type ComponentType { get; set; } = null!;
    public string Title { get; set; } = string.Empty;
    public Dictionary<string, object> Parameters { get; set; } = new();
    public bool CloseButton { get; set; } = true;
    public bool Show { get; set; }
    public string ModalSize { get; set; } = "modal-lg";
}