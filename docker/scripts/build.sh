#!/bin/bash
# NeonLink Docker Build Script

set -e

echo "========================================="
echo "NeonLink Docker Build Script"
echo "========================================="

# Build all services
echo "Building all services..."
docker-compose build

echo ""
echo "========================================="
echo "Build complete!"
echo "========================================="
echo ""
echo "To start the services, run:"
echo "  docker-compose up"
echo ""
echo "Services will be available at:"
echo "  - Server:     http://localhost:9876"
echo "  - Web UI:     http://localhost:8080"
echo "  - Desktop VNC: VNC://localhost:5900"
echo "  - Desktop Web: http://localhost:6080"
