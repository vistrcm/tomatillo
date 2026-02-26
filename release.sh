#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY_NAME="Tomatillo"
BUILD_DIR="$SCRIPT_DIR/.build/release"
BINARY="$BUILD_DIR/$BINARY_NAME"
ENTITLEMENTS="$SCRIPT_DIR/entitlements.plist"
NOTARY_PROFILE="tomatillo-notary"
APP_BUNDLE="$SCRIPT_DIR/$BINARY_NAME.app"
ICNS="$SCRIPT_DIR/AppIcon.icns"

SIGNING_IDENTITY="Developer ID Application: Stanislav Vitko (4D2D7HUF4Q)"

# check: must be on a git tag with clean working tree
TAG=$(git -C "$SCRIPT_DIR" describe --exact-match --tags HEAD 2>/dev/null || true)
if [[ -z "$TAG" ]]; then
    echo "error: HEAD is not a git tag. Tag a release first: git tag v0.1.0"
    exit 1
fi
if ! git -C "$SCRIPT_DIR" tag -v "$TAG" >/dev/null 2>&1; then
    echo "error: tag $TAG is not signed. Use: git tag -s v0.1.0"
    exit 1
fi
if [[ -n "$(git -C "$SCRIPT_DIR" status --porcelain)" ]]; then
    echo "error: uncommitted changes. Commit or stash before releasing."
    exit 1
fi

VERSION="${TAG#v}"  # strip leading 'v' (v0.1.0 → 0.1.0)
BUILD_NUMBER=$(git -C "$SCRIPT_DIR" rev-list --count HEAD)

echo "==> version: $VERSION (build $BUILD_NUMBER) from tag $TAG"
echo "==> signing identity: $SIGNING_IDENTITY"

if [[ ! -f "$ICNS" ]]; then
    echo "error: $ICNS not found. Run: ./icon/convert-icon.sh <1024x1024.png>"
    exit 1
fi

echo "==> building release binary"
swift build -c release

echo "==> assembling .app bundle"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/"
sed -e "s/0\.1\.0/$VERSION/" -e "s/<string>1</<string>$BUILD_NUMBER</" \
    "$SCRIPT_DIR/Info.plist" > "$APP_BUNDLE/Contents/Info.plist"
cp "$ICNS" "$APP_BUNDLE/Contents/Resources/"

echo "==> signing with Developer ID"
codesign -s "$SIGNING_IDENTITY" \
    --entitlements "$ENTITLEMENTS" \
    --timestamp \
    --options runtime \
    --force \
    "$APP_BUNDLE"

echo "==> verifying signature"
codesign --verify --strict "$APP_BUNDLE"
echo "    signature OK"

echo "==> packaging for notarization"
ZIP_NAME="${BINARY_NAME}-$(uname -m).zip"
zip -r "$SCRIPT_DIR/$ZIP_NAME" "$APP_BUNDLE"

echo "==> submitting for notarization"
xcrun notarytool submit "$SCRIPT_DIR/$ZIP_NAME" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

echo "==> stapling notarization ticket"
xcrun stapler staple "$APP_BUNDLE"

echo "==> re-packaging with stapled bundle"
rm "$SCRIPT_DIR/$ZIP_NAME"
(cd "$SCRIPT_DIR" && zip -r "$ZIP_NAME" "$BINARY_NAME.app")

echo "==> checksums"
shasum -a 256 "$SCRIPT_DIR/$ZIP_NAME"

echo "==> done: $ZIP_NAME"
