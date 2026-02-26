#!/usr/bin/env bash
set -euo pipefail

# Converts a 1024x1024 PNG to AppIcon.icns for macOS .app bundle.
# Usage: ./icon/convert-icon.sh path/to/icon-1024x1024.png

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

INPUT="${1:?usage: $0 <1024x1024.png>}"
ICONSET_DIR=$(mktemp -d)/AppIcon.iconset
OUTPUT="$PROJECT_DIR/AppIcon.icns"

mkdir -p "$ICONSET_DIR"

# Generate all required sizes from the source PNG
sizes=(16 32 128 256 512)
for sz in "${sizes[@]}"; do
    sz2=$((sz * 2))
    sips -z "$sz" "$sz" "$INPUT" --out "$ICONSET_DIR/icon_${sz}x${sz}.png" >/dev/null
    sips -z "$sz2" "$sz2" "$INPUT" --out "$ICONSET_DIR/icon_${sz}x${sz}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT"
rm -rf "$(dirname "$ICONSET_DIR")"

echo "created $OUTPUT"
