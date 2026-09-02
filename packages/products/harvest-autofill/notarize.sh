#!/bin/bash
# Sign + notarize + staple "Harvest Auto-Fill.app" for distribution to other Macs.
#
# WHY: the app is ad-hoc signed today, which runs locally but Gatekeeper rejects a
# copied/downloaded build ("unidentified developer"). Notarizing under a TTT Apple
# Developer ID removes that prompt so anyone can double-click it.
#
# WHAT YOU NEED (one-time, only you/TTT can supply -- I can't):
#   1. A TTT Apple Developer Program membership ($99/yr org account).
#   2. A "Developer ID Application" certificate in your login keychain
#      (Xcode > Settings > Accounts > Manage Certificates > + Developer ID Application),
#      or `security find-identity -v -p codesigning` to see its name.
#   3. A notary credential profile stored once:
#        xcrun notarytool store-credentials ttt-notary \
#          --apple-id "you@ttt.studio" --team-id "TEAMID" \
#          --password "app-specific-password"     # from appleid.apple.com > App-Specific Passwords
#
# USAGE:
#   SIGN_ID="Developer ID Application: Two Tall Totems Ltd (TEAMID)" \
#   NOTARY_PROFILE="ttt-notary" \
#   ./notarize.sh "/Applications/Harvest Auto-Fill.app"
#
# Result: a stapled .app that opens with no Gatekeeper prompt on any Mac, plus a
# HarvestAutoFill.zip next to it ready to AirDrop/share.
set -euo pipefail

APP="${1:-/Applications/Harvest Auto-Fill.app}"
: "${SIGN_ID:?set SIGN_ID to your 'Developer ID Application: ...' identity}"
: "${NOTARY_PROFILE:?set NOTARY_PROFILE to your stored notarytool profile name}"
ENTITLEMENTS="$(mktemp -t hafent).plist"

# Hardened-runtime entitlements, kept minimal. The app runs the bundled CPython, whose dylibs
# would otherwise fail library validation, so it needs disable-library-validation. It does NOT
# need allow-jit / allow-unsigned-executable-memory — CPython 3.12 has no JIT and executes no
# unsigned memory — so those are omitted to keep the runtime as hardened as possible.
cat >"$ENTITLEMENTS" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.cs.disable-library-validation</key><true/>
</dict></plist>
PLIST

echo "==> Signing nested Mach-O binaries (python, dylibs) first, then the app..."
# Sign every nested Mach-O (the bundled Python is full of them) with hardened runtime.
find "$APP/Contents/Resources/python" -type f \( -name "*.dylib" -o -name "*.so" -o -perm -u+x \) -print0 2>/dev/null |
  while IFS= read -r -d '' f; do
    if file "$f" | grep -q "Mach-O"; then
      codesign --force --timestamp --options runtime -s "$SIGN_ID" "$f" 2>/dev/null || true
    fi
  done

echo "==> Signing the app bundle (nested Mach-O already signed inside-out above)..."
# No --deep: nested code was signed individually just above (the correct inside-out order), and
# Apple deprecated --deep for signing. This signs the top-level bundle with the hardened runtime
# and entitlements; --verify --deep still checks the whole tree.
codesign --force --timestamp --options runtime \
  --entitlements "$ENTITLEMENTS" -s "$SIGN_ID" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Zipping for notarization..."
ZIP="$(dirname "$APP")/HarvestAutoFill.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Submitting to Apple notary service (waits for the verdict)..."
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling the ticket to the app..."
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "==> Re-zipping the stapled app for sharing..."
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "Done. Share: $ZIP  (notarized; opens without a Gatekeeper prompt on a standard Mac)"
rm -f "$ENTITLEMENTS"
