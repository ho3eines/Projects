using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BlazorDeployService.Models
{
    public class TreeNodeData
    {
        public int Id { get; set; }
        public int ParentId { get; set; }
        public string Name { get; set; }
        public string Icon { get; set; }
        public int Level { get; set; }
        public int LinkId { set; get; }
        public string AccountCode { get; set; }
        public List<TreeNodeData> Children { get; set; } = new();
        public bool IsExpanded { get; set; }
        public bool IsSelected { get; set; }
        public bool IsVisible { get; set; } = true;
        public bool IsEditing { get; set; }
        public bool HasChildren { get; set; } = true;
        public TreeNodeData Parent { get; set; }
        public bool IsLoading { get; set; } // برای اسپینر
    }
}
