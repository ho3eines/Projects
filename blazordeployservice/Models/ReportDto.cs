using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BlazorDeployService.Models
{
    public class ReportDto
    {
        public DateTime dateTime { set; get; }
        public string ReportPath { set; get; }
        public DataTable dt { set; get; }
        public string UserCode { set; get; }

    }
}
