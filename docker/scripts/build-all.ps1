# NeonLink Build Script
# Builds all components: Server, Desktop, Flutter

param(
    [switch]$Server,
    [switch]$Desktop,
    [switch]$Flutter,
    [switch]$All,
    [switch]$Push
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

function Write-Step {
    param([string]$Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Build-Server {
    Write-Step "Building Server (.NET 8)"
    Set-Location "$ProjectRoot\src\NeonLink.Server"
    dotnet restore
    dotnet publish -c Release -o "$ProjectRoot\output\server"
    Write-Host "Server built successfully" -ForegroundColor Green
}

function Build-Desktop {
    Write-Step "Building Desktop (PyInstaller)"
    Set-Location "$ProjectRoot\src\neonlink_desktop"
    
    # Create output directory
    $outputDir = "$ProjectRoot\output\desktop"
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # Build with PyInstaller
    pyinstaller neonlink.spec --distpath "$outputDir" --workpath "$outputDir\build" --noconfirm
    Write-Host "Desktop app built successfully" -ForegroundColor Green
}

function Build-Flutter {
    Write-Step "Building Flutter (via Docker)"
    docker build -f "$ProjectRoot\docker\flutter-android.Dockerfile" -t neonlink-flutter-builder .
    docker run --rm -v "$ProjectRoot\output:/output" neonlink-flutter-builder
    Write-Host "Flutter APK built successfully" -ForegroundColor Green
}

function Push-Docker {
    Write-Step "Pushing Docker images"
    docker push neonlink/server:latest
    docker push neonlink/postgres:latest
    Write-Host "Docker images pushed successfully" -ForegroundColor Green
}

# Main execution
if ($All) {
    if ($Server) { Build-Server }
    if ($Desktop) { Build-Desktop }
    if ($Flutter) { Build-Flutter }
    if ($Push) { Push-Docker }
} else {
    # Default: build all if no flags specified
    Build-Server
    Build-Desktop
    Build-Flutter
}

Write-Step "Build complete!"
