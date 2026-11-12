FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY src/HelmDemoApp/HelmDemoApp.csproj src/HelmDemoApp/
RUN dotnet restore src/HelmDemoApp/HelmDemoApp.csproj

COPY src/HelmDemoApp/ src/HelmDemoApp/
RUN dotnet publish src/HelmDemoApp/HelmDemoApp.csproj \
    --configuration Release \
    --no-restore \
    --output /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
COPY --from=build /app/publish .
USER $APP_UID
ENTRYPOINT ["dotnet", "HelmDemoApp.dll"]
