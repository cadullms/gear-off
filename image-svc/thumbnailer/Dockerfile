# Builder
FROM mcr.microsoft.com/dotnet/sdk:5.0 AS builder 
WORKDIR /source
COPY . .
RUN dotnet publish --output package --configuration release

# Production
FROM mcr.microsoft.com/dotnet/aspnet:5.0-alpine
WORKDIR /app
COPY --from=builder /source/package .
ENTRYPOINT ["dotnet", "thumbnailer.dll"]