# App Store Preflight Report

- Generated at: 2026-02-20 14:55:32 +0900
- Report directory: /Users/hirotaka-m/MyDailyPhrase/AppStoreReadinessReports/20260220-145228
- Device: iPhone 17
- Simulator UDID: 8D714328-9145-4B4B-89EC-BC4F8217E0A6

## Summary
- Pass: 14
- Warning: 0
- Fail: 0

## Checks
- [PASS] Google login is disabled for this release
- [PASS] X login is disabled for this release
- [PASS] Auth verify endpoint is optional because external OAuth login is disabled
- [PASS] Terms URL は HTTPS 公開URLです (LEGAL_TERMS_URL)
- [PASS] Privacy URL は HTTPS 公開URLです (LEGAL_PRIVACY_POLICY_URL)
- [PASS] OAuth callback scheme を確認 (AUTH_OAUTH_CALLBACK_SCHEME)
- [PASS] Manual auth token input is disabled in Release
- [PASS] Auth verify bearer check skipped because external OAuth login is disabled
- [PASS] Security log retention is valid (default=90, max=365)
- [PASS] Terms last-updated date is acceptable (2026-02-13)
- [PASS] Privacy policy last-updated date is acceptable (2026-02-13)
- [PASS] Simulator detected (8D714328-9145-4B4B-89EC-BC4F8217E0A6)
- [PASS] Release Build
- [PASS] Critical UI Tests

## Release Settings Snapshot
- AUTH_BACKEND_VERIFY_ENDPOINT: 
- AUTH_GOOGLE_OAUTH_START_URL: 
- AUTH_X_OAUTH_START_URL: 
- AUTH_OAUTH_CALLBACK_SCHEME: mydailyphrase
- LEGAL_TERMS_URL: https://raw.githubusercontent.com/catlover-bot/MyDailyPhrase/main/LEGAL_TERMS.md
- LEGAL_PRIVACY_POLICY_URL: https://raw.githubusercontent.com/catlover-bot/MyDailyPhrase/main/LEGAL_PRIVACY_POLICY.md
- AUTH_ALLOW_MANUAL_TOKEN_INPUT: NO
- AUTH_BACKEND_VERIFY_BEARER_REQUIRED: NO
- SECURITY_LOG_RETENTION_DAYS_DEFAULT: 90
- SECURITY_LOG_RETENTION_DAYS_MAX: 365

## Logs
- /Users/hirotaka-m/MyDailyPhrase/AppStoreReadinessReports/20260220-145228/logs/Release_Build.log
- /Users/hirotaka-m/MyDailyPhrase/AppStoreReadinessReports/20260220-145228/logs/Critical_UI_Tests.log
