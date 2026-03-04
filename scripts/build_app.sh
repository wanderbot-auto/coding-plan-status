#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CodingPlanStatusApp"
BUNDLE_ID="com.wander.codingplanstatus"
VERSION="1.0.0"
BUILD_NUMBER="1"
MIN_MACOS="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
APP_ICON_SOURCE="${ROOT_DIR}/assets/AppIcon.icns"

BUILD_CONFIG="release"
OPEN_AFTER_BUILD="0"
NO_SIGN="0"

usage() {
  cat <<USAGE
Usage: scripts/build_app.sh [options]

Options:
  --debug         Build debug instead of release
  --open          Open app after build
  --no-sign       Skip ad-hoc codesign
  -h, --help      Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      BUILD_CONFIG="debug"
      shift
      ;;
    --open)
      OPEN_AFTER_BUILD="1"
      shift
      ;;
    --no-sign)
      NO_SIGN="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

echo "[1/5] Building ${APP_NAME} (${BUILD_CONFIG})..."
cd "${ROOT_DIR}"
swift build -c "${BUILD_CONFIG}" --product "${APP_NAME}"

BIN_PATH="${ROOT_DIR}/.build/arm64-apple-macosx/${BUILD_CONFIG}/${APP_NAME}"
if [[ ! -f "${BIN_PATH}" ]]; then
  echo "Build output not found: ${BIN_PATH}" >&2
  exit 1
fi
if [[ ! -f "${APP_ICON_SOURCE}" ]]; then
  echo "App icon not found: ${APP_ICON_SOURCE}" >&2
  exit 1
fi

echo "[2/5] Preparing app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"
cp "${APP_ICON_SOURCE}" "${RESOURCES_DIR}/AppIcon.icns"

echo "[3/5] Writing Info.plist..."
cat > "${CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>${MIN_MACOS}</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

if [[ "${NO_SIGN}" == "0" ]]; then
  echo "[4/5] Ad-hoc codesign..."
  codesign --force --deep --sign - "${APP_DIR}"
else
  echo "[4/5] Skipping codesign (--no-sign)."
fi

echo "[5/5] Done: ${APP_DIR}"

if [[ "${OPEN_AFTER_BUILD}" == "1" ]]; then
  echo "Opening app..."
  open "${APP_DIR}"
fi
