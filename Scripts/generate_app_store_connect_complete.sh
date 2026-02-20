#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
METADATA_FILE="${ROOT_DIR}/AppStoreSubmission/metadata_ja-JP.md"
REVIEW_NOTES_FILE="${ROOT_DIR}/AppStoreSubmission/review_notes_ja-JP.md"
RELEASE_XCCONFIG="${ROOT_DIR}/App/MyDailyPhrase/Config/MyDailyPhrase.Release.xcconfig"
PBXPROJ_FILE="${ROOT_DIR}/App/MyDailyPhrase/MyDailyPhrase.xcodeproj/project.pbxproj"
IAP_STORE_FILE="${ROOT_DIR}/App/MyDailyPhrase/MyDailyPhrase/IAPStore.swift"
READINESS_ROOT="${ROOT_DIR}/AppStoreReadinessReports"
OUTPUT_FILE="${1:-${ROOT_DIR}/AppStoreSubmission/app_store_connect_complete_ja-JP.md}"

section_body() {
  local section="$1"
  awk -v section="${section}" '
    $0 == "## " section { in_section=1; next }
    in_section && /^## / { exit }
    in_section { print }
  ' "${METADATA_FILE}"
}

section_first_line() {
  local section="$1"
  section_body "${section}" | sed '/^[[:space:]]*$/d' | head -n 1
}

xcconfig_value() {
  local key="$1"
  awk -F '=' -v key="${key}" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      v=$2
      sub(/^[[:space:]]+/, "", v)
      sub(/[[:space:]]+$/, "", v)
      print v
      exit
    }
  ' "${RELEASE_XCCONFIG}"
}

latest_dir() {
  local base="$1"
  [[ -d "${base}" ]] || return 1
  ls -1 "${base}" | sort | tail -n 1
}

if [[ ! -f "${METADATA_FILE}" ]]; then
  echo "[generate] metadata file not found: ${METADATA_FILE}"
  exit 1
fi

APP_NAME="$(section_first_line "App Name")"
SUBTITLE="$(section_first_line "Subtitle")"
PROMO_TEXT="$(section_body "Promotional Text")"
DESCRIPTION="$(section_body "Description")"
KEYWORDS="$(section_first_line "Keywords")"
WHATS_NEW="$(section_body "What's New")"
SUPPORT_URL="$(section_first_line "Support URL")"
MARKETING_URL="$(section_first_line "Marketing URL")"
PRIVACY_URL="$(section_first_line "Privacy Policy URL")"
TERMS_URL="$(section_first_line "Terms of Service URL")"

BUNDLE_ID="$(awk '/PRODUCT_BUNDLE_IDENTIFIER = jp\.catloverbot\.MyDailyPhrase;/ {gsub(/;/, "", $3); print $3; exit}' "${PBXPROJ_FILE}")"
if [[ -z "${BUNDLE_ID}" ]]; then
  BUNDLE_ID="jp.catloverbot.MyDailyPhrase"
fi

CALLBACK_SCHEME="$(xcconfig_value "AUTH_OAUTH_CALLBACK_SCHEME")"
GOOGLE_START_URL="$(xcconfig_value "AUTH_GOOGLE_OAUTH_START_URL")"
X_START_URL="$(xcconfig_value "AUTH_X_OAUTH_START_URL")"
VERIFY_URL="$(xcconfig_value "AUTH_BACKEND_VERIFY_ENDPOINT")"
AUTH_MODE_DETAIL="Releaseでは外部OAuthは無効化（Sign in with Appleのみ表示）"
if [[ -n "${GOOGLE_START_URL}" || -n "${X_START_URL}" ]]; then
  AUTH_MODE_DETAIL="Releaseで外部OAuth有効（Google/X）"
fi

IAP_IDS="$(rg -o 'mydailyphrase\.[a-z0-9.]+' "${IAP_STORE_FILE}" | sort -u || true)"
IAP_TABLE_LINES=""
if [[ -n "${IAP_IDS}" ]]; then
  while IFS= read -r product_id; do
    [[ -n "${product_id}" ]] || continue
    product_type="消耗型"
    notes="ガチャチケット付与"
    case "${product_id}" in
      mydailyphrase.creatorpass.monthly)
        product_type="自動更新サブスクリプション"
        notes="Creator Pass（月額）"
        ;;
      mydailyphrase.creatorpass.yearly)
        product_type="自動更新サブスクリプション"
        notes="Creator Pass（年額）"
        ;;
      mydailyphrase.gacha.ticket*)
        product_type="消耗型"
        notes="ガチャチケットパック"
        ;;
    esac
    IAP_TABLE_LINES+=$"| \`${product_id}\` | ${product_type} | ${notes} |\n"
  done <<< "${IAP_IDS}"
fi
if [[ -z "${IAP_TABLE_LINES}" ]]; then
  IAP_TABLE_LINES="| - | - | IAP未検出 |\n"
fi

LATEST_READINESS="$(latest_dir "${READINESS_ROOT}" || true)"
LATEST_READINESS_REPORT=""
READINESS_PASS="N/A"
READINESS_WARN="N/A"
READINESS_FAIL="N/A"
if [[ -n "${LATEST_READINESS}" && -f "${READINESS_ROOT}/${LATEST_READINESS}/report.md" ]]; then
  LATEST_READINESS_REPORT="${READINESS_ROOT}/${LATEST_READINESS}/report.md"
  READINESS_PASS="$(awk -F ': ' '/^- Pass:/{print $2; exit}' "${LATEST_READINESS_REPORT}")"
  READINESS_WARN="$(awk -F ': ' '/^- Warning:/{print $2; exit}' "${LATEST_READINESS_REPORT}")"
  READINESS_FAIL="$(awk -F ': ' '/^- Fail:/{print $2; exit}' "${LATEST_READINESS_REPORT}")"
fi

REVIEW_NOTES_SUMMARY="(未作成)"
if [[ -f "${REVIEW_NOTES_FILE}" ]]; then
  REVIEW_NOTES_SUMMARY="$(sed -n '1,80p' "${REVIEW_NOTES_FILE}")"
fi

NOW="$(date '+%Y-%m-%d %H:%M:%S %z')"
mkdir -p "$(dirname "${OUTPUT_FILE}")"

cat > "${OUTPUT_FILE}" <<EOF
# App Store Connect 提出完全版 (ja-JP)

- 生成日時: ${NOW}
- バンドルID: \`${BUNDLE_ID}\`
- SKU推奨: \`${BUNDLE_ID}\`
- 対象ロケール: ja-JP

## 1. App Information（入力値）

- Name: ${APP_NAME}
- Subtitle: ${SUBTITLE}
- Primary Category: ライフスタイル
- Secondary Category: ソーシャルネットワーキング
- Content Rights: 自社保有（第三者コンテンツ利用なし）

## 2. Version Information（入力値）

### Promotional Text
${PROMO_TEXT}

### Description
${DESCRIPTION}

### Keywords
\`${KEYWORDS}\`

### What's New
${WHATS_NEW}

## 3. URL設定（入力値）

- Support URL: ${SUPPORT_URL}
- Marketing URL: ${MARKETING_URL}
- Privacy Policy URL: ${PRIVACY_URL}
- Terms of Service URL: ${TERMS_URL}

## 4. 認証・ログイン実装（審査説明用）

- ログイン必須: はい（初回ログインゲートあり）
- 対応: Sign in with Apple
- OAuthコールバックスキーム: \`${CALLBACK_SCHEME}\`
- 外部OAuth設定: ${AUTH_MODE_DETAIL}
- Google OAuth Start URL: ${GOOGLE_START_URL:-"(未設定)"}
- X OAuth Start URL: ${X_START_URL:-"(未設定)"}
- Auth Verify Endpoint: ${VERIFY_URL:-"(未設定)"}

## 5. App内課金（IAP）

| Product ID | 種別 | 備考 |
| --- | --- | --- |
$(printf "%b" "${IAP_TABLE_LINES}")

- 課金導線: Profile / Gacha / コミュニティ急上昇詳細
- サブスクリプション: Creator Pass（月額・年額）
- 消耗型: ガチャチケットパック

## 6. App Privacy（App Store Connect入力ガイド）

- Tracking: いいえ
- Data Used to Track You: なし
- Data Linked to You（実装ベース）
- 識別子: ユーザーID、外部認証連携ID（provider/subject）
- ユーザーコンテンツ: 投稿文、タグ、リアクション、コメント
- 購入情報: Creator Pass状態、チケット購入反映
- 診断: セキュリティ監査ログ（連携/解除/失効/エラー）
- 収集目的: アプリ機能提供、不正利用防止、運用監査、サポート対応

## 7. App Review Information（貼り付け用）

### Review Notes
${REVIEW_NOTES_SUMMARY}

### 連絡先
- support: support@mydailyphrase.app

## 8. 提出前の実行結果（最新）

- Preflight Report: ${LATEST_READINESS_REPORT:-"(未検出)"}
- Summary: Pass=${READINESS_PASS} / Warning=${READINESS_WARN} / Fail=${READINESS_FAIL}
- Metadata Validation: \`./Scripts/validate_app_store_metadata.sh\` を必ずPASS
- Endpoint Reachability: \`./Scripts/check_production_endpoints.sh\` を実ネットワーク環境で実行

## 9. 最終提出チェックリスト

- [ ] App Store Connect の Name / Subtitle / Description / Keywords を本シート値で入力
- [ ] Privacy Policy / Terms URL を本シート値で入力
- [ ] IAP商品IDが「Ready to Submit」以上で有効
- [ ] Age Rating 質問票を最新機能に合わせて入力
- [ ] App Privacy 質問票を本シート「6. App Privacy」に沿って入力
- [ ] 最新Build（Release）をVersionに紐付け
- [ ] Review Notes を貼り付け
- [ ] 外部URL疎通確認（check_production_endpoints）を実ネットワークでPASS
- [ ] \`AppStoreSubmission/<timestamp>/\` の提出バンドルを最終保存

EOF

echo "[generate] created: ${OUTPUT_FILE}"
