#!/usr/bin/env bash
# Build, sign, and upload Scripture Up to TestFlight. One command:
#
#   ./scripts/cut_release.sh test ios               # build → sign → TestFlight
#   ./scripts/cut_release.sh test ios --no-upload   # build → sign → .ipa, no upload
#   ./scripts/cut_release.sh test ios --dry-run     # print the plan only
#
# Modelled on Seminary Sidekick scripts/cut_release.sh test ios + fastlane
# ios internal. There is no App Store submit or release lane, on purpose.
# The build number is the latest ASC build for this app + 1 (read with the
# ASC API key). Override with BUILD_NUMBER=N.
set -euo pipefail
cd "$(dirname "$0")/.."

usage() {
  cat <<'USAGE' >&2
usage: ./scripts/cut_release.sh test ios [--no-upload] [--dry-run]

  test ios     Build, sign, and upload to TestFlight. Never submits for review.
  --no-upload  Build and sign the .ipa, then stop before the upload.
  --dry-run    Print what would run. No build, no upload.
USAGE
  exit 2
}

track=""
target=""
DRY_RUN=0
NO_UPLOAD=0
for arg in "$@"; do
  case "$arg" in
    test) track="test" ;;
    ios) target="ios" ;;
    release|android|both)
      echo "❌ TestFlight only. There is no App Store submit or release lane." >&2
      echo "   ./scripts/cut_release.sh test ios" >&2
      exit 2
      ;;
    --no-upload) NO_UPLOAD=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done
if [ "$track" = "test" ] && [ -z "$target" ]; then
  target="ios"
fi
[ "$track" = "test" ] && [ "$target" = "ios" ] || usage

# --- shared TestFlight helpers (same block in Speed Read, Goji Memory,
# Goji Chat, Scripture Up) ---------------------------------------------

# ASC API key. Never printed. Looks for asc-api.env when the vars are
# unset, and falls back to ~/.appstoreconnect/private_keys when
# ASC_KEY_PATH points at a file that is not on this machine.
load_asc() {
  if [ -z "${ASC_KEY_ID:-}" ] || [ -z "${ASC_ISSUER_ID:-}" ] || [ -z "${ASC_KEY_PATH:-}" ]; then
    local f
    for f in \
      "$HOME/Desktop/active/business/narrow-road-keys/asc-api.env" \
      "$HOME/nr/business/narrow-road-keys/asc-api.env" \
      "$HOME/nr-builds/asc.env"
    do
      if [ -f "$f" ]; then
        set -a
        # shellcheck disable=SC1090
        source "$f"
        set +a
        break
      fi
    done
  fi
  if [ -z "${ASC_KEY_ID:-}" ] || [ -z "${ASC_ISSUER_ID:-}" ]; then
    echo "❌ ASC_KEY_ID / ASC_ISSUER_ID are unset, and asc-api.env was not found." >&2
    exit 1
  fi
  if [ -z "${ASC_KEY_PATH:-}" ] || [ ! -f "${ASC_KEY_PATH/#\~/$HOME}" ]; then
    local alt="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
    if [ -f "$alt" ]; then
      ASC_KEY_PATH="$alt"
    else
      echo "❌ No .p8 for ASC key ${ASC_KEY_ID} (ASC_KEY_PATH or ~/.appstoreconnect/private_keys)." >&2
      exit 1
    fi
  fi
  export ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH
  echo "▶ ASC API key ${ASC_KEY_ID} (path and issuer not printed)."
}

# Build with the Flutter version CI pins (.github/workflows flutter-version).
# Uses ~/nr-builds/flutter-<pin> when the flutter on PATH is a different
# version. Refuses to build with any other version.
use_pinned_flutter() {
  local pin cand
  pin=$(grep -hoE 'flutter-version:[[:space:]]*"?[0-9]+\.[0-9]+\.[0-9]+' .github/workflows/*.yml 2>/dev/null \
    | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+$' || true)
  if [ -z "$pin" ]; then
    echo "❌ No flutter-version pin found in .github/workflows/*.yml." >&2
    exit 1
  fi
  for cand in "${FLUTTER_HOME:-}" "$HOME/nr-builds/flutter-$pin" \
    "$(cd "$(dirname "$(command -v flutter 2>/dev/null || echo /nonexistent/bin/flutter)")/.." 2>/dev/null && pwd)"; do
    [ -n "$cand" ] && [ -x "$cand/bin/flutter" ] || continue
    case "$("$cand/bin/flutter" --version 2>/dev/null || true)" in
      "Flutter $pin "*) ;;
      *) continue ;;
    esac
    export PATH="$cand/bin:$PATH"
    echo "▶ Flutter $pin (CI pin) from $cand"
    return 0
  done
  echo "❌ Flutter $pin (the CI pin) is not installed. Put it at ~/nr-builds/flutter-$pin" >&2
  echo "   (git clone --depth 1 -b $pin https://github.com/flutter/flutter.git ~/nr-builds/flutter-$pin)" >&2
  exit 1
}

require_login_keychain() {
  local login="$HOME/Library/Keychains/login.keychain-db"
  if ! security show-keychain-info "$login" </dev/null >/dev/null 2>&1; then
    echo "❌ Login keychain is locked. Signing would need the GUI keychain unlocked." >&2
    echo "   Unlock it in the GUI session, then re-run. This script will not prompt." >&2
    exit 1
  fi
}
# ----------------------------------------------------------------------

if [ "$DRY_RUN" -eq 0 ] && ! command -v fastlane >/dev/null 2>&1; then
  echo "❌ fastlane not found — install with: brew install fastlane" >&2
  exit 1
fi
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
mode="upload to TestFlight"
[ "$NO_UPLOAD" -eq 1 ] && mode="build + sign only (--no-upload)"
echo ""
echo "════════════════════════════════════════════════════════"
echo " TEST (TestFlight) ${VERSION%%+*} → ios: $mode"
echo "════════════════════════════════════════════════════════"
echo ""
echo "   iOS: fastlane ios internal (build number = latest ASC build + 1)"
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
  echo "dry-run: no build, no upload"
  exit 0
fi

require_login_keychain
load_asc
use_pinned_flutter
export NO_UPLOAD
(cd ios && fastlane ios internal)

echo ""
if [ "$NO_UPLOAD" -eq 1 ]; then
  echo "✅ cut_release.sh test ios --no-upload done. Signed .ipa built; nothing uploaded."
else
  echo "✅ cut_release.sh test ios done. Uploaded to TestFlight; not submitted for review."
fi
