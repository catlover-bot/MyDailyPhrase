#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
READINESS_ROOT="${ROOT_DIR}/AppStoreReadinessReports"
SCREENSHOTS_ROOT="${ROOT_DIR}/AppStoreScreenshots"
SUBMISSION_ROOT="${1:-${ROOT_DIR}/AppStoreSubmission}"
TIMESTAMP="$(date +"%Y%m%d-%H%M%S")"
OUTPUT_DIR="${SUBMISSION_ROOT}/${TIMESTAMP}"
COMPLETE_SHEET_GENERATOR="${ROOT_DIR}/Scripts/generate_app_store_connect_complete.sh"

latest_dir() {
  local base="$1"
  if [[ ! -d "${base}" ]]; then
    return 1
  fi
  ls -1 "${base}" | sort | tail -n 1
}

LATEST_READINESS="$(latest_dir "${READINESS_ROOT}" || true)"
LATEST_SCREENSHOTS="$(latest_dir "${SCREENSHOTS_ROOT}" || true)"

if [[ -z "${LATEST_READINESS}" ]]; then
  echo "[bundle] readiness report not found under: ${READINESS_ROOT}"
  exit 1
fi

if [[ -z "${LATEST_SCREENSHOTS}" ]]; then
  echo "[bundle] screenshots not found under: ${SCREENSHOTS_ROOT}"
  exit 1
fi

READINESS_DIR="${READINESS_ROOT}/${LATEST_READINESS}"
SCREENSHOTS_DIR="${SCREENSHOTS_ROOT}/${LATEST_SCREENSHOTS}"

mkdir -p "${OUTPUT_DIR}/readiness" "${OUTPUT_DIR}/screenshots" "${OUTPUT_DIR}/metadata"

cp -R "${READINESS_DIR}/." "${OUTPUT_DIR}/readiness/"
cp -R "${SCREENSHOTS_DIR}/." "${OUTPUT_DIR}/screenshots/"

if [[ -x "${COMPLETE_SHEET_GENERATOR}" ]]; then
  "${COMPLETE_SHEET_GENERATOR}" >/dev/null
fi

for metadata_file in "${ROOT_DIR}/AppStoreSubmission/"*.md; do
  [[ -f "${metadata_file}" ]] || continue
  cp "${metadata_file}" "${OUTPUT_DIR}/metadata/"
done

if [[ ! -f "${OUTPUT_DIR}/metadata/metadata_ja-JP.md" ]]; then
  echo "[bundle] metadata_ja-JP.md not found under AppStoreSubmission/"
  exit 1
fi

PNG_COUNT="$(find "${OUTPUT_DIR}/screenshots" -maxdepth 1 -type f -name '*.png' | wc -l | tr -d ' ')"
REPORT_FILE="${OUTPUT_DIR}/readiness/report.md"
SUMMARY_LINE="$(grep -E '^- Warning:|^- Fail:|^- Pass:' "${REPORT_FILE}" 2>/dev/null || true)"
METADATA_FILE_COUNT="$(find "${OUTPUT_DIR}/metadata" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"

{
  echo "# App Store Submission Bundle"
  echo
  echo "- Generated: $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "- Output: ${OUTPUT_DIR}"
  echo "- Readiness source: ${READINESS_DIR}"
  echo "- Screenshots source: ${SCREENSHOTS_DIR}"
  echo "- Screenshot count: ${PNG_COUNT}"
  echo "- Metadata files: ${METADATA_FILE_COUNT}"
  if [[ -n "${SUMMARY_LINE}" ]]; then
    echo
    echo "## Readiness summary"
    echo "${SUMMARY_LINE}"
  fi
  echo
  echo "## Contents"
  echo "- readiness/report.md"
  echo "- readiness/logs/*"
  echo "- screenshots/*.png"
  echo "- metadata/*.md"
} > "${OUTPUT_DIR}/manifest.md"

echo "[bundle] created: ${OUTPUT_DIR}"
