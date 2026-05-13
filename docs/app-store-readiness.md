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
  free/local gacha is exposed, while paid gacha / Creator Pass purchase UI remains disabled by feature flag for the first release candidate.
- Community status:
  community-related surfaces remain hidden from the shipped root navigation until moderation, reporting, blocking, privacy, and terms requirements are finalized.
- Current TestFlight build number:
  `1.0 (2)`
- Archive dry-run status:
  `xcodebuild archive` now reaches signing and provisioning checks. The current failure mode is distribution configuration, not a code or asset-catalog build failure.
- Next recommended step:
  Confirm signing, provisioning, and App Group capability setup in Xcode and the Apple Developer portal, then create a signed Archive and upload that build to TestFlight.
- TestFlight readiness:
  Ready from a code-and-assets perspective, pending signing/provisioning verification and Archive upload.
- App Store submission readiness:
  Not ready yet because real-device QA and final screenshots are still outstanding.

## Current submission blockers

1. Manual on-device QA is still required.
   This pass verified package tests and a generic iOS build, but App Review quality still depends on device validation across layout, persistence, deletion, and notification flows.

2. Updated App Store screenshots must be captured for the current tab-based experience.
   Any older screenshots from the previous product shape should not be reused.

3. Local reminder behavior must be verified on a real device.
   The code requests notification permission only after explicit opt-in and schedules a repeating local reminder, but real-device confirmation is still required before submission.

4. Signing and provisioning still need manual verification.
   The local archive dry-run reached the signing stage and failed because no provisioning profile for `jp.catloverbot.MyDailyPhrase` was available in the local Xcode environment.
   The App Group capability must also be confirmed in the Apple Developer portal and included in the final provisioning profile.

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
- Profile tab with local display name and decoration state visible
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
- Confirm profile tab does not expose login, community, or paid purchase flows
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
- Notification permission denied path
- Notification permission allowed path

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
- Paid gacha / Creator Pass purchase UI is intentionally disabled by feature flag for the first release candidate.
- Community UI is intentionally deferred from the shipped root navigation until moderation, reporting, blocking, privacy, and terms work is complete.
- Privacy and support URLs currently point to public GitHub pages. They can remain if they are intended to stay stable, but branded production URLs are preferable before final submission.

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
