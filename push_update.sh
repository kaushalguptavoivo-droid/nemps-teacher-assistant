#!/bin/bash

echo "🔍 Zip file dhoondh raha hu..."
ZIP_FILE="$HOME/storage/downloads/nemps-teacher-assistant-complete.zip"

if [ ! -f "$ZIP_FILE" ]; then
    ZIP_FILE="$HOME/storage/shared/Download/nemps-teacher-assistant-complete.zip"
fi

if [ ! -f "$ZIP_FILE" ]; then
    echo "❌ ERROR: Zip file nahi mili! Kripya check karein ki file download folder me mojood hai aur naam bilkul wahi hai."
    exit 1
fi

echo "✅ Zip file mil gayi. Purani files clear kar raha hu (git history safe rahegi)..."
find . -mindepth 1 -maxdepth 1 ! -name '.git' ! -name 'push_update.sh' -exec rm -rf {} +

echo "📦 Extract kar raha hu..."
TEMP_DIR="$HOME/nemps_extract_temp"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

unzip -q "$ZIP_FILE" -d "$TEMP_DIR"
if [ $? -ne 0 ]; then
    echo "❌ ERROR: Unzip fail ho gaya! Zip file corrupt ho sakti hai."
    exit 1
fi

echo "🔄 Nayi files set kar raha hu..."
EXTRACTED_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)

if [ -z "$EXTRACTED_DIR" ]; then
    cp -a "$TEMP_DIR"/. .
else
    cp -a "$EXTRACTED_DIR"/. .
fi

echo "🧹 Temporary kachra saaf kar raha hu..."
rm -rf "$TEMP_DIR"

echo "🚀 GitHub par push kar raha hu..."
git add -A
git commit -m "Fee receipt delete/reset, professional receipt format, admin+fees UI redesign"

echo ""
echo "========================================================="
echo "🔑 Push karte waqt apna GitHub Username aur Password ki jagah apna NAYA Token enter karein!"
echo "========================================================="
git push origin main

echo ""
echo "🎉 Kaam ho gaya! Agar upar koi error nahi aaya, to naya code successfully push ho chuka hai."
