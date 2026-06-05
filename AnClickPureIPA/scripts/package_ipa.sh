#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$(find "$PROJECT_DIR/.theos/obj" -name 'AnClickPureIPA.app' -type d -print -quit)"
DYLIB_PATH="${ANCLICK_DYLIB_PATH:-}"
FILTER_PATH="$PROJECT_DIR/../Filter.plist"

if [[ -z "${APP_PATH}" ]]; then
  echo "AnClickPureIPA.app not found. Run make first." >&2
  exit 1
fi

if [[ -z "${DYLIB_PATH}" ]]; then
  if [[ -f "$PROJECT_DIR/../build-artifacts/AnClick.dylib" ]]; then
    DYLIB_PATH="$PROJECT_DIR/../build-artifacts/AnClick.dylib"
  else
    DYLIB_PATH="$(find "$PROJECT_DIR/../.theos/obj" -name 'AnClick.dylib' -type f ! -path '*.dSYM/*' -print -quit 2>/dev/null || true)"
  fi
fi

if [[ -z "${DYLIB_PATH}" || ! -f "${DYLIB_PATH}" ]]; then
  echo "Bundled AnClick.dylib not found. Build the root dylib first." >&2
  exit 1
fi

if [[ ! -f "${FILTER_PATH}" ]]; then
  echo "Filter.plist not found at ${FILTER_PATH}" >&2
  exit 1
fi

rm -rf "$PROJECT_DIR/build/Payload"
mkdir -p "$PROJECT_DIR/build/Payload"
cp -R "$APP_PATH" "$PROJECT_DIR/build/Payload/AnClickPureIPA.app"
cp "$DYLIB_PATH" "$PROJECT_DIR/build/Payload/AnClickPureIPA.app/AnClick.dylib"
cp "$FILTER_PATH" "$PROJECT_DIR/build/Payload/AnClickPureIPA.app/Filter.plist"

(
  cd "$PROJECT_DIR/build"
  rm -f AnClickPureIPA.ipa
  zip -qry AnClickPureIPA.ipa Payload
)

echo "$PROJECT_DIR/build/AnClickPureIPA.ipa"
