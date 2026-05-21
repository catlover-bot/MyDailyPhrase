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

Follow is local/mock until a safe backend is available.

- States: `フォローする`, `フォロー中`, `相互フォロー`, `ブロック中`.
- Blocked users are excluded from recommendations.
- Report and block controls stay visible before public discovery is enabled.
- Recommendations are local preview cards and should not imply live remote activity.

## DM Safety

DM remains mutual-follow only.

- Text-only local draft flow.
- No images, files, or link previews.
- No anonymous public DM.
- Block/report/delete controls remain available.
- Diary answers are not sent automatically.
- Disabled DM buttons should explain the reason: not followed yet, not followed back yet, blocked, or unsupported.

## Communities

Community participation remains free. Creator/community creation is gated:

- Creator Pass users can create/customize communities.
- Admin can preview creation through admin capability.
- Normal unpaid users can join but cannot create premium communities.
- Admin bypass does not modify StoreKit entitlement.
- The `みんな` tab is organized around joined communities, recommended communities, recommended users, following, mutual follows, DM, and invite/share.

## Repository Boundary

Social connection behavior is still local/mock, but the domain now has a `SocialConnectionRepository` protocol so a backend implementation can later provide recommended profiles, following/follower lists, mutual follow state, and DM eligibility without changing the UI contract.

## Sharing

Sharing is designed to feel social without unsafe public posting:

- Profile share card
- Community invite card
- Gacha result share
- Daily reflection share template

Share previews should be readable, decorative, and explicit about what is included. Diary text is not included unless the user chooses it.
