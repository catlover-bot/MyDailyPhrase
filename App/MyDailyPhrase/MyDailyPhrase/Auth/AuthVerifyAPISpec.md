# `/auth/verify` API Spec (v1)

## Endpoint
- Method: `POST`
- Path: `/auth/verify`
- Headers:
  - `Content-Type: application/json`
  - `Accept: application/json`
  - `X-MyDailyPhrase-Auth-Schema: 1`
  - `Authorization: Bearer <token>` (optional, server-to-server secret)

## Request Body
```json
{
  "schema_version": 1,
  "provider": "google",
  "provider_token": "eyJ..."
}
```

### provider
- `google` or `x`

## Success Response (`200`)
```json
{
  "success": true,
  "provider": "google",
  "subject": "provider-user-id",
  "issued_at": "2026-02-13T10:11:12Z",
  "display_name": "Taro",
  "email": "taro@example.com"
}
```

## Rejected Response (`200`)
```json
{
  "success": false,
  "provider": "google",
  "issued_at": "2026-02-13T10:11:12Z",
  "error_code": "token_invalid",
  "error_message": "token expired"
}
```

## Error Response (`4xx/5xx`)
```json
{
  "error_code": "invalid_request",
  "reason": "provider is unsupported",
  "message": "provider must be google or x"
}
```

## Notes
- `issued_at` must be ISO8601 (`YYYY-MM-DDTHH:mm:ssZ` or fractional seconds).
- If app config has only host/base URL, app automatically appends `/auth/verify`.
- Production build expects HTTPS endpoints only.

## Mobile OAuth Prerequisites
- `AUTH_GOOGLE_OAUTH_START_URL`: backend OAuth start URL for Google
- `AUTH_X_OAUTH_START_URL`: backend OAuth start URL for X
- `AUTH_OAUTH_CALLBACK_SCHEME`: callback scheme received by app
- `AUTH_OAUTH_CALLBACK_SCHEME` is required to be registered in `Info.plist > CFBundleURLTypes > CFBundleURLSchemes`
- Callback must include one of query/fragment keys:
  - `provider_token`
  - `id_token`
  - `token`
  - `access_token`

## Current Build Defaults
- Debug:
  - `AUTH_BACKEND_VERIFY_ENDPOINT`: `https://api.mydailyphrase.app/auth/verify`
  - `AUTH_GOOGLE_OAUTH_START_URL`: `https://api.mydailyphrase.app/oauth/google/start`
  - `AUTH_X_OAUTH_START_URL`: `https://api.mydailyphrase.app/oauth/x/start`
- Release:
  - `AUTH_BACKEND_VERIFY_ENDPOINT`: empty (external OAuth disabled)
  - `AUTH_GOOGLE_OAUTH_START_URL`: empty (Google login disabled)
  - `AUTH_X_OAUTH_START_URL`: empty (X login disabled)
- `LEGAL_TERMS_URL`: `https://github.com/catlover-bot/MyDailyPhrase/blob/main/LEGAL_TERMS.md`
- `LEGAL_PRIVACY_POLICY_URL`: `https://github.com/catlover-bot/MyDailyPhrase/blob/main/LEGAL_PRIVACY_POLICY.md`
- `AUTH_BACKEND_VERIFY_BEARER_REQUIRED`: `NO` (if set to `YES`, `AUTH_BACKEND_VERIFY_BEARER` must be configured)
