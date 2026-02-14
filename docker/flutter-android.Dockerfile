# NeonLink Flutter Android Builder
# Builds Android APK using Flutter SDK and Android SDK

FROM ubuntu:22.04 AS base

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    openjdk-17-jdk \
    wget \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Set up Android SDK
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools

# Create Android SDK directory
RUN mkdir -p $ANDROID_SDK_ROOT/cmdline-tools

# Download and extract Android command line tools
WORKDIR $ANDROID_SDK_ROOT/cmdline-tools
RUN wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip && \
    unzip -q cmdline-tools.zip && \
    mv cmdline-tools latest && \
    rm cmdline-tools.zip

# Accept licenses and install required SDK components
RUN yes | $ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager --licenses || true
RUN $ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager --install \
    "platform-tools" \
    "platforms;android-34" \
    "build-tools;34.0.0" \
    "ndk;26.1.10909125"

# Set up Flutter SDK
ENV FLUTTER_VERSION=3.24.0
ENV FLUTTER_ROOT=/flutter
ENV PATH=$FLUTTER_ROOT/bin:$PATH

WORKDIR /
RUN git clone --depth 1 --branch $FLUTTER_VERSION https://github.com/flutter/flutter.git $FLUTTER_ROOT

# Run flutter doctor to initialize
RUN flutter precache --android
RUN flutter config --no-analytics
RUN flutter doctor

# Builder stage
FROM base AS builder
WORKDIR /app

# Copy Flutter project
COPY neonlink_app/ .

# Get dependencies
RUN flutter pub get

# Build debug APK
RUN flutter build apk --debug --no-pub

# Final stage - copy APK
FROM alpine:latest AS final
WORKDIR /output
COPY --from=builder /app/build/app/outputs/flutter-apk/app-debug.apk /output/neonlink-debug.apk

CMD ["ls", "-la", "/output"]
