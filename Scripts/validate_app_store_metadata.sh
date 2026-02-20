#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
METADATA_FILE="${1:-${ROOT_DIR}/AppStoreSubmission/metadata_ja-JP.md}"

if [[ ! -f "${METADATA_FILE}" ]]; then
  echo "[metadata] file not found: ${METADATA_FILE}"
  exit 1
fi

section_body() {
  local title="$1"
  awk -v header="## ${title}" '
    $0 == header { capture = 1; next }
    capture && /^## / { exit }
    capture { print }
  ' "${METADATA_FILE}"
}

first_non_empty_line() {
  awk 'NF { print; exit }'
}

trim_spaces() {
  sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

count_chars() {
  printf "%s" "$1" | wc -m | tr -d ' '
}

count_bytes() {
  printf "%s" "$1" | wc -c | tr -d ' '
}

fail_count=0

check_required_single_line() {
  local title="$1"
  local value
  value="$(section_body "${title}" | first_non_empty_line | trim_spaces)"
  if [[ -z "${value}" ]]; then
    echo "[FAIL] ${title}: empty"
    fail_count=$((fail_count + 1))
    return
  fi
  echo "[PASS] ${title}: ${value}"
}

check_char_limit_single_line() {
  local title="$1"
  local limit="$2"
  local value chars
  value="$(section_body "${title}" | first_non_empty_line | trim_spaces)"
  chars="$(count_chars "${value}")"
  if [[ -z "${value}" ]]; then
    echo "[FAIL] ${title}: empty"
    fail_count=$((fail_count + 1))
    return
  fi
  if (( chars > limit )); then
    echo "[FAIL] ${title}: ${chars} chars (limit ${limit})"
    fail_count=$((fail_count + 1))
    return
  fi
  echo "[PASS] ${title}: ${chars} chars (limit ${limit})"
}

check_char_limit_multi_line() {
  local title="$1"
  local limit="$2"
  local value chars
  value="$(section_body "${title}")"
  value="$(printf "%s" "${value}" | sed '/^[[:space:]]*$/d')"
  chars="$(count_chars "${value}")"
  if [[ -z "${value}" ]]; then
    echo "[FAIL] ${title}: empty"
    fail_count=$((fail_count + 1))
    return
  fi
  if (( chars > limit )); then
    echo "[FAIL] ${title}: ${chars} chars (limit ${limit})"
    fail_count=$((fail_count + 1))
    return
  fi
  echo "[PASS] ${title}: ${chars} chars (limit ${limit})"
}

check_keyword_bytes() {
  local title="Keywords"
  local value bytes
  value="$(section_body "${title}" | first_non_empty_line | trim_spaces | tr -d ' ')"
  bytes="$(count_bytes "${value}")"
  if [[ -z "${value}" ]]; then
    echo "[FAIL] ${title}: empty"
    fail_count=$((fail_count + 1))
    return
  fi
  if (( bytes > 100 )); then
    echo "[FAIL] ${title}: ${bytes} bytes (limit 100)"
    fail_count=$((fail_count + 1))
    return
  fi
  echo "[PASS] ${title}: ${bytes} bytes (limit 100)"
}

check_https_url() {
  local title="$1"
  local value
  value="$(section_body "${title}" | first_non_empty_line | trim_spaces)"
  if [[ -z "${value}" ]]; then
    echo "[FAIL] ${title}: empty"
    fail_count=$((fail_count + 1))
    return
  fi
  if [[ "${value}" =~ ^https:// ]]; then
    echo "[PASS] ${title}: ${value}"
  else
    echo "[FAIL] ${title}: must start with https:// (${value})"
    fail_count=$((fail_count + 1))
  fi
}

echo "[metadata] validating: ${METADATA_FILE}"

check_required_single_line "App Name"
check_char_limit_single_line "Subtitle" 30
check_char_limit_single_line "Promotional Text" 170
check_char_limit_multi_line "Description" 4000
check_keyword_bytes
check_char_limit_multi_line "What's New" 4000
check_https_url "Support URL"
check_https_url "Marketing URL"
check_https_url "Privacy Policy URL"
check_https_url "Terms of Service URL"

if (( fail_count > 0 )); then
  echo "[metadata] failed: ${fail_count}"
  exit 1
fi

echo "[metadata] all checks passed"
