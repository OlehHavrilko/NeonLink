#!/bin/bash
# NeonLink Docker Start Script

echo "========================================="
echo "Starting NeonLink Services"
echo "========================================="

# Start all services
docker-compose up -d

echo ""
echo "========================================="
echo "Services started!"
echo "========================================="
echo ""
echo "Access points:"
echo "  - Server WebSocket: ws://localhost:9876/ws"
echo "  - Web UI:          http://localhost:8080"
echo "  - Desktop VNC:     vnc://localhost:5900"
echo "  - Desktop Web:     http://localhost:6080"
echo ""
echo "To view logs: docker-compose logs -f"
echo "To stop:     docker-compose down"
