# Social Safety Scope

## Current scope in Build `1.0 (42)`

`MyDailyPhrase` includes a lightweight social UX layer, but it is intentionally constrained to avoid unsafe public UGC.

- `みんな` focuses on preset communities, weekly challenges, follow-style profile cards, and local share flows
- community participation is free
- community creation is gated by Creator Pass entitlement
- public feed, comments, ranking, and open user discovery remain disabled
- follow/block/report can sync to Supabase for authenticated users, with local/demo fallback
- DM can sync text-only threads/messages to Supabase for authenticated mutual-follow users
- DM requires mutual follow and blocks prevent starting or continuing conversations

## Follow behavior

- users can follow and unfollow profile cards
- users can block and unblock a profile
- users can mark a local report flag for a profile
- blocked profiles are removed from recommendations
- follower / mutual-follow cards can use Supabase state when available, with local fallback
- public discovery is disabled by default

User-facing rule:

- `フォローすると相手のプロフィールカードを見つけやすくなります。`

## DM behavior

- DM is only available between mutual follows
- DM is text-only in this build
- images, files, and link previews are not supported
- conversations can be deleted locally; remote deletion is not exposed yet
- blocked users cannot be DM targets
- report / block actions are available from the conversation flow
- Supabase-backed DM uses explicit text entered in the DM UI only
- diary answers are not auto-inserted into DM

User-facing rules:

- `DMは相互フォローの相手とのみ利用できます。`
- `不快な相手はブロック・通報できます。`
- `まだメッセージはありません。相互フォローの相手とメッセージを始められます。`

## User-facing copy boundary

Build `1.0 (42)` separates product copy from developer diagnostics.

- Normal users should see friendly product language such as `プロフィールを保存しました`, `コミュニティ情報を更新しました`, and `メッセージを更新しました`.
- Normal screens must not show Supabase, RLS, auth.uid, providerUserId, UUID, access token, refresh token, localFallback, StoreKit product IDs, or raw table names.
- Raw IDs and backend troubleshooting details belong only in admin/developer diagnostics.
- Diagnostics must never print tokens or DM message bodies.

## What is intentionally not enabled

The shipped flow must not expose any of the following until a real backend and moderation plan are ready:

- public user discovery
- public comments
- public feed / timeline
- ranking based on user posts
- anonymous public posting
- arbitrary inbound DM from strangers
- media attachments in DM
- fake live activity counts

## Backend status

Current status:

- profile, follow/block/report, community/membership, and mutual-follow DM can use Supabase when the user is signed in and policies allow it
- local fallback remains available when the user is signed out, offline, or using local/demo preview rows
- no CloudKit-backed social graph is enabled
- no public account system is required for the core diary / gacha loop

Before expanding beyond this constrained scope, define:

- stable user identity
- authentication rules
- data retention rules
- delete-account / delete-message behavior
- report / block workflows
- abuse contact
- moderation or review plan
- privacy policy updates
- App Privacy metadata updates if stored social data changes disclosure requirements

## QA checklist

- [ ] Follow / unfollow state updates correctly
- [ ] Block removes the user from local recommendations
- [ ] Report stores safely without crashing
- [ ] DM is unavailable for non-mutual follows
- [ ] DM becomes available for mutual follows
- [ ] Blocked user cannot be used as a DM target
- [ ] Delete conversation removes only the local conversation state
- [ ] No public feed / comments / ranking UI appears
- [ ] No fake live member counts or fake inbox activity appear
- [ ] iPhone SE layout remains readable for follow and DM flows
