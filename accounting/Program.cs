using Microsoft.AspNetCore.Components.Web;
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;
using Accounting;
using BlazorDeployService.Extensions;

var builder = WebAssemblyHostBuilder.CreateDefault(args);
builder.RootComponents.Add<App>("#app");
builder.RootComponents.Add<HeadOutlet>("head::after");

// سرویس‌های عمومی پکیج BlazorDeployService
builder.Services.AddBlazorDeployServices(builder.Configuration);

await builder.Build().RunAsync();