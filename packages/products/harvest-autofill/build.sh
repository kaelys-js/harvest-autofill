#!/bin/bash
# Build "Harvest Auto-Fill.app" from source into ./dist. Reproducible; used locally and in CI.
#   ./build.sh [version] [build]
# Stamps CFBundleShortVersionString/CFBundleVersion when both are given (CI passes them);
# otherwise keeps whatever Info.plist holds. Bundles a relocatable Python and ad-hoc signs
# (set SIGN_ID to sign with a Developer ID instead).
set -euo pipefail
cd "$(dirname "$0")"
VERSION="${1:-}"
BUILD="${2:-}"
DIST="dist"
APP="$DIST/Harvest Auto-Fill.app"
PY_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20260825/cpython-3.12.14%2B20260825-aarch64-apple-darwin-install_only_stripped.tar.gz"

echo "==> Compiling..."
swiftc -parse-as-library -O HarvestApp.swift -o /tmp/haf-bin.$$
echo "==> Fetching bundled Python (cached in vendor/)..."
if [ ! -x "vendor/python/bin/python3" ]; then
  mkdir -p vendor && curl -sL -m 300 -o vendor/py.tar.gz "$PY_URL"
  rm -rf vendor/python && tar -C vendor -xzf vendor/py.tar.gz
fi

echo "==> Assembling $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' >"$APP/Contents/PkgInfo"
mv /tmp/haf-bin.$$ "$APP/Contents/MacOS/Harvest"
chmod +x "$APP/Contents/MacOS/Harvest"
for f in discover.py harvest_weekly.py engine.sh config.default.json; do cp "$f" "$APP/Contents/Resources/$f"; done
cp icon.png "$APP/Contents/Resources/icon.png"
cp icon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R vendor/python "$APP/Contents/Resources/python"
find "$APP/Contents/Resources/python" -name "__pycache__" -prune -exec rm -rf {} + 2>/dev/null || true

if [ -n "$VERSION" ]; then /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"; fi
if [ -n "$BUILD" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$APP/Contents/Info.plist" 2>/dev/null ||
    /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $BUILD" "$APP/Contents/Info.plist"
fi

echo "==> Signing (sign LAST so nothing mutates the bundle after)..."
if [ -n "${SIGN_ID:-}" ]; then
  codesign --force --deep --timestamp --options runtime -s "$SIGN_ID" "$APP"
else codesign --force --deep -s - "$APP"; fi
codesign --verify --deep --strict "$APP"
echo "Built: $APP  ($(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist") / $(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist"))"
