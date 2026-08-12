using Microsoft.AspNetCore.Components.Web;
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;
using Accounting;
using BlazorDeployService.Extensions;
using Share.Extensions;

var builder = WebAssemblyHostBuilder.CreateDefault(args);
builder.RootComponents.Add<App>("#app");
builder.RootComponents.Add<HeadOutlet>("head::after");

builder.Services.AddBlazorDeployServices(builder.Configuration);
builder.Services.AddHermesSystemApi(builder.Configuration);

await builder.Build().RunAsync();