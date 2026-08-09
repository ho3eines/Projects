using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BlazorDeployService.Models
{
    public class VerifyResult
    {
        public int code { get; set; }
        public string? message { get; set; }
        public string? requestToken { get; set; }
        public string? encryptionkey { get; set; }
    }

    public class Verify
    {
        public string requestDate { set; get; }
        public string? requestToken { set; get; }
        public string? encryptionkey { set; get; }
        public string? responsedate { set; get; }
    }
}
