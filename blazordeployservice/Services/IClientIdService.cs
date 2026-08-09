
using System.Threading.Tasks;

namespace BlazorDeployService.Services
{

    public interface IClientIdService
    {
        /// <summary>
        /// دریافت شناسه کاربر - اگر وجود نداشت ایجاد می‌کند
        /// </summary>
        Task<string> GetClientIdAsync();

        /// <summary>
        /// آیا localStorage پاک شده است؟
        /// </summary>
        bool WasStorageCleared { get; }

        /// <summary>
        /// دلیل پاک شدن storage
        /// </summary>
        string StorageClearReason { get; }

        /// <summary>
        /// رویداد هنگام پاک شدن storage
        /// </summary>
        event System.EventHandler<StorageClearedEventArgs> StorageCleared;
    }

    public class StorageClearedEventArgs : System.EventArgs
    {
        public string Reason { get; set; }
        public System.DateTime ClearedAt { get; set; }
        public string PreviousClientId { get; set; }
    }
}

