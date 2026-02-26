#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZIP_NAME="Tomatillo-$(uname -m).zip"
ZIP_PATH="$SCRIPT_DIR/$ZIP_NAME"

TAG=$(git -C "$SCRIPT_DIR" describe --exact-match --tags HEAD)

if [[ ! -f "$ZIP_PATH" ]]; then
    echo "error: $ZIP_NAME not found. Run ./release.sh first."
    exit 1
fi

SHA=$(shasum -a 256 "$ZIP_PATH" | cut -d' ' -f1)
NOTES=$(git -C "$SCRIPT_DIR" tag -l --format='%(subject)' "$TAG")

gh release create "$TAG" "$ZIP_PATH" \
    --title "Tomatillo $TAG" \
    --notes "$NOTES

**SHA256:** \`$SHA\`"

VERSION="${TAG#v}"
echo ""
echo "==> update homebrew cask: homebrew-apps/Casks/tomatillo.rb"
echo "    version \"$VERSION\""
echo "    sha256 \"$SHA\""
