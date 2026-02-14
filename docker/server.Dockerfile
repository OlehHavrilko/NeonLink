# NeonLink Server - Linux Docker Container
# Hardware monitoring is simulated on Linux using mock data
# For full hardware monitoring, run on Windows with native hardware access

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 9876
EXPOSE 9877

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy shared project
COPY src/NeonLink.Shared/NeonLink.Shared.csproj src/NeonLink.Shared/NeonLink.Shared.csproj
RUN dotnet restore src/NeonLink.Shared/NeonLink.Shared.csproj

# Copy server project
COPY src/NeonLink.Server/NeonLink.Server.csproj src/NeonLink.Server/NeonLink.Server.csproj
RUN dotnet restore src/NeonLink.Server/NeonLink.Server.csproj

# Copy server source files
COPY src/NeonLink.Server/ src/NeonLink.Server/
COPY src/NeonLink.Shared/ src/NeonLink.Shared/

# Build for Linux
WORKDIR /src/src/NeonLink.Server
RUN dotnet build -c Release -o /app/build \
    -p:RuntimeIdentifier=linux-x64 \
    -p:PublishSingleFile=false \
    -p:SelfContained=false

FROM build AS publish
WORKDIR /src/src/NeonLink.Server
RUN dotnet publish -c Release -o /app/publish \
    -p:RuntimeIdentifier=linux-x64 \
    -p:PublishSingleFile=false \
    -p:SelfContained=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .

# Create logs directory
RUN mkdir -p logs

# Set environment variables
ENV ASPNETCORE_ENVIRONMENT=Docker
ENV NEONLINK_LOG_LEVEL=Information

ENTRYPOINT ["dotnet", "NeonLink.Server.dll"]
