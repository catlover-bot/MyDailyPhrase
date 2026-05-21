# Backend Plan

Build 34 prepared the app to move local/mock social features toward Supabase without enabling unsafe public UGC. Build 35 adds the first backend-backed path: profile sync. Build 38 bridges manual Sign in with Apple to Supabase Auth so profile writes can satisfy RLS.

## Current Runtime Policy

- Release launch remains safe with `APP_SAFE_MODE = YES`.
- Root `AuthGate` is still bypassed.
- StoreKit product IDs, entitlement state, and purchase flow are unchanged.
- Supabase is the first backend candidate, but `SUPABASE_BACKEND_ENABLED = NO` and empty config keep it disabled.
- Missing backend config must never crash the app.
- Local Apple sign-in alone is not enough for RLS writes. Profile sync requires a Supabase Auth session.
- Admin can continue local QA when backend is disconnected.
- StoreKit/IAP and Creator Pass entitlement are not connected to backend profile sync.

## Supabase Configuration

The app reads these optional Info.plist values:

- `SUPABASE_BACKEND_ENABLED`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_AUTH_ENABLED`
- `SUPABASE_APPLE_AUTH_ENABLED`
- `SUPABASE_SCHEMA_VERSION`

The iOS client uses Supabase's publishable client key through the existing `SUPABASE_ANON_KEY` config name. Service role keys, OAuth secrets, and database passwords must never be committed or placed in the app bundle.

Build 36 configures the test Supabase project host:

- `SUPABASE_URL`: `https://kzhaivmewwnsrkxnbgpy.supabase.co`
- `SUPABASE_ANON_KEY`: publishable key only, prefix `sb_publishable`

Diagnostics may show whether a key is present, its type, and the safe prefix. They must never show the full key value.

Build 38 enables Supabase Auth bridging only after the user manually completes Sign in with Apple. The app exchanges Apple's `identityToken` with Supabase Auth and stores only the minimum session data needed for REST requests. Diagnostics may show Supabase Auth status, Supabase user id, token-present booleans, and token expiry, but never access tokens or refresh tokens.

Local setup:

1. Create a Supabase project.
2. Open SQL Editor and run `supabase/schema.sql`.
3. Put `SUPABASE_URL` and `SUPABASE_ANON_KEY` in xcconfig or local build settings. Use the publishable key for iOS client tests.
4. Set `SUPABASE_BACKEND_ENABLED = YES` only for a backend test build or TestFlight verification build.
5. Enable `SUPABASE_AUTH_ENABLED = YES` and `SUPABASE_APPLE_AUTH_ENABLED = YES` only after the Supabase Apple provider is configured.
6. Never commit `service_role`, database password, OAuth client secrets, or private JWT signing secrets.

Production note: the iOS client uses the publishable key and a Supabase Auth user token. The app must never write profiles with anonymous broad policies or a service role key.

## Build 35 Profile Sync

The first real Supabase-backed feature is profile sync. When Supabase is configured and the user has linked Apple login, profile saves are written locally first. Remote upsert runs only when a Supabase Auth session is available.

Identity mapping:

- Apple `providerUserId`: Apple subject identifier from Sign in with Apple.
- Local `AuthUser.id`: existing local app profile id used by local diary/gacha data.
- Supabase Auth user id: `auth.uid()` from Supabase Auth.
- `profiles.user_id`: Supabase Auth user id. This must match `auth.uid()` for RLS.

The client still preserves the local profile id for local data. Remote profile rows use the Supabase Auth user id.

Mapped fields:

- `user_id`
- `display_name`
- `bio`
- `avatar_symbol`
- `interest_tags`
- `updated_at`

If the user is signed out, the app does not attempt backend profile writes. If Supabase is unavailable or a request fails, the local profile remains saved and diagnostics record the error.

Current limitations:

- Diary answers are not synced.
- Follow/DM/community data still uses local fallback.
- Public feed/comments/ranking remain disabled.
- Profile sync depends on safe Supabase policies being installed before production use.

Expected statuses:

- `localFallback`: Supabase is disabled or incomplete.
- `supabaseConfigured`: URL/key are configured, but a test has not proven access yet.
- `supabaseAvailable`: connection/profile sync succeeded.
- `supabaseError`: connection/profile sync failed.
- `connecting` / `syncing`: a manual admin test is running.
- `skippedSupabaseAuthMissing`: profile was saved locally, but no Supabase Auth access token is available yet.
- `synced`: profile upsert/fetch completed.
- `failed`: local profile was preserved, but backend write/read failed.

Common errors:

- `401` / `403` / `42501`: check that Supabase Auth is configured, the Apple provider accepted the identity token, `profiles.user_id = auth.uid()`, and the client is using the publishable key plus Supabase access token, not `service_role`.
- `404`: check that the schema was applied and that the table name is `profiles`.
- Invalid URL: use the HTTPS Supabase project URL.
- Network failure: check device connectivity and Supabase project status.

## Schema

Draft schema lives at:

`supabase/schema.sql`

Designed tables:

- `users`
- `profiles`
- `follows`
- `blocks`
- `communities`
- `memberships`
- `dm_threads`
- `dm_messages`
- `reports`
- `admin_roles`

Not included/enabled yet:

- public feed
- public comments
- ranking
- diary answer sync

## Repository Boundary

Domain protocols:

- `ProfileRepository`
- `CommunityRepository`
- `SocialConnectionRepository`
- `DMRepository`
- `ReportRepository`

Local implementations remain the active fallback. Supabase-ready adapters can later implement the same protocols without changing SwiftUI screens.

## Safety Rules

- Diary text is not uploaded or shared automatically.
- DM remains mutual-follow only.
- Block/report must exist before any discovery or messaging expansion.
- Public feed/comments/ranking remain disabled.
- Backend being configured must not change StoreKit entitlement or Creator Pass purchase state.

## Diagnostics

Settings > Admin shows Backend diagnostics for the allowlisted owner:

- provider
- status
- active mode
- Supabase project host
- anon key configured or not
- key type and safe prefix
- schema version
- table name (`profiles`)
- connection test status and last checked time
- Supabase Auth status
- Supabase user id
- access/refresh token present flags
- token expiry
- last Supabase Auth error
- profile sync status
- last profile sync time
- last backend error
- local fallback state
- public feed/comment/ranking disabled state
- DM policy

Normal users do not see admin diagnostics.

Manual admin tests:

- `Supabase接続テスト`: reads the `profiles` table metadata path without writing data.
- `プロフィール同期テスト`: requires a Sign in with Apple linked profile and Supabase Auth session, upserts the local profile, then fetches it back when possible.

If `プロフィール同期テスト` shows `ローカル保存済み / Supabase認証待ち`, run the manual Apple login again and confirm Supabase Auth status becomes `signedIn`.
