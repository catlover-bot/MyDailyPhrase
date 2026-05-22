# Social Features

## Current Policy

- The app still launches directly into the main tab shell.
- Login is optional and is not required for basic diary, gacha, or local profile use.
- Public feed, public comments, and public ranking remain disabled until backend moderation and abuse controls are ready.
- Diary answers are private by default and are never shared automatically.
- Sharing only happens after an explicit user action.

## Login Entry Points

Users can discover login from normal app surfaces instead of a hidden debug-only path:

- Profile: `アカウントでつながる` card with `ログイン / 新規登録`.
- Settings: account section with login status, login CTA, diagnostics copy, logout, and account deletion placeholder.
- Community / みんな: follow and DM sections show login prompts when social actions are unavailable.
- Follow / DM actions explain why they are disabled instead of silently failing.

The Release launch path remains safe:

```xcconfig
APP_SAFE_MODE = YES
AUTH_ENABLED = NO
AUTH_TEST_ENTRY_ENABLED = YES
AUTH_MANUAL_APPLE_SIGN_IN_ENABLED = YES
AUTH_ADMIN_MENU_ENABLED = YES
```

`AUTH_ENABLED = NO` means the root auth gate is not forced at launch. Manual auth is created only from account/social surfaces.

## Profile Identity

Profile now supports local identity fields:

- Display name
- Short bio
- Simple avatar symbol
- Interest tags
- Joined community summary
- Follow/follower/mutual follow counts
- Profile share card

Raw internal IDs should stay in diagnostics, not prominent user-facing cards.

After a user signs in, Profile shows a lightweight setup card until the core identity fields are filled. The card explains that diary text remains private and that only the chosen profile fields are used for social surfaces.

## Follow Safety

Follow, block, and report can sync to Supabase when a Supabase Auth session exists. Local/mock behavior remains the fallback for signed-out users, missing backend config, failed backend requests, and seeded local preview profiles.

- States: `フォローする`, `フォロー中`, `相互フォロー`, `ブロック中`.
- Blocked users are excluded from recommendations.
- Report and block controls stay visible before public discovery is enabled.
- Recommendations can include backend discoverable profiles when available. Seeded local preview cards should still avoid implying live remote activity.

## DM Safety

DM remains mutual-follow only.

- Text-only local draft flow.
- No images, files, or link previews.
- No anonymous public DM.
- Block/report/delete controls remain available.
- Diary answers are not sent automatically.
- Disabled DM buttons should explain the reason: not followed yet, not followed back yet, blocked, or unsupported.

## Communities

Community participation remains free. Community and membership state can sync to Supabase when a Supabase Auth session exists. Local/mock behavior remains the fallback for signed-out users, local preset ids, missing backend config, or backend failures.

- Creator Pass users can create/customize communities.
- Admin can preview creation through admin capability.
- Normal unpaid users can join but cannot create premium communities.
- Admin bypass does not modify StoreKit entitlement.
- Supabase `communities.creator_user_id` and `memberships.user_id` use Supabase Auth user id, not Apple providerUserId.
- The `みんな` tab is organized around joined communities, recommended communities, recommended users, following, mutual follows, DM, and invite/share.

## Repository Boundary

Social connection behavior is backend-ready through repository protocols. Local implementations remain available as fallback so screens do not need separate code paths:

- `ProfileRepository`
- `CommunityRepository`
- `SocialConnectionRepository`
- `DMRepository`
- `ReportRepository`

Build 34 adds a Supabase plan and schema while keeping local fallback active. If Supabase config is empty, diagnostics show `disabled` / `localFallback` and the app continues to launch safely.

Build 35 adds Supabase profile sync as the first backend-backed feature. Signed-in profile edits are saved locally first, then synced to the `profiles` table when Supabase is configured. If sync fails, local profile changes are preserved and the admin Backend診断 shows the profile sync status and last backend error.

Build 36 configures the Supabase project URL for profile sync testing and adds admin-only manual checks:

- `Supabase接続テスト`: confirms the configured host/key can reach the `profiles` table path without writing data.
- `プロフィール同期テスト`: requires a linked Apple user, upserts the current local profile, and fetches it back when possible.

Diagnostics show key presence, key type `publishable`, and safe prefix `sb_publishable`; they do not show the full key.

Build 38 adds the Supabase Auth bridge for manual Sign in with Apple:

- Apple local sign-in can still succeed even if Supabase Auth fails.
- Remote profile sync requires a Supabase Auth session so RLS can use `auth.uid()`.
- `profiles.user_id` uses the Supabase Auth user id, while local diary/gacha data keeps the local profile id.
- Access tokens and refresh tokens are never shown in diagnostics or share payloads.
- If Supabase Auth is missing, profile edits remain local and admin diagnostics show `ローカル保存済み / Supabase認証待ち`.

Build 39 adds Supabase-backed social connection sync:

- Follow/unfollow writes to `follows` when the actor is signed in with Supabase Auth and the target is a Supabase user id.
- Block/unblock writes to `blocks` and removes blocked users from recommendations.
- User reports write to `reports` as the authenticated reporter.
- Backend failures preserve local UI state and show details only in admin Backend診断.
- Apple `providerUserId` is not used for remote social rows; it remains for Apple identity and admin allowlist only.
- Supabase Auth user id is used for `follower_user_id`, `blocker_user_id`, and `reporter_user_id`.

Build 40 adds Supabase-backed community and membership sync:

- Joined/recommended communities can refresh from Supabase when signed in.
- Join/leave writes to `memberships` as the authenticated Supabase user.
- Creator/admin community creation writes to `communities` when the app-side Creator Pass/admin check allows it.
- Backend failures preserve local state and show detailed errors only in admin Backend診断.
- StoreKit Creator Pass entitlement remains separate from admin bypass and backend sync.

Still local/fallback in Build 40:

- DM threads/messages
- Invite/share state

Public feed/comments/ranking remain disabled.

## Sharing

Sharing is designed to feel social without unsafe public posting:

- Profile share card
- Community invite card
- Gacha result share
- Daily reflection share template

Share previews should be readable, decorative, and explicit about what is included. Diary text is not included unless the user chooses it.
