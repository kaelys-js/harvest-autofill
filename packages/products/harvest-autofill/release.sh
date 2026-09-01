#!/bin/bash
# Publish a Harvest Auto-Fill update to the GitHub Releases feed the app auto-updates from.
#
#   ./release.sh <version> <build> ["release notes"] [app_path]
#   e.g. ./release.sh 2.8 28 "Adds auto-update."
#
# It stamps the version into a COPY of the app, (notarizes if SIGN_ID+NOTARY_PROFILE are set,
# else ad-hoc signs), zips it, writes + Ed25519-signs a manifest, and creates the GitHub release
# with three assets: HarvestAutoFill.zip, manifest.json, manifest.json.sig.
#
# The app verifies the manifest signature with the public key baked into it, so only releases
# signed by the matching private key are accepted.
#
# Needs: the private key at ~/.config/harvest-autofill/release_ed25519_priv.pem (override with
# HAF_PRIV_KEY), gh authenticated, openssl 3.x.
set -euo pipefail

VERSION="${1:?usage: release.sh <version> <build> [notes] [app_path]}"
BUILD="${2:?need a build number (integer, must increase each release)}"
NOTES="${3:-}"
APP="${4:-/Applications/Harvest Auto-Fill.app}"
REPO="kaelys-js/harvest-autofill"
PRIV="${HAF_PRIV_KEY:-$HOME/.config/harvest-autofill/release_ed25519_priv.pem}"
[ -f "$PRIV" ] || {
  echo "Private key not found at $PRIV"
  exit 1
}

WORK="$(mktemp -d -t haf-release)"
trap 'rm -rf "$WORK"' EXIT
STAGE="$WORK/Harvest Auto-Fill.app"
echo "==> Staging $APP as v$VERSION (build $BUILD)..."
/usr/bin/ditto "$APP" "$STAGE"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$STAGE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$STAGE/Contents/Info.plist" 2>/dev/null ||
  /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $BUILD" "$STAGE/Contents/Info.plist"

if [ -n "${SIGN_ID:-}" ] && [ -n "${NOTARY_PROFILE:-}" ]; then
  echo "==> Developer ID sign + notarize..."
  SIGN_ID="$SIGN_ID" NOTARY_PROFILE="$NOTARY_PROFILE" \
    "$(dirname "$0")/notarize.sh" "$STAGE"
else
  echo "==> Ad-hoc signing (set SIGN_ID+NOTARY_PROFILE to notarize)..."
  codesign --force -s - "$STAGE"
fi
codesign --verify --deep --strict "$STAGE"

echo "==> Zipping..."
ZIP="$WORK/HarvestAutoFill.zip"
/usr/bin/ditto -c -k --keepParent "$STAGE" "$ZIP"
SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')

echo "==> Writing + signing manifest..."
MAN="$WORK/manifest.json"
cat >"$MAN" <<JSON
{
  "version": "$VERSION",
  "build": $BUILD,
  "sha256": "$SHA",
  "minMacOS": "14.0",
  "notes": $(python3 -c "import json,sys;print(json.dumps(sys.argv[1]))" "$NOTES")
}
JSON
openssl pkeyutl -sign -inkey "$PRIV" -rawin -in "$MAN" | base64 | tr -d '\n' >"$WORK/manifest.json.sig"

echo "==> Creating GitHub release v$VERSION on $REPO..."
gh release create "v$VERSION" --repo "$REPO" --title "v$VERSION" --notes "${NOTES:-Release $VERSION}" \
  "$ZIP" "$MAN" "$WORK/manifest.json.sig"
echo "Done. The app will pick up v$VERSION (build $BUILD) on its next check."
