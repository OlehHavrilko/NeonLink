# NeonLink Desktop Builder - Windows .exe via PyInstaller
# Builds Windows executable using PyInstaller

FROM python:3.11-windowsservercore AS base

# Install Chocolatey and build tools
RUN choco install -y visualstudio2022buildtools visualstudio2022-workload-vctools python311

# Set working directory
WORKDIR /app

FROM base AS builder
WORKDIR /app

# Copy requirements
COPY src/neonlink_desktop/requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir pyinstaller

# Copy application source
COPY src/neonlink_desktop/ .

# Create PyInstaller spec file
RUN echo "from PyInstaller.__main__ import run\nrun()" > pyinstaller_run.py

# Build executable
RUN pyinstaller --name=NeonLink --windowed --onefile --icon=resources/icon.ico --add-data "resources;resources" __main__.py

# Final stage
FROM scratch AS final
WORKDIR /output
COPY --from=builder /app/dist/NeonLink.exe /output/
COPY --from=builder /app/src/neonlink_desktop/resources /output/resources
