# NeonLink Flutter App - Web Build Container
# Собирает Flutter приложение для web

FROM dart:3.0 AS base

# Install Flutter SDK
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Set up Flutter
ENV FLUTTER_VERSION=3.24.0
ENV FLUTTER_ROOT=/flutter

RUN git clone --depth 1 --branch $FLUTTER_VERSION https://github.com/flutter/flutter.git $FLUTTER_ROOT
ENV PATH="$FLUTTER_ROOT/bin:$PATH"

# Run flutter doctor to initialize
RUN flutter precache --web
RUN flutter config --no-analytics
RUN flutter doctor

WORKDIR /app

# Copy Flutter project
COPY neonlink_app/ .

# Get dependencies
RUN flutter pub get

# Build for web
RUN flutter build web --release

FROM nginx:alpine AS final

# Copy build output
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copy nginx config
RUN echo 'server {\n\
    listen 80;\n\
    server_name localhost;\n\
    root /usr/share/nginx/html;\n\
    index index.html;\n\
\n\
    location / {\n\
        try_files $uri $uri/ /index.html;\n\
    }\n\
\n\
    # Cache static assets\n\
    location ~* \\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {\n\
        expires 1y;\n\
        add_header Cache-Control "public, immutable";\n\
    }\n\
\n\
    # Enable CORS for API\n\
    location /api/ {\n\
        proxy_pass http://server:9876/;\n\
        proxy_http_version 1.1;\n\
        proxy_set_header Upgrade $http_upgrade;\n\
        proxy_set_header Connection "upgrade";\n\
        proxy_set_header Host $host;\n\
        proxy_set_header X-Real-IP $remote_addr;\n\
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n\
    }\n\
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
