# Backend Plan

Build 34 prepares the app to move local/mock social features toward Supabase without enabling unsafe public UGC.

## Current Runtime Policy

- Release launch remains safe with `APP_SAFE_MODE = YES`.
- Root `AuthGate` is still bypassed.
- StoreKit product IDs, entitlement state, and purchase flow are unchanged.
- Supabase is the first backend candidate, but `SUPABASE_BACKEND_ENABLED = NO` and empty config keep it disabled.
- Missing backend config must never crash the app.
- Admin can continue local QA when backend is disconnected.

## Supabase Configuration

The app reads these optional Info.plist values:

- `SUPABASE_BACKEND_ENABLED`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SCHEMA_VERSION`

The anon key is a public client key, but we still keep all backend values empty in committed Release config until the project is ready. Service role keys, OAuth secrets, and database passwords must never be committed.

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
- schema version
- local fallback state
- public feed/comment/ranking disabled state
- DM policy

Normal users do not see admin diagnostics.
