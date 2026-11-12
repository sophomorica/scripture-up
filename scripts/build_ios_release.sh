#!/usr/bin/env bash
# Release iOS archive for Scripture Up. Called by cut_release.sh test ios.
#
# Signs with the login-keychain Apple Distribution cert and
# ios/fastlane/ExportOptions.plist (profile "Scripture Up App Store CLI").
# No accounts and no API keys. Does not submit for App Store review.
# Does not prompt for a keychain password.

set -euo pipefail
cd "$(dirname "$0")/.."

unset GEM_HOME GEM_PATH
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-ios/fastlane/ExportOptions.plist}"
if [ ! -f "$EXPORT_OPTIONS_PLIST" ]; then
  echo "❌ Missing $EXPORT_OPTIONS_PLIST" >&2
  exit 1
fi

LOGIN_KC="$HOME/Library/Keychains/login.keychain-db"
if ! security show-keychain-info "$LOGIN_KC" </dev/null >/dev/null 2>&1; then
  echo "❌ Login keychain is locked. Unlock it in the GUI session, then re-run." >&2
  echo "   This script will not prompt for the keychain password." >&2
  exit 1
fi

SAVED_KCS=$(security list-keychains -d user | tr -d '"' | awk 'NF')
restore_keychains() {
  local args=()
  while IFS= read -r line; do
    [ -n "$line" ] && args+=("$line")
  done <<<"$SAVED_KCS"
  if [ ${#args[@]} -gt 0 ]; then
    security list-keychains -d user -s "${args[@]}" >/dev/null 2>&1 || true
  fi
}
trap restore_keychains EXIT
security list-keychains -d user -s "$LOGIN_KC" >/dev/null

VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
echo "▶ Building scripture_up $VERSION (ipa, release)…"

rm -rf build/ios/ipa
flutter build ipa --release \
  --export-options-plist="$EXPORT_OPTIONS_PLIST"

archive="build/ios/archive/Runner.xcarchive"
shopt -s nullglob
ipas=(build/ios/ipa/*.ipa)
if [ ${#ipas[@]} -eq 0 ]; then
  echo "❌ IPA export failed — no file under build/ios/ipa/." >&2
  echo "   Archive may still be at $archive. Need Apple Distribution signing." >&2
  exit 1
fi
ipa=$(ls -t "${ipas[@]}" | head -1)
if [ -d "$archive" ] && [ "$archive" -nt "$ipa" ]; then
  echo "❌ IPA export failed — archive is newer than $(basename "$ipa") (stale IPA)." >&2
  exit 1
fi

echo "✅ Done: $ipa — scripture_up $VERSION"
