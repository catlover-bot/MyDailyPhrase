# App Store Preflight Report

- Generated at: 2026-02-20 13:49:49 +0900
- Report directory: /Users/hirotaka-m/MyDailyPhrase/AppStoreReadinessReports/20260220-134616
- Device: iPhone 17
- Simulator UDID: 8D714328-9145-4B4B-89EC-BC4F8217E0A6

## Summary
- Pass: 11
- Warning: 3
- Fail: 0

## Checks
- [PASS] Auth verify endpoint は HTTPS 公開URLです (AUTH_BACKEND_VERIFY_ENDPOINT)
- [PASS] Google OAuth start URL は HTTPS 公開URLです (AUTH_GOOGLE_OAUTH_START_URL)
- [PASS] X OAuth start URL は HTTPS 公開URLです (AUTH_X_OAUTH_START_URL)
- [WARN] Terms URL points to github.com. Production-hosted legal URL is recommended (LEGAL_TERMS_URL)
- [WARN] Privacy URL points to github.com. Production-hosted legal URL is recommended (LEGAL_PRIVACY_POLICY_URL)
- [PASS] OAuth callback scheme を確認 (AUTH_OAUTH_CALLBACK_SCHEME)
- [PASS] Manual auth token input is disabled in Release
- [WARN] Auth verify bearer is empty (ignore if backend does not require it)
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
- LEGAL_TERMS_URL: https://github.com/catlover-bot/MyDailyPhrase/blob/main/LEGAL_TERMS.md
- LEGAL_PRIVACY_POLICY_URL: https://github.com/catlover-bot/MyDailyPhrase/blob/main/LEGAL_PRIVACY_POLICY.md
- AUTH_ALLOW_MANUAL_TOKEN_INPUT: NO
- SECURITY_LOG_RETENTION_DAYS_DEFAULT: 90
- SECURITY_LOG_RETENTION_DAYS_MAX: 365

## Logs
- /Users/hirotaka-m/MyDailyPhrase/AppStoreReadinessReports/20260220-134616/logs/Release_Build.log
- /Users/hirotaka-m/MyDailyPhrase/AppStoreReadinessReports/20260220-134616/logs/Critical_UI_Tests.log
