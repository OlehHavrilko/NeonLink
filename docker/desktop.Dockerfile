# NeonLink Desktop - Python GUI Application with VNC
# Для удалённого доступа к PyQt6 приложению

FROM python:3.11-slim AS base

# Install system dependencies for PyQt6 and VNC
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libgbm1 \
    libxkbcommon0 \
    libxcb-cursor0 \
    libxcb-icccm4 \
    libxcb-keysyms1 \
    libxcb-render-util0 \
    libxcb-shape0 \
    libxcb-xinerama0 \
    libxcb-xfixes0 \
    libxcb-randr0 \
    libxcb-image0 \
    libxcb-keysyms \
    libxcb-render0 \
    libxcb-shm0 \
    libxcb-sync1 \
    libxcb-xkb1 \
    libxkbcommon-x11-0 \
    libdbus-1-3 \
    libfontconfig1 \
    libfreetype6 \
    libx11-6 \
    libxext6 \
    libxrender1 \
    libice6 \
    libsm6 \
    libxv1 \
    xvfb \
    fluxbox \
    x11vnc \
    websockify \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set display environment
ENV DISPLAY=:99
ENV QT_QPA_PLATFORM=offscreen
ENV QT_DEBUG_PLUGINS=0

WORKDIR /app

FROM base AS builder
WORKDIR /app

# Copy requirements and install Python dependencies
COPY src/neonlink_desktop/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source
COPY src/neonlink_desktop/ .

FROM base AS runtime
WORKDIR /app

# Copy Python dependencies from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy application source
COPY --from=builder /app /app

# Create VNC startup script
RUN echo '#!/bin/bash\n\
export DISPLAY=:99\n\
export QT_QPA_PLATFORM=offscreen\n\
\n\
# Start Xvfb\n\
Xvfb :99 -screen 0 1920x1080x24 &\n\
sleep 2\n\
\n\
# Start Fluxbox window manager\n\
fluxbox &\n\
sleep 1\n\
\n\
# Start x11vnc\n\
x11vnc -display :99 -forever -shared -bg\n\
\n\
# Start websockify for web-based VNC access\n\
websockify --web=/usr/share/novnc 6080 localhost:5900 &\n\
sleep 1\n\
\necho "VNC Server started. Connect to http://localhost:6080"\necho "Or use VNC client on port 5900"\n\
\n\
# Run the application\n\
cd /app\n\
python -m neonlink_desktop\n' > /start.sh

RUN chmod +x /start.sh

# Expose VNC ports
EXPOSE 5900 6080

ENTRYPOINT ["/start.sh"]
