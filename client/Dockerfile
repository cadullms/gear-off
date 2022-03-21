# Build the vue app
FROM node:lts-alpine AS vue-builder
WORKDIR /usr/src/app
COPY vue/babel.config.js ./
COPY vue/jsconfig.json ./
COPY vue/package.json ./
COPY vue/package-lock.json ./
RUN npm install
COPY vue/public ./public
COPY vue/src ./src
RUN npm run build

# Build our (BFF) api as .net core app
FROM mcr.microsoft.com/dotnet/sdk:5.0 AS api-builder 
WORKDIR /source
COPY api .
RUN dotnet publish --output package --configuration release

# Production
FROM mcr.microsoft.com/dotnet/aspnet:5.0-alpine
WORKDIR /app
COPY --from=api-builder /source/package .
RUN mkdir ./StaticFiles
COPY --from=vue-builder /usr/src/app/dist/ ./StaticFiles
ENTRYPOINT ["dotnet", "api.dll"]