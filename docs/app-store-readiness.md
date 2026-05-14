# App Store Readiness

## Current status

- GitHub sync status:
  Local `main` matches `origin/main`, and the working tree is clean at the time of this verification pass.
- Debug build passes:
  `xcodebuild -project App/MyDailyPhrase/MyDailyPhrase.xcodeproj -scheme MyDailyPhrase -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/MyDailyPhraseDerivedData CODE_SIGNING_ALLOWED=NO build`
- Release build passes:
  `xcodebuild -project App/MyDailyPhrase/MyDailyPhrase.xcodeproj -scheme MyDailyPhrase -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/MyDailyPhraseDerivedDataRelease CODE_SIGNING_ALLOWED=NO build`
- Swift package tests pass:
  `Packages/Domain`, `Packages/Data`, and `Packages/Presentation`
- Production App Icon is installed:
  `App/MyDailyPhrase/MyDailyPhrase/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
- App Icon validation:
  PNG, `1024x1024`, square, RGB, `hasAlpha: no`
- Main navigation for the TestFlight candidate:
  `今日`, `履歴`, `ガチャ`, `プロフィール`, `設定`
- First-release feature gating:
  free/local gacha remains available, while paid gacha / Creator Pass UI is shown only when StoreKit products load successfully.
- Build 1.0 (3) theme-preview additions:
  the gacha result flow now includes a visual theme preview, sample journal card, sample profile card, equip action, and native share action.
- Build 1.0 (3) generalized gacha assets:
  owned items now behave as reusable local customization assets instead of one-off result labels.
  Depending on item type, they can affect profile identity, share card styling, preview cards, journal-card previews, and collection cards.
- Community Lite status:
  a safe local-first social layer is available from Profile, centered on weekly challenges, profile card sharing, achievement sharing, invite-style sharing, and preset community participation through the native share sheet.
- Game Community Lite status:
  Build `1.0 (4)` adds preset game communities plus a local prompt engine that generates stable community prompts from category, tags, schedule, and prompt tone.
- Creator community creation status:
  community creation now has a real StoreKit entitlement path in code, but it is still safely gated by Creator Pass entitlement.
  Free users can join and participate in preset communities without payment.
- Paid gacha status:
  Build `1.0 (5)` adds StoreKit-backed ticket pack support, centralized product IDs, odds disclosure UI, and duplicate-to-shard handling.
- Public community status:
  full public community surfaces remain hidden from the shipped root navigation until moderation, reporting, blocking, privacy, abuse handling, and terms requirements are finalized.
- Current TestFlight build number:
  `1.0 (5)`
- Archive dry-run status:
  `xcodebuild archive` now reaches signing and provisioning checks. The current failure mode is distribution configuration, not a code or asset-catalog build failure.
- Next recommended step:
  Confirm signing, provisioning, App Group capability setup, and App Store Connect IAP product setup, then create a signed Archive and upload that build to TestFlight.
- TestFlight readiness:
  Ready from a code-and-assets perspective, pending signing/provisioning verification, App Store Connect IAP setup, and Archive upload.
- App Store submission readiness:
  Not ready yet because real-device QA and final screenshots are still outstanding.

## Current submission blockers

1. Manual on-device QA is still required.
   This pass verified package tests and a generic iOS build, but App Review quality still depends on device validation across layout, persistence, deletion, and notification flows.

2. Updated App Store screenshots must be captured for the current tab-based experience.
   Any older screenshots from the previous product shape should not be reused.

   New screenshot-worthy candidates now include:
   - the gacha result preview screen
   - the collection screen with owned / locked / equipped states
   - the equipped profile card after applying a new theme
   - the weekly challenge / Community Lite share preview flow

3. Local reminder behavior must be verified on a real device.
   The code requests notification permission only after explicit opt-in and schedules a repeating local reminder, but real-device confirmation is still required before submission.

4. Signing and provisioning still need manual verification.
   The local archive dry-run reached the signing stage and failed because no provisioning profile for `jp.catloverbot.MyDailyPhrase` was available in the local Xcode environment.
   The App Group capability must also be confirmed in the Apple Developer portal and included in the final provisioning profile.

5. App Store Connect IAP setup is still required.
   The app code and local StoreKit file now support paid gacha tickets and Creator Pass, but App Store Connect products, screenshots, pricing, and sandbox/TestFlight validation are still required before release.

6. Sandbox / TestFlight purchase validation is still required.
   Cancelled, pending, failed, restored, and successful purchase flows must be verified on device before App Store submission.

## Required App Store Connect metadata

- App name, subtitle, keywords, and promotional text
- App description aligned with the local-first daily reflection experience
- Support URL
- Privacy Policy URL
- Marketing URL if you intend to use one
- Age rating questionnaire
- App privacy questionnaire
- Version release notes
- Review notes describing that data is stored locally on device and reminders use local notifications only
- In-App Purchases metadata for ticket packs and Creator Pass
- Final App Icon asset in `App/MyDailyPhrase/MyDailyPhrase/Assets.xcassets/AppIcon.appiconset/AppIcon.png`

## Privacy Policy URL TODO

- Current in-app URL:
  `https://github.com/catlover-bot/MyDailyPhrase/blob/main/LEGAL_PRIVACY_POLICY.md`
- TODO:
  Decide whether to keep the GitHub-hosted privacy policy or replace it with a branded production URL before submission.
- Requirement:
  The final URL must be publicly accessible from App Store Connect and from inside the app.
- Current assessment:
  The GitHub URL is public and openable, so it is technically acceptable if you intend to keep it stable.
  A branded production URL is still recommended for a more polished App Store presentation.

## Support URL TODO

- Current in-app URL:
  `https://github.com/catlover-bot/MyDailyPhrase/issues`
- TODO:
  Decide whether GitHub Issues is the final public support surface or replace it with a branded support page/contact URL before submission.
- Requirement:
  The final URL must be publicly accessible and monitored.
- Current assessment:
  The GitHub Issues URL is public and openable, so it is technically acceptable if you actively monitor it.
  A branded support destination is still recommended before final App Store submission.

## Screenshot checklist

- Home screen with today's prompt visible
- Home screen after answering today's prompt
- History screen with saved entries
- Gacha tab with the free/local collection flow visible
- Gacha shop with odds disclosure and ticket purchase UI
- Gacha result screen showing visual preview, rarity, equip action, and share action
- Collection screen showing owned / locked / equipped themes
- Profile tab with local display name and decoration state visible
- Community Lite weekly challenge and profile-share preview
- Preset game community detail screen with prompt preview and join state
- Locked creator community creation preview with theme selection and prompt preview
- Settings screen with privacy/support/reminder sections
- iPhone SE screenshots
- Standard iPhone screenshots
- iPad screenshots
- Dark mode screenshots if you plan to market dark mode

## Manual test checklist

- Fresh install launches into the journal flow without crashes
- Save today's answer
- Update today's answer
- Kill and relaunch the app and confirm persistence
- Open each main tab and confirm titles/state restore correctly
- Search History
- Delete one entry from History
- Confirm streak recalculates after deleting an entry
- Delete all entries from Settings
- Confirm Home resets after delete-all
- Confirm History resets after delete-all
- Confirm free gacha works without exposing any paid purchase UI
- Confirm paid gacha purchase buttons only appear when StoreKit products load
- Confirm odds disclosure is visible before spending paid tickets
- Confirm duplicate items convert to local shards as disclosed
- Confirm cancelled / pending / failed purchases do not grant tickets
- Confirm verified ticket purchases increase ticket balance exactly once
- Confirm Creator Pass purchase UI does not appear broken when products are unavailable
- Confirm Creator Pass restore flow works when applicable
- Confirm the gacha result screen shows a real visual preview, not text only
- Confirm “今すぐ使う” equips the drawn theme immediately
- Confirm “あとで使う” leaves the current equipped theme unchanged
- Confirm “結果を共有” opens the native share sheet only after explicit user action
- Confirm obtained items appear later in コレクション with correct owned / equipped state
- Confirm equipped items still apply after relaunch
- Confirm profile tab does not expose login, paid purchase flows, or unsafe public community UI
- Open Community Lite from Profile
- Confirm weekly challenge prompt and preview card render correctly
- Confirm weekly challenge share does not include the private answer by default
- Confirm preset game communities are browsable and joinable for free
- Confirm joining and leaving a preset community updates local state correctly
- Confirm community prompt generation stays stable for the same day / week
- Confirm different game community presets produce appropriately different prompts
- Confirm default community share does not include the answer text unless explicitly enabled
- Confirm creator community creation shows a locked or gated state in production
- Confirm Creator Pass entitlement unlocks community creation only after verification
- Confirm no broken Creator Pass purchase button or external payment link appears
- Confirm profile / invite / achievement share actions all require explicit user action
- Confirm no public feed, comments, likes, or ranking UI appear in the shipped flow
- Enable reminders from Settings
- Disable reminders from Settings
- Change reminder time
- Verify no notification permission prompt appears before explicit opt-in
- Relaunch the app and confirm reminder toggle/time persist
- After changing reminder time, confirm the pending notification was rescheduled
- Check airplane mode behavior
- Check that privacy/support links open successfully

## Device test checklist

- iPhone SE or equivalent small-screen device
- Standard iPhone size
- iPad
- Dark mode
- Large Dynamic Type
- VoiceOver smoke test
- Gacha reveal animation with Reduce Motion enabled
- Gacha result preview layout on iPhone SE
- Collection / preview sheet layout on iPhone SE
- Community Lite layout on iPhone SE
- Game community detail and creator preview layout on iPhone SE
- Weekly challenge share preview with large Dynamic Type
- Notification permission denied path
- Notification permission allowed path
- Successful gacha ticket sandbox purchase
- Cancelled gacha ticket sandbox purchase
- Pending purchase behavior
- Creator Pass restore / entitlement refresh

## App privacy answer recommendation

Recommended only if the shipped build remains local-first with no reachable server-backed features:

- Data Used to Track You: `No`
- Data Linked to You: `No`
- Data Not Linked to You: `No`
- Third-party advertising: `No`
- Analytics: `No`
- Crash reporting SDKs: `No`

## Notes for the release build

- The current implementation stores journal entries locally in UserDefaults/App Group storage.
- The current implementation does not add analytics, tracking, login, or third-party SDKs to the journal flow.
- The App Icon asset catalog now references `App/MyDailyPhrase/MyDailyPhrase/Assets.xcassets/AppIcon.appiconset/AppIcon.png` for the standard, dark, and tinted slots.
- The TestFlight candidate now exposes existing local engagement surfaces through the main tab bar.
- Build 3 adds a stronger local-only gacha loop:
- Build 4 extends that loop into reusable community styling and safe social participation:
  preset communities can reuse owned themes, share templates, titles, badges, and prompt-pack style items without requiring a backend or payment for participation.
- Build 4 adds Game Community Lite:
  preset game communities are joinable for free and use a deterministic local prompt engine to produce tailored daily or weekly prompts.
- Build 5 adds StoreKit-backed monetization support:
  paid ticket packs, odds disclosure, duplicate-to-shard conversion, and Creator Pass entitlement handling are implemented in code and wired to the local StoreKit configuration.
- Creator Pass uses StoreKit only.
  No external payment links are present.
- Community participation remains free.
- Community creation is still gated by Creator Pass entitlement.
- Paid gacha remains cosmetic/local only:
  items have no cash value, no trading, no resale, and no marketplace.
- No public unmoderated UGC is exposed in the shipped flow.
- Native sharing is explicit user action only.
- Private answers are not shared by default in community, weekly challenge, or profile-related share cards.
- Full public community still requires moderation, reporting, blocking, delete-own-content, privacy, abuse-contact, and terms work before it can be enabled.
- Build 3 adds a stronger local-only gacha loop:
  users can draw, see a visual preview immediately, equip the theme from the result screen, find it later in コレクション, and share the result via the native iOS share sheet.
- Gacha items are now generalized reusable local assets:
  item metadata includes surfaces / type / palette / preview behavior so rewards can affect more than one user-facing card.
- Theme application scope for this build is intentionally local and review-safe:
  equipped decorations visibly affect the profile card, gacha result preview, collection preview, gacha share cards, and journal-card previews.
  The app does not force a full global reskin of every screen in this release.
- Community Lite is intentionally scoped to App-Review-safe sharing:
  weekly challenges, profile cards, streak cards, and invite cards are shared only through the native share sheet.
  Private journal answers are not shared by default.
- Full public community UI is intentionally deferred until moderation, reporting, blocking, privacy, and terms work is complete.
- Privacy and support URLs currently point to public GitHub pages. They can remain if they are intended to stay stable, but branded production URLs are preferable before final submission.

## IAP checklist

### Paid gacha checklist

- [ ] App Store Connect consumable products created
- [ ] Product IDs match:
  - `jp.catloverbot.MyDailyPhrase.gacha.tickets10`
  - `jp.catloverbot.MyDailyPhrase.gacha.tickets50`
  - `jp.catloverbot.MyDailyPhrase.gacha.tickets120`
- [ ] Price tiers selected
- [ ] Product metadata and screenshots added
- [ ] Odds disclosure visible in app before spending paid tickets
- [ ] Actual odds and displayed odds both derive from the same pool/weight source
- [ ] Duplicate handling disclosed and tested
- [ ] No cash value / trading / resale / marketplace
- [ ] Sandbox purchase tested
- [ ] Cancelled purchase tested
- [ ] Pending purchase tested
- [ ] Failed purchase tested

### Creator Pass checklist

- [ ] App Store Connect Creator Pass product created
- [ ] Product type finalized:
  - lifetime non-consumable
  - or monthly/yearly subscription
- [ ] Product ID matches code
- [ ] Restore purchases / entitlement refresh tested
- [ ] Community creation locks correctly when not entitled
- [ ] Community creation unlocks correctly when entitled
- [ ] Free users can still join preset communities

## App Review notes for IAP

- Paid gacha is cosmetic / local only.
- Odds disclosure is available in the Gacha screen and purchase flow.
- Duplicate rewards convert to local shards only.
- Creator Pass unlocks community creation only.
- Public community feed / comments / ranking remain disabled.
- Free users can still participate in preset communities without payment.
- No external payment links are present.

## TestFlight checklist

- [ ] Confirm Apple Developer team
- [ ] Confirm Bundle ID exists in App Store Connect
- [ ] Confirm App Group exists in Apple Developer portal
- [ ] Confirm provisioning profile includes App Group
- [ ] Archive in Xcode
- [ ] Validate archive
- [ ] Upload to App Store Connect
- [ ] Wait for build processing
- [ ] Add internal testers
- [ ] Install via TestFlight on physical device
