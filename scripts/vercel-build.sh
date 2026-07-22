#!/usr/bin/env bash
set -euo pipefail

echo "==> Cloning Flutter (stable, depth=1)..."
git clone --depth 1 --branch stable https://github.com/flutter/flutter.git .flutter-sdk

export PATH="$PATH:$(pwd)/.flutter-sdk/bin"

# Disable analytics / first-run interactive prompts
flutter config --no-analytics --suppress-analytics 2>/dev/null || true

# Enable web platform
flutter config --enable-web

# Pre-cache web engine artifacts so they don't download mid-build
echo "==> Pre-caching Flutter web engine..."
flutter precache --web --no-android --no-ios --no-macos --no-linux --no-windows --no-fuchsia 2>/dev/null || true

# Install pub dependencies
echo "==> Running flutter pub get..."
flutter pub get

# Build Flutter web (release)
echo "==> Building Flutter web..."
flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-https://fdvfmoxcbkdisgnhplaa.supabase.co}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-sb_publishable_2G6kz4aS1GPHOJU0MeNtrg_j2psSWoS}"

echo "==> Done! Output: build/web"
