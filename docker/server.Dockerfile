# NeonLink Server - .NET 8 with PostgreSQL
# Optimized multi-stage build for production

# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build
WORKDIR /src

# Install PostgreSQL client for migrations
RUN apk add --no-cache postgresql15-client curl

# Copy solution and projects
COPY NeonLink.sln ./
COPY src/NeonLink.Shared/NeonLink.Shared.csproj src/NeonLink.Shared/
COPY src/NeonLink.Server/NeonLink.Server.csproj src/NeonLink.Server/

# Restore dependencies
RUN dotnet restore src/NeonLink.Server/NeonLink.Server.csproj

# Copy all source files
COPY src/NeonLink.Shared/ src/NeonLink.Shared/
COPY src/NeonLink.Server/ src/NeonLink.Server/

# Build application
WORKDIR /src/src/NeonLink.Server
RUN dotnet build -c Release -o /app/build \
    --no-restore

# Publish application
FROM build AS publish
RUN dotnet publish -c Release -o /app/publish \
    --no-build \
    -p:PublishSingleFile=false \
    -p:SelfContained=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS final
WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache \
    postgresql15-client \
    curl \
    icu-data-full

# Enable ICU for globalization
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=0

# Create non-root user
RUN addgroup -g 1000 appgroup && \
    adduser -u 1000 -G appgroup -s /bin/sh -D appuser

# Copy published files
COPY --from=publish /app/publish .

# Create directories with proper permissions
RUN mkdir -p logs && chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose ports
EXPOSE 9876 9877

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:9876/api/health || exit 1

# Environment variables
ENV ASPNETCORE_ENVIRONMENT=Docker \
    NEONLINK_LOG_LEVEL=Information \
    DOTNET_RUNNING_IN_CONTAINER=true

ENTRYPOINT ["dotnet", "NeonLink.Server.dll"]
