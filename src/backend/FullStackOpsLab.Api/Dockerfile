FROM mcr.microsoft.com/dotnet/sdk:10.0

WORKDIR /src

COPY FullStackOpsLab.Api.csproj ./
RUN dotnet restore FullStackOpsLab.Api.csproj

COPY . ./
RUN dotnet publish FullStackOpsLab.Api.csproj -c Release -o /app/publish --no-restore

ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

WORKDIR /app/publish
ENTRYPOINT ["dotnet", "FullStackOpsLab.Api.dll"]
