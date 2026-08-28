$env:ASPNETCORE_URLS = 'https://localhost:65220'
$env:TARAZIN_DEBUG_INIT = '1'
$p = Start-Process -FilePath 'dotnet.exe' -ArgumentList 'run','--project','Tarazin.Web/Tarazin.Web.csproj','--no-build' -RedirectStandardOutput '.freebuff/preview-closeyear.log' -RedirectStandardError '.freebuff/preview-closeyear.log.err' -WindowStyle Hidden -PassThru
$p.Id
