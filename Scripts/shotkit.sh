#!/bin/bash
#
# shotkit.sh — capture every screen in every language, and build the App Store set.
#
# Copy this into your app's Scripts/ and edit the config block. Everything below it is
# app-agnostic.
#
#   Scripts/shotkit.sh                      # every locale, light pass
#   Scripts/shotkit.sh de fr                # just those locales
#   APPEARANCE=dark Scripts/shotkit.sh      # dark pass → Screenshots/<locale>-dark/
#   MODE=store Scripts/shotkit.sh           # App Store frames from the last capture
#   SKIP_BUILD=1 Scripts/shotkit.sh de      # reuse the last build
#   DEVICE="iPhone 17 Pro" Scripts/shotkit.sh
#
set -euo pipefail

# ---- config: the only part you edit ----------------------------------------
SCHEME="BookGate"
BUNDLE_ID="app.bookgate.BookGate"
APP_NAME="BookGate"                       # PRODUCT_NAME
EXPECTED=11                               # screens per locale — keep in step with `Shot`

# "locale code : region". The code names the output folder and must match a
# CFBundleLocalizations entry.
# Only English is translated today (Localizable.xcstrings has no other locale filled in);
# add a row here the moment one is, and the whole set rebuilds in it.
ALL_LOCALES=("en:en_US")

# Files to drop into the app container before capture — camera stand-ins, seed photos,
# the caption copy. "source:destination-name", relative to the repo root. Kept out of the
# app bundle so a personal photo never ships.
# The caption copy is staged into the container rather than bundled, so App Store marketing
# text never ships inside the app. shot-photo.jpg stands in for the camera the Simulator
# doesn't have on the nightly gate screen — drop a real photo of someone holding a book at
# Scripts/shot-assets/gate.jpg and that frame captures for real (it is skipped if absent).
CONTAINER_ASSETS=(
  "Scripts/store_captions.json:store_captions.json"
  "Scripts/shot-assets/gate.jpg:shot-photo.jpg"
  "Scripts/shot-assets/cover.jpg:shot-cover.jpg"
)

# Extra environment for the app process, "KEY=VALUE" — for the debug hooks an app already
# has (a camera stand-in, a seed switch). simctl passes SIMCTL_CHILD_* through to the app.
LAUNCH_ENV=("BOOKGATE_CAMERA_IMAGE=shot-photo.jpg")

# ---- everything below is app-agnostic --------------------------------------
# xcodebuild and simctl need full Xcode. A machine whose xcode-select still points at the
# Command Line Tools fails several steps in, with an error that names neither.
if [ -z "${DEVELOPER_DIR:-}" ] && ! xcode-select -p 2>/dev/null | grep -q "Xcode.app"; then
  if [ -d /Applications/Xcode.app ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  else
    echo "Xcode is required (xcode-select points at $(xcode-select -p 2>/dev/null))."; exit 1
  fi
fi

for kv in "${LAUNCH_ENV[@]:-}"; do
  [ -z "$kv" ] && continue
  export "SIMCTL_CHILD_${kv%%=*}=${kv#*=}"
done

DEVICE="${DEVICE:-iPhone 17 Pro Max}"     # App Store 6.9" class (1320×2868)
APPEARANCE="${APPEARANCE:-light}"
MODE="${MODE:-screens}"                   # screens | store
DERIVED="build-shots"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$REPO_DIR/Screenshots"
FILTER=("$@")
FAILED=0

SUFFIX=""
[ "$APPEARANCE" = "dark" ] && SUFFIX="-dark"
[ "$MODE" = "store" ] && SUFFIX=""

log()  { printf '\033[1;36m▸ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m✗ %s\033[0m\n' "$*"; FAILED=1; }

wanted() {
  [ ${#FILTER[@]} -eq 0 ] && return 0
  for f in "${FILTER[@]}"; do [ "$f" = "$1" ] && return 0; done
  return 1
}

# ---- simulator --------------------------------------------------------------
log "Resolving simulator: $DEVICE"
UDID=$(xcrun simctl list devices available | grep -F "$DEVICE (" | head -1 | grep -oE '[0-9A-F-]{36}' || true)
[ -n "$UDID" ] || { echo "Simulator '$DEVICE' not found."; xcrun simctl list devices available | grep iPhone; exit 1; }

xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
open -a Simulator >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" >/dev/null 2>&1 || true

# A clean status bar is required for App Store shots: 9:41, full bars, full battery.
xcrun simctl status_bar "$UDID" override \
  --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 >/dev/null 2>&1 || true

# ---- build + install --------------------------------------------------------
APP_PATH="$REPO_DIR/$DERIVED/Build/Products/Debug-iphonesimulator/$APP_NAME.app"
if [ "${SKIP_BUILD:-0}" != "1" ]; then
  log "Building $SCHEME (Debug) — the harness is DEBUG-only and never ships"
  xcodebuild -scheme "$SCHEME" -configuration Debug -sdk iphonesimulator \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$REPO_DIR/$DERIVED" \
    CODE_SIGNING_ALLOWED=NO build | tail -3
fi
[ -d "$APP_PATH" ] || { echo "App not found at $APP_PATH"; exit 1; }
log "Installing"
xcrun simctl install "$UDID" "$APP_PATH"

DATA_DIR="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
SHOTS="$DATA_DIR/Documents/shots"
mkdir -p "$DATA_DIR/Documents"

for asset in "${CONTAINER_ASSETS[@]:-}"; do
  [ -z "$asset" ] && continue
  src="$REPO_DIR/${asset%%:*}"; dest="$DATA_DIR/Documents/${asset##*:}"
  if [ -f "$src" ]; then cp "$src" "$dest"; log "Container asset: ${asset%%:*}"
  else rm -f "$dest"; log "Missing (skipped): ${asset%%:*}"; fi
done

# ---- capture ----------------------------------------------------------------
for entry in "${ALL_LOCALES[@]}"; do
  code="${entry%%:*}"; region="${entry##*:}"
  wanted "$code" || continue

  if [ "$MODE" = "store" ]; then
    # Store frames read the previous pass's PNGs back in from the container.
    src="$OUT_DIR/$code"
    [ -d "$src" ] || { log "No captures for $code — run the screens pass first"; continue; }
    rm -rf "$DATA_DIR/Documents/source"; mkdir -p "$DATA_DIR/Documents/source"
    cp "$src"/*.png "$DATA_DIR/Documents/source/" 2>/dev/null || true
    log "Locale $code (store frames)"
    EXTRA=(-shotStoreFrames 1)
  else
    log "Locale $code ($region, $APPEARANCE)"
    EXTRA=(-shotAppearance "$APPEARANCE")
  fi

  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  rm -rf "${SHOTS:?}/$code"

  xcrun simctl launch "$UDID" "$BUNDLE_ID" \
    -AppleLanguages "($code)" -AppleLocale "$region" \
    -shotMode 1 -shotLocale "$code" "${EXTRA[@]}" >/dev/null

  for _ in $(seq 1 180); do [ -f "$SHOTS/$code/_done" ] && break; sleep 1; done
  [ -f "$SHOTS/$code/_done" ] || fail "timed out waiting for $code (partial output kept)"

  dest="$OUT_DIR/$code$SUFFIX"
  [ "$MODE" = "store" ] && dest="$OUT_DIR/_store/$code"
  rm -rf "$dest"; mkdir -p "$dest"
  cp -R "$SHOTS/$code/"*.png "$dest/" 2>/dev/null || true
  count=$(ls "$dest"/*.png 2>/dev/null | wc -l | tr -d ' ')
  log "  → $count frames in ${dest#$REPO_DIR/}"

  # A blank PNG looks like a successful capture in a folder listing. Never let one pass.
  if [ -f "$SHOTS/$code/_blank" ]; then
    fail "blank or overflowing frames in $code:"; sed 's/^/       /' "$SHOTS/$code/_blank"
  fi
  # A palette that would be unreadable at App Store thumbnail size.
  if [ -f "$SHOTS/$code/_contrast" ]; then
    fail "contrast problems in $code:"; sed 's/^/       /' "$SHOTS/$code/_contrast"
  fi
  if [ "$MODE" != "store" ] && [ "$EXPECTED" -gt 0 ] && [ "$count" -ne "$EXPECTED" ]; then
    fail "expected $EXPECTED screens in $code, got $count"
  fi
done

xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl status_bar "$UDID" clear >/dev/null 2>&1 || true

if [ "$FAILED" = "1" ]; then
  echo; echo "Capture incomplete — do not upload this set. Re-run; if it persists, keep"
  echo "the Simulator window visible and frontmost while capturing."
  exit 1
fi
log "Done → $OUT_DIR/"
