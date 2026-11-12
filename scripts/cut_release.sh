#!/usr/bin/env bash
# Build, sign, and upload Scripture Up to TestFlight.
#
#   ./scripts/cut_release.sh test ios
#   ./scripts/cut_release.sh test ios --dry-run
#
# No App Store submit lane. Modelled on Seminary Sidekick
# scripts/cut_release.sh test ios + fastlane ios internal.

set -euo pipefail
cd "$(dirname "$0")/.."

usage() {
  cat <<'EOF' >&2
usage: ./scripts/cut_release.sh test ios [--dry-run]

  test ios  Build, sign, and upload to TestFlight.
            Does not submit for App Store review.
EOF
  exit 2
}

track=""
target=""
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    test) track="test" ;;
    ios) target="ios" ;;
    release|android|both)
      echo "❌ TestFlight only. There is no App Store submit lane." >&2
      echo "   ./scripts/cut_release.sh test ios" >&2
      exit 2
      ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done
if [ "$track" = "test" ] && [ -z "$target" ]; then
  target="ios"
fi
[ "$track" = "test" ] && [ "$target" = "ios" ] || usage

load_asc() {
  if [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ] && [ -n "${ASC_KEY_PATH:-}" ]; then
    return 0
  fi
  local f
  for f in \
    "$HOME/Desktop/active/business/narrow-road-keys/asc-api.env" \
    "$HOME/nr/business/narrow-road-keys/asc-api.env"
  do
    if [ -f "$f" ]; then
      set -a
      # shellcheck disable=SC1090
      source "$f"
      set +a
      return 0
    fi
  done
  echo "❌ ASC_KEY_ID, ASC_ISSUER_ID, and ASC_KEY_PATH are unset, and asc-api.env was not found." >&2
  exit 1
}

require_login_keychain() {
  local login="$HOME/Library/Keychains/login.keychain-db"
  if ! security show-keychain-info "$login" </dev/null >/dev/null 2>&1; then
    echo "❌ Login keychain is locked. Unlock it in the GUI session, then re-run." >&2
    echo "   This script will not prompt for the keychain password." >&2
    exit 1
  fi
}

if [ "$DRY_RUN" -eq 0 ] && ! command -v fastlane >/dev/null 2>&1; then
  echo "❌ fastlane not found — install with: brew install fastlane" >&2
  exit 1
fi

VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
echo ""
echo "════════════════════════════════════════════════════════"
echo " TEST (TestFlight) $VERSION → ios"
echo "════════════════════════════════════════════════════════"
echo ""
echo "   iOS: fastlane ios internal"
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
  echo "dry-run: no build, no upload"
  exit 0
fi

require_login_keychain
load_asc

(cd ios && fastlane ios internal)

echo ""
echo "✅ cut_release.sh test ios done ($VERSION)"
echo "   Install from TestFlight. This repo does not submit for App Store review."
