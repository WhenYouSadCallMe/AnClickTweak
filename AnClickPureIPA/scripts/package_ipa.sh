#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$(find "$PROJECT_DIR/.theos/obj" -name 'AnClickPureIPA.app' -type d -print -quit)"

if [[ -z "${APP_PATH}" ]]; then
  echo "AnClickPureIPA.app not found. Run make first." >&2
  exit 1
fi

rm -rf "$PROJECT_DIR/build/Payload"
mkdir -p "$PROJECT_DIR/build/Payload"
cp -R "$APP_PATH" "$PROJECT_DIR/build/Payload/AnClickPureIPA.app"

(
  cd "$PROJECT_DIR/build"
  rm -f AnClickPureIPA.ipa
  zip -qry AnClickPureIPA.ipa Payload
)

echo "$PROJECT_DIR/build/AnClickPureIPA.ipa"
