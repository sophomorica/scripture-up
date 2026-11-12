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

# `security list-keychains` indents each path and quotes it. Strip both, or
# the restore below turns each entry into a bogus relative keychain path.
SAVED_KCS=$(security list-keychains -d user | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//' | awk 'NF')
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
# Ctrl-C / kill: exit so the EXIT trap still restores the list.
trap 'exit 130' INT
trap 'exit 143' TERM
security list-keychains -d user -s "$LOGIN_KC" >/dev/null

VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
echo "▶ Building scripture_up $VERSION (ipa, release)…"

# Version from pubspec; build number from the fastlane lane (latest ASC + 1).
build_args=()
if [ -n "${BUILD_NUMBER:-}" ]; then
  build_args+=(--build-name="${BUILD_NAME:-${VERSION%%+*}}" --build-number="$BUILD_NUMBER")
fi
rm -rf build/ios/ipa
flutter build ipa --release ${build_args[@]+"${build_args[@]}"} \
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


# Prove what was built: version, build number, and signature.
verify_dir=$(mktemp -d)
unzip -q "$ipa" -d "$verify_dir"
app_dir=$(ls -d "$verify_dir"/Payload/*.app | head -1)
got_build=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app_dir/Info.plist")
got_name=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app_dir/Info.plist")
if [ -n "${BUILD_NUMBER:-}" ] && [ "$got_build" != "$BUILD_NUMBER" ]; then
  echo "❌ .ipa CFBundleVersion is $got_build, expected $BUILD_NUMBER." >&2
  rm -rf "$verify_dir"
  exit 1
fi
if ! codesign --verify --deep --strict "$app_dir" 2>/dev/null; then
  echo "❌ codesign --verify failed on $(basename "$app_dir")." >&2
  rm -rf "$verify_dir"
  exit 1
fi
# Read all of codesign's output first: grep -m1 in a pipe makes codesign
# die of SIGPIPE, and pipefail turns that into a silent failure.
cs_info=$(codesign -dvv "$app_dir" 2>&1 || true)
signer=$(printf '%s\n' "$cs_info" | sed -n 's/^Authority=//p' | sed -n 1p)
rm -rf "$verify_dir"
echo "▶ .ipa: $got_name ($got_build), signed by: $signer"
echo "✅ Done: $ipa — scripture_up $VERSION"
