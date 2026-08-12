# webapi — single backend of the Hermes platform
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY share/share.csproj share/
COPY webapi/webapi.csproj webapi/
RUN dotnet restore webapi/webapi.csproj

COPY share/ share/
COPY webapi/ webapi/
RUN dotnet publish webapi/webapi.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "webapi.dll"]
