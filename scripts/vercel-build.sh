#!/usr/bin/env bash
set -euo pipefail
git clone --depth 1 --branch stable https://github.com/flutter/flutter.git .flutter-sdk
./.flutter-sdk/bin/flutter config --enable-web
./.flutter-sdk/bin/flutter pub get
./.flutter-sdk/bin/flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-https://fdvfmoxcbkdisgnhplaa.supabase.co}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-sb_publishable_2G6kz4aS1GPHOJU0MeNtrg_j2psSWoS}"
