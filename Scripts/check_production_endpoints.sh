#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_XCCONFIG="${ROOT_DIR}/App/MyDailyPhrase/Config/MyDailyPhrase.Release.xcconfig"

if [[ ! -f "${RELEASE_XCCONFIG}" ]]; then
  echo "[check] release config not found: ${RELEASE_XCCONFIG}"
  exit 1
fi

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

check_url() {
  local label="$1"
  local url="$2"
  local code
  local curl_rc=0
  local err_file
  local err_text

  if [[ -z "${url}" ]]; then
    echo "[FAIL] ${label}: empty URL"
    return 1
  fi

  err_file="$(mktemp)"
  code="$(curl -sS -L --max-time 10 -o /dev/null -w '%{http_code}' "${url}" 2>"${err_file}")" || curl_rc=$?
  err_text="$(tr '\n' ' ' < "${err_file}" | sed 's/[[:space:]]\+/ /g' | sed 's/^ //; s/ $//')"
  rm -f "${err_file}"

  if [[ "${curl_rc}" -ne 0 ]]; then
    case "${curl_rc}" in
      6)
        echo "[FAIL] ${label}: DNS解決に失敗 (${url})"
        ;;
      7)
        echo "[FAIL] ${label}: 接続失敗 (${url})"
        ;;
      28)
        echo "[FAIL] ${label}: タイムアウト (${url})"
        ;;
      35|51|60)
        echo "[FAIL] ${label}: TLS/証明書エラー (${url})"
        ;;
      *)
        echo "[FAIL] ${label}: curl rc=${curl_rc} (${url}) ${err_text}"
        ;;
    esac
    return 1
  fi

  if [[ "${code}" =~ ^2|3 ]]; then
    echo "[PASS] ${label}: ${url} -> ${code}"
    return 0
  fi

  echo "[FAIL] ${label}: ${url} -> ${code}"
  return 1
}

TERMS_URL="$(xcconfig_value "LEGAL_TERMS_URL")"
PRIVACY_URL="$(xcconfig_value "LEGAL_PRIVACY_POLICY_URL")"
VERIFY_URL="$(xcconfig_value "AUTH_BACKEND_VERIFY_ENDPOINT")"
GOOGLE_START_URL="$(xcconfig_value "AUTH_GOOGLE_OAUTH_START_URL")"
X_START_URL="$(xcconfig_value "AUTH_X_OAUTH_START_URL")"

echo "[check] release config: ${RELEASE_XCCONFIG}"
echo "[check] started at: $(date '+%Y-%m-%d %H:%M:%S %z')"

BASELINE_CODE="$(curl -sS -L --max-time 8 -o /dev/null -w '%{http_code}' https://example.com || true)"
if [[ ! "${BASELINE_CODE}" =~ ^2|3 ]]; then
  echo "[warn] baseline network check failed for https://example.com (http=${BASELINE_CODE})"
  echo "[warn] この端末のDNS/ネットワーク制限で外部URL確認が失敗している可能性があります。"
fi

FAIL_COUNT=0

check_url "Terms URL" "${TERMS_URL}" || FAIL_COUNT=$((FAIL_COUNT + 1))
check_url "Privacy URL" "${PRIVACY_URL}" || FAIL_COUNT=$((FAIL_COUNT + 1))

if [[ -n "${GOOGLE_START_URL}" ]]; then
  check_url "Google OAuth start URL" "${GOOGLE_START_URL}" || FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "[SKIP] Google OAuth start URL: disabled for this release"
fi

if [[ -n "${X_START_URL}" ]]; then
  check_url "X OAuth start URL" "${X_START_URL}" || FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "[SKIP] X OAuth start URL: disabled for this release"
fi

if [[ -n "${GOOGLE_START_URL}" || -n "${X_START_URL}" ]]; then
  if [[ -n "${VERIFY_URL}" ]]; then
    check_url "Auth verify endpoint" "${VERIFY_URL}" || FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    echo "[FAIL] Auth verify endpoint: external OAuth is enabled but endpoint is empty"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
else
  if [[ -n "${VERIFY_URL}" ]]; then
    check_url "Auth verify endpoint (optional)" "${VERIFY_URL}" || FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    echo "[SKIP] Auth verify endpoint: disabled for this release"
  fi
fi

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  echo "[check] failed: ${FAIL_COUNT}"
  echo "[hint] DNS fail の場合は、対象ホストの A/AAAA または CNAME レコードと反映状況、ローカルDNS/プロキシ設定を確認してください。"
  exit 1
fi

echo "[check] all endpoints reachable"
