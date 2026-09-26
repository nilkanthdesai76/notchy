#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------
# Notchy DMG Builder Script
# Builds Notchy in Release mode and packages it into a clean .dmg
# ---------------------------------------------------------

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${PROJECT_DIR}/dist"
STAGING_DIR="${PROJECT_DIR}/build/dmg_staging"
APP_NAME="Notchy"
DMG_NAME="${APP_NAME}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"

echo "==> Building ${APP_NAME} (Release)..."
cd "${PROJECT_DIR}"

xcodebuild -scheme "${APP_NAME}" \
  -configuration Release \
  -derivedDataPath "${PROJECT_DIR}/build/ReleaseDerivedData" \
  build -quiet

BUILT_APP="${PROJECT_DIR}/build/ReleaseDerivedData/Build/Products/Release/${APP_NAME}.app"

if [ ! -d "${BUILT_APP}" ]; then
  echo "Error: Built application not found at ${BUILT_APP}"
  exit 1
fi

echo "==> Preparing DMG staging directory..."
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
mkdir -p "${DIST_DIR}"

# Copy application bundle
cp -R "${BUILT_APP}" "${STAGING_DIR}/"

# Create symlink to /Applications for easy drag-to-install
ln -s /Applications "${STAGING_DIR}/Applications"

echo "==> Packaging ${DMG_NAME} using hdiutil..."
rm -f "${DMG_PATH}"

hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

echo "==> Cleaning up staging files..."
rm -rf "${STAGING_DIR}"

DMG_SIZE=$(du -h "${DMG_PATH}" | cut -f1)
echo "✅ Successfully built: ${DMG_PATH} (${DMG_SIZE})"
echo "You can share ${DMG_PATH} directly or upload it to your website / GitHub Releases."
