#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/App/MyDailyPhrase/MyDailyPhrase.xcodeproj"
SCHEME_NAME="MyDailyPhrase"

OUTPUT_BASE_DIR="${1:-${ROOT_DIR}/AppStoreScreenshots}"
TIMESTAMP="$(date +"%Y%m%d-%H%M%S")"
OUTPUT_DIR="${OUTPUT_BASE_DIR}/${TIMESTAMP}"
mkdir -p "${OUTPUT_DIR}"
MODE_FILE="/tmp/MyDailyPhrase.screenshot_mode"

DEVICE_NAME="${DEVICE_NAME:-iPhone 17}"

echo "[screenshots] output: ${OUTPUT_DIR}"
echo "[screenshots] device: ${DEVICE_NAME}"

printf '%s\n' "${OUTPUT_DIR}" > "${MODE_FILE}"
trap 'rm -f "${MODE_FILE}"' EXIT

UDID="$(xcrun simctl list devices available | awk -v name="${DEVICE_NAME}" -F '[()]' '$0 ~ name { print $2; exit }')"
if [[ -z "${UDID}" ]]; then
  echo "[screenshots] '${DEVICE_NAME}' が見つからないため、最初のiPhoneを使用します"
  UDID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ { print $2; exit }')"
fi

if [[ -z "${UDID}" ]]; then
  echo "[screenshots] 利用可能なiPhoneシミュレータが見つかりません"
  exit 1
fi

echo "[screenshots] boot simulator: ${UDID}"
xcrun simctl boot "${UDID}" || true
xcrun simctl bootstatus "${UDID}" -b

echo "[screenshots] running UITest"
ENABLE_SCREENSHOT_CAPTURE=1 \
SCREENSHOT_OUTPUT_DIR="${OUTPUT_DIR}" \
xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME_NAME}" \
  -destination "id=${UDID}" \
  -parallel-testing-enabled NO \
  test \
  -only-testing:MyDailyPhraseUITests/AppStoreScreenshotsUITests/testCaptureAppStoreScreenshots

echo "[screenshots] done: ${OUTPUT_DIR}"
