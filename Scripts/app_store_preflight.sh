#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/App/MyDailyPhrase/MyDailyPhrase.xcodeproj"
SCHEME_NAME="MyDailyPhrase"
RELEASE_XCCONFIG="${ROOT_DIR}/App/MyDailyPhrase/Config/MyDailyPhrase.Release.xcconfig"
TERMS_FILE="${ROOT_DIR}/LEGAL_TERMS.md"
PRIVACY_FILE="${ROOT_DIR}/LEGAL_PRIVACY_POLICY.md"

OUTPUT_BASE_DIR="${1:-${ROOT_DIR}/AppStoreReadinessReports}"
TIMESTAMP="$(date +"%Y%m%d-%H%M%S")"
REPORT_DIR="${OUTPUT_BASE_DIR}/${TIMESTAMP}"
LOG_DIR="${REPORT_DIR}/logs"
REPORT_FILE="${REPORT_DIR}/report.md"

DEVICE_NAME="${DEVICE_NAME:-iPhone 17}"
SKIP_UI_TESTS="${SKIP_UI_TESTS:-0}"

mkdir -p "${LOG_DIR}"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
CHECK_LINES=()
LOG_FILES=()

record_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  CHECK_LINES+=("- [PASS] $1")
  echo "[PASS] $1"
}

record_warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  CHECK_LINES+=("- [WARN] $1")
  echo "[WARN] $1"
}

record_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  CHECK_LINES+=("- [FAIL] $1")
  echo "[FAIL] $1"
}

xcconfig_value() {
  local key="$1"
  awk -F '=' -v key="$key" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      v=$2
      sub(/^[[:space:]]+/, "", v)
      sub(/[[:space:]]+$/, "", v)
      print v
      exit
    }
  ' "${RELEASE_XCCONFIG}"
}

is_placeholder_value() {
  local value="$1"
  [[ "${value}" == *'$('* ]] || [[ "${value}" == "" ]]
}

check_required_setting() {
  local key="$1"
  local label="$2"
  local value
  value="$(xcconfig_value "${key}")"
  if is_placeholder_value "${value}"; then
    record_fail "${label} が未設定です (${key})"
    return
  fi
  record_pass "${label} を確認 (${key})"
}

check_https_setting() {
  local key="$1"
  local label="$2"
  local value
  value="$(xcconfig_value "${key}")"
  if is_placeholder_value "${value}"; then
    record_fail "${label} が未設定です (${key})"
    return
  fi
  if [[ "${value}" != https://* ]]; then
    record_fail "${label} must start with https:// (${key})"
    return
  fi
  record_pass "${label} は HTTPS 公開URLです (${key})"
}

check_legal_date_recency() {
  local file="$1"
  local label="$2"
  local updated raw_ts now_ts age_days

  if [[ ! -f "${file}" ]]; then
    record_fail "${label} file is missing (${file})"
    return
  fi

  updated="$(awk -F ': ' '/^最終更新日:/ {print $2; exit}' "${file}")"
  if [[ -z "${updated}" ]]; then
    record_warn "${label} does not include a last-updated date"
    return
  fi

  if ! raw_ts="$(date -j -f "%Y-%m-%d" "${updated}" +%s 2>/dev/null)"; then
    record_warn "${label} has invalid last-updated format (${updated})"
    return
  fi

  now_ts="$(date +%s)"
  age_days=$(( (now_ts - raw_ts) / 86400 ))
  if [[ "${age_days}" -gt 365 ]]; then
    record_warn "${label} appears stale (${updated}, ${age_days} days ago)"
  else
    record_pass "${label} last-updated date is acceptable (${updated})"
  fi
}

run_command() {
  local title="$1"
  shift
  local slug
  slug="$(echo "${title}" | tr ' /:' '___')"
  local log_file="${LOG_DIR}/${slug}.log"
  LOG_FILES+=("${log_file}")

  echo "[RUN] ${title}"
  if "$@" >"${log_file}" 2>&1; then
    record_pass "${title}"
  else
    record_fail "${title} (log: ${log_file})"
  fi
}

echo "[preflight] output: ${REPORT_DIR}"
echo "[preflight] device: ${DEVICE_NAME}"
echo "[preflight] skip UI tests: ${SKIP_UI_TESTS}"

if [[ ! -f "${RELEASE_XCCONFIG}" ]]; then
  echo "[preflight] release xcconfig not found: ${RELEASE_XCCONFIG}"
  exit 1
fi

AUTH_GOOGLE_START_URL="$(xcconfig_value "AUTH_GOOGLE_OAUTH_START_URL")"
AUTH_X_START_URL="$(xcconfig_value "AUTH_X_OAUTH_START_URL")"

GOOGLE_LOGIN_ENABLED="NO"
X_LOGIN_ENABLED="NO"

if is_placeholder_value "${AUTH_GOOGLE_START_URL}"; then
  record_pass "Google login is disabled for this release"
else
  GOOGLE_LOGIN_ENABLED="YES"
  check_https_setting "AUTH_GOOGLE_OAUTH_START_URL" "Google OAuth start URL"
fi

if is_placeholder_value "${AUTH_X_START_URL}"; then
  record_pass "X login is disabled for this release"
else
  X_LOGIN_ENABLED="YES"
  check_https_setting "AUTH_X_OAUTH_START_URL" "X OAuth start URL"
fi

if [[ "${GOOGLE_LOGIN_ENABLED}" == "YES" || "${X_LOGIN_ENABLED}" == "YES" ]]; then
  check_https_setting "AUTH_BACKEND_VERIFY_ENDPOINT" "Auth verify endpoint"
else
  record_pass "Auth verify endpoint is optional because external OAuth login is disabled"
fi

check_https_setting "LEGAL_TERMS_URL" "Terms URL"
check_https_setting "LEGAL_PRIVACY_POLICY_URL" "Privacy URL"
check_required_setting "AUTH_OAUTH_CALLBACK_SCHEME" "OAuth callback scheme"

AUTH_ALLOW_MANUAL_TOKEN_INPUT="$(xcconfig_value "AUTH_ALLOW_MANUAL_TOKEN_INPUT")"
if [[ "${AUTH_ALLOW_MANUAL_TOKEN_INPUT}" == "NO" ]]; then
  record_pass "Manual auth token input is disabled in Release"
else
  record_fail "Manual auth token input is enabled in Release (AUTH_ALLOW_MANUAL_TOKEN_INPUT=${AUTH_ALLOW_MANUAL_TOKEN_INPUT})"
fi

AUTH_BEARER="$(xcconfig_value "AUTH_BACKEND_VERIFY_BEARER")"
AUTH_BEARER_REQUIRED_RAW="$(xcconfig_value "AUTH_BACKEND_VERIFY_BEARER_REQUIRED")"
AUTH_BEARER_REQUIRED_NORMALIZED="$(echo "${AUTH_BEARER_REQUIRED_RAW}" | tr '[:lower:]' '[:upper:]' | tr -d '[:space:]')"
case "${AUTH_BEARER_REQUIRED_NORMALIZED}" in
  YES|TRUE|1)
    AUTH_BEARER_REQUIRED="YES"
    ;;
  NO|FALSE|0|"")
    AUTH_BEARER_REQUIRED="NO"
    ;;
  *)
    AUTH_BEARER_REQUIRED="NO"
    record_warn "AUTH_BACKEND_VERIFY_BEARER_REQUIRED has invalid value (${AUTH_BEARER_REQUIRED_RAW}). Treating as optional."
    ;;
esac

if [[ "${GOOGLE_LOGIN_ENABLED}" == "YES" || "${X_LOGIN_ENABLED}" == "YES" ]]; then
  if [[ "${AUTH_BEARER_REQUIRED}" == "YES" ]]; then
    if is_placeholder_value "${AUTH_BEARER}"; then
      record_fail "Auth verify bearer is required but empty/placeholder"
    else
      record_pass "Auth verify bearer is set (required)"
    fi
  else
    if [[ -z "${AUTH_BEARER}" ]]; then
      record_pass "Auth verify bearer is optional and empty"
    elif [[ "${AUTH_BEARER}" == *'$('* ]]; then
      record_warn "Auth verify bearer is optional, but unresolved variable syntax is set"
    else
      record_pass "Auth verify bearer is configured (optional)"
    fi
  fi
else
  record_pass "Auth verify bearer check skipped because external OAuth login is disabled"
fi

RETENTION_DEFAULT="$(xcconfig_value "SECURITY_LOG_RETENTION_DAYS_DEFAULT")"
RETENTION_MAX="$(xcconfig_value "SECURITY_LOG_RETENTION_DAYS_MAX")"
if [[ "${RETENTION_DEFAULT}" =~ ^[0-9]+$ ]] && [[ "${RETENTION_MAX}" =~ ^[0-9]+$ ]]; then
  if [[ "${RETENTION_DEFAULT}" -gt "${RETENTION_MAX}" ]]; then
    record_fail "Security log retention config is invalid (default=${RETENTION_DEFAULT}, max=${RETENTION_MAX})"
  elif [[ "${RETENTION_MAX}" -gt 365 ]]; then
    record_warn "Security log max retention is over 365 days (max=${RETENTION_MAX})"
  else
    record_pass "Security log retention is valid (default=${RETENTION_DEFAULT}, max=${RETENTION_MAX})"
  fi
else
  record_warn "Security log retention values are not numeric"
fi

check_legal_date_recency "${TERMS_FILE}" "Terms"
check_legal_date_recency "${PRIVACY_FILE}" "Privacy policy"

UDID="$(xcrun simctl list devices available | awk -v name="${DEVICE_NAME}" -F '[()]' '$0 ~ name {print $2; exit}')"
if [[ -z "${UDID}" ]]; then
  UDID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ {print $2; exit}')"
fi
if [[ -z "${UDID}" ]]; then
  record_fail "No available iPhone simulator was found"
else
  record_pass "Simulator detected (${UDID})"
  xcrun simctl boot "${UDID}" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "${UDID}" -b >/dev/null 2>&1 || true

  run_command "Release Build" \
    xcodebuild \
      -project "${PROJECT_PATH}" \
      -scheme "${SCHEME_NAME}" \
      -configuration Release \
      -destination "id=${UDID}" \
      -parallel-testing-enabled NO \
      build

  if [[ "${SKIP_UI_TESTS}" != "1" ]]; then
    run_command "Critical UI Tests" \
      xcodebuild \
        -project "${PROJECT_PATH}" \
        -scheme "${SCHEME_NAME}" \
        -destination "id=${UDID}" \
        -parallel-testing-enabled NO \
        test \
        -only-testing:MyDailyPhraseUITests/AuthGateUITests \
        -only-testing:MyDailyPhraseUITests/OnboardingFlowUITests \
        -only-testing:MyDailyPhraseUITests/GachaFlowUITests \
        -only-testing:MyDailyPhraseUITests/ProfileReleaseReadinessUITests
  else
    record_warn "Critical UI Tests skipped because SKIP_UI_TESTS=1"
  fi
fi

{
  echo "# App Store Preflight Report"
  echo
  echo "- Generated at: $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "- Report directory: ${REPORT_DIR}"
  echo "- Device: ${DEVICE_NAME}"
  echo "- Simulator UDID: ${UDID:-N/A}"
  echo
  echo "## Summary"
  echo "- Pass: ${PASS_COUNT}"
  echo "- Warning: ${WARN_COUNT}"
  echo "- Fail: ${FAIL_COUNT}"
  echo
  echo "## Checks"
  for line in "${CHECK_LINES[@]}"; do
    echo "${line}"
  done
  echo
  echo "## Release Settings Snapshot"
  echo "- AUTH_BACKEND_VERIFY_ENDPOINT: $(xcconfig_value "AUTH_BACKEND_VERIFY_ENDPOINT")"
  echo "- AUTH_GOOGLE_OAUTH_START_URL: $(xcconfig_value "AUTH_GOOGLE_OAUTH_START_URL")"
  echo "- AUTH_X_OAUTH_START_URL: $(xcconfig_value "AUTH_X_OAUTH_START_URL")"
  echo "- AUTH_OAUTH_CALLBACK_SCHEME: $(xcconfig_value "AUTH_OAUTH_CALLBACK_SCHEME")"
  echo "- LEGAL_TERMS_URL: $(xcconfig_value "LEGAL_TERMS_URL")"
  echo "- LEGAL_PRIVACY_POLICY_URL: $(xcconfig_value "LEGAL_PRIVACY_POLICY_URL")"
  echo "- AUTH_ALLOW_MANUAL_TOKEN_INPUT: $(xcconfig_value "AUTH_ALLOW_MANUAL_TOKEN_INPUT")"
  echo "- AUTH_BACKEND_VERIFY_BEARER_REQUIRED: $(xcconfig_value "AUTH_BACKEND_VERIFY_BEARER_REQUIRED")"
  echo "- SECURITY_LOG_RETENTION_DAYS_DEFAULT: $(xcconfig_value "SECURITY_LOG_RETENTION_DAYS_DEFAULT")"
  echo "- SECURITY_LOG_RETENTION_DAYS_MAX: $(xcconfig_value "SECURITY_LOG_RETENTION_DAYS_MAX")"
  echo
  if ((${#LOG_FILES[@]} > 0)); then
    echo "## Logs"
    for f in "${LOG_FILES[@]}"; do
      echo "- ${f}"
    done
  fi
} > "${REPORT_FILE}"

echo "[preflight] report: ${REPORT_FILE}"

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  echo "[preflight] failed with ${FAIL_COUNT} issue(s)."
  exit 1
fi

echo "[preflight] succeeded."
