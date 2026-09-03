FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY ["Tarazin.Web/Tarazin.Web.csproj", "Tarazin.Web/"]
COPY ["Tarazin.Ui/Tarazin.Ui.csproj", "Tarazin.Ui/"]
COPY ["Tarazin.Data/Tarazin.Data.csproj", "Tarazin.Data/"]
COPY ["Tarazin.Share/Tarazin.Share.csproj", "Tarazin.Share/"]
RUN dotnet restore "Tarazin.Web/Tarazin.Web.csproj"

COPY . .
RUN dotnet publish "Tarazin.Web/Tarazin.Web.csproj" \
    --configuration Release \
    --output /app/publish \
    --no-restore \
    -p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .

ENV ASPNETCORE_ENVIRONMENT=Production
# Railway terminates public HTTPS at its proxy; the container receives HTTP.
ENV Tarazin__EnableHttpsRedirection=false
EXPOSE 8080

# Railway injects PORT at runtime; bind publicly on that port.
CMD ["sh", "-c", "dotnet Tarazin.Web.dll --urls http://0.0.0.0:${PORT:-8080}"]
