using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BlazorDeployService.Models
{
    public class ApiSettings
    {
        public string BaseUrl { get; set; } = string.Empty;
        public int Timeout { get; set; } = 30000;
        public string APIKey { get; set; } = string.Empty;
        public string Encryption { get; set; } = string.Empty;
        public string ConnectionStringToken { get; set; } = string.Empty;
    }

    public class EncryptionSettings
    {
        public bool Enabled { get; set; } = false;
        public string Key { get; set; } = string.Empty;
    }
    public class LocalizationSettings
    {
        public List<string> SupportedLanguageCodes { get; set; } = new List<string>();
        public string DefaultLanguage { get; set; } = "fa-IR";
        public bool EnableAutoDetection { get; set; } = true;
    }
    
    public class AppSettings
    {
        public ApiSettings ApiSettings { get; set; } = new();
        public EncryptionSettings Encryption { get; set; } = new();
        public LocalizationSettings Localization { get; set; } = new(); 
    }
}

