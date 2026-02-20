# App Store Preflight Report

- Generated at: 2026-02-20 14:00:38 +0900
- Report directory: /Users/hirotaka-m/MyDailyPhrase/AppStoreReadinessReports/20260220-135741
- Device: iPhone 17
- Simulator UDID: 8D714328-9145-4B4B-89EC-BC4F8217E0A6

## Summary
- Pass: 14
- Warning: 0
- Fail: 0

## Checks
- [PASS] Auth verify endpoint は HTTPS 公開URLです (AUTH_BACKEND_VERIFY_ENDPOINT)
- [PASS] Google OAuth start URL は HTTPS 公開URLです (AUTH_GOOGLE_OAUTH_START_URL)
- [PASS] X OAuth start URL は HTTPS 公開URLです (AUTH_X_OAUTH_START_URL)
- [PASS] Terms URL は HTTPS 公開URLです (LEGAL_TERMS_URL)
- [PASS] Privacy URL は HTTPS 公開URLです (LEGAL_PRIVACY_POLICY_URL)
- [PASS] OAuth callback scheme を確認 (AUTH_OAUTH_CALLBACK_SCHEME)
- [PASS] Manual auth token input is disabled in Release
- [PASS] Auth verify bearer is optional and empty
- [PASS] Security log retention is valid (default=90, max=365)
- [PASS] Terms last-updated date is acceptable (2026-02-13)
- [PASS] Privacy policy last-updated date is acceptable (2026-02-13)
- [PASS] Simulator detected (8D714328-9145-4B4B-89EC-BC4F8217E0A6)
- [PASS] Release Build
- [PASS] Critical UI Tests

## Release Settings Snapshot
- AUTH_BACKEND_VERIFY_ENDPOINT: https://api.mydailyphrase.app/auth/verify
- AUTH_GOOGLE_OAUTH_START_URL: https://api.mydailyphrase.app/oauth/google/start
- AUTH_X_OAUTH_START_URL: https://api.mydailyphrase.app/oauth/x/start
- AUTH_OAUTH_CALLBACK_SCHEME: mydailyphrase
- LEGAL_TERMS_URL: https://api.mydailyphrase.app/legal/terms
- LEGAL_PRIVACY_POLICY_URL: https://api.mydailyphrase.app/legal/privacy
- AUTH_ALLOW_MANUAL_TOKEN_INPUT: NO
- AUTH_BACKEND_VERIFY_BEARER_REQUIRED: NO
- SECURITY_LOG_RETENTION_DAYS_DEFAULT: 90
- SECURITY_LOG_RETENTION_DAYS_MAX: 365

## Logs
- /Users/hirotaka-m/MyDailyPhrase/AppStoreReadinessReports/20260220-135741/logs/Release_Build.log
- /Users/hirotaka-m/MyDailyPhrase/AppStoreReadinessReports/20260220-135741/logs/Critical_UI_Tests.log
