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

    public class Request
    {
        public string Token { get; set; }
        public string Data { get; set; }
        public string RequestDate { get; set; }
        public bool Exec { set; get; }
        public string userCode { set; get; }
    }
    public class requestV2
    {
        public string requestToken { get; set; }
        public string data { get; set; }
    }
    public class requestData
    {
        public string requestDate { get; set; }
        public string ConnectionStringToken { set; get; }
        public bool IsExec { set; get; }
        public string sqlstr { set; get; }
        public object? param { set; get; }
        public string? userCode { set; get; }
        public string ExpairDate { set; get; }
    }
    public class responeData
    {
        public int code { set; get; }
        public string? data { set; get; }
        public string? message { set; get; }
        public string? sql { set; get; }
        public string? connectionstringtoken { set; get; }
    }
    public class responseDataTable
    {
        public int code { set; get; }
        public DataTable? data { set;get; }
        public string? message { set; get; }
    }
}
