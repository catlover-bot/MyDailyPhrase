# App Store Preflight Report

- 生成日時: 2026-02-20 13:31:59 +0900
- レポート出力先: /Users/hirotaka-m/MyDailyPhrase/AppStoreReadinessReports/20260220-132816
- デバイス: iPhone 17
- シミュレータUDID: 8D714328-9145-4B4B-89EC-BC4F8217E0A6

## Summary
- ✅ Pass: 11
- ⚠️ Warning: 3
- ❌ Fail: 0

## Checks
- ✅ 認証バックエンド検証API は HTTPS 公開URLです (AUTH_BACKEND_VERIFY_ENDPOINT)
- ✅ Google OAuth開始URL は HTTPS 公開URLです (AUTH_GOOGLE_OAUTH_START_URL)
- ✅ X OAuth開始URL は HTTPS 公開URLです (AUTH_X_OAUTH_START_URL)
- ⚠️ 利用規約URL が GitHub URL です。提出前に本番公開URLを推奨 (LEGAL_TERMS_URL)
- ⚠️ プライバシーポリシーURL が GitHub URL です。提出前に本番公開URLを推奨 (LEGAL_PRIVACY_POLICY_URL)
- ✅ OAuth callback scheme を確認 (AUTH_OAUTH_CALLBACK_SCHEME)
- ✅ Releaseで手動トークン入力は無効
- ⚠️ 認証バックエンドBearerが未設定です（不要なら無視可）
- ✅ 監査ログ保持日数を確認 (default=90, max=365)
- ✅ 利用規約 の更新日を確認 (2026-02-13)
- ✅ プライバシーポリシー の更新日を確認 (2026-02-13)
- ✅ シミュレータを検出 (8D714328-9145-4B4B-89EC-BC4F8217E0A6)
- ✅ Release Build
- ✅ Critical UI Tests

## Release Settings Snapshot
- AUTH_BACKEND_VERIFY_ENDPOINT: https://api.mydailyphrase.app/auth/verify
- AUTH_GOOGLE_OAUTH_START_URL: https://api.mydailyphrase.app/oauth/google/start
- AUTH_X_OAUTH_START_URL: https://api.mydailyphrase.app/oauth/x/start
- AUTH_OAUTH_CALLBACK_SCHEME: mydailyphrase
- LEGAL_TERMS_URL: https://github.com/catlover-bot/MyDailyPhrase/blob/main/LEGAL_TERMS.md
- LEGAL_PRIVACY_POLICY_URL: https://github.com/catlover-bot/MyDailyPhrase/blob/main/LEGAL_PRIVACY_POLICY.md
- AUTH_ALLOW_MANUAL_TOKEN_INPUT: NO
- SECURITY_LOG_RETENTION_DAYS_DEFAULT: 90
- SECURITY_LOG_RETENTION_DAYS_MAX: 365

## Logs
- /Users/hirotaka-m/MyDailyPhrase/AppStoreReadinessReports/20260220-132816/logs/Release_Build.log
- /Users/hirotaka-m/MyDailyPhrase/AppStoreReadinessReports/20260220-132816/logs/Critical_UI_Tests.log
