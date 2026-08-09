using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using static System.Runtime.InteropServices.JavaScript.JSType;

namespace BlazorDeployService.Models
{

    public class RequestDataTable
    {
        public string Token { get; set; }
        public DataTable Data { get; set; }
        public string RequestDate { get; set; }
    }
}
