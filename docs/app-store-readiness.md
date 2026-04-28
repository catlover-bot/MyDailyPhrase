# App Store Readiness

## Current submission blockers

1. App Icon is incomplete.
   The asset catalog currently contains `App/MyDailyPhrase/MyDailyPhrase/Assets.xcassets/AppIcon.appiconset/Contents.json` only and no production PNG assets.
   There is no production App Icon image in `App/MyDailyPhrase/MyDailyPhrase/Assets.xcassets/AppIcon.appiconset/`.
   A final 1024x1024 PNG must be added to that `AppIcon.appiconset` before submission.

2. Manual on-device QA is still required.
   This pass verified package tests and a generic iOS build, but App Review quality still depends on device validation across layout, persistence, deletion, and notification flows.

3. Updated App Store screenshots must be captured for the new Home/History/Settings experience.
   Any older screenshots from the previous product shape should not be reused.

4. Local reminder behavior must be verified on a real device.
   The code requests notification permission only after explicit opt-in and schedules a repeating local reminder, but real-device confirmation is still required before submission.

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
- Final App Icon asset added in `App/MyDailyPhrase/MyDailyPhrase/Assets.xcassets/AppIcon.appiconset`

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
- Open History from Home
- Search History
- Delete one entry from History
- Confirm streak recalculates after deleting an entry
- Delete all entries from Settings
- Confirm Home resets after delete-all
- Confirm History resets after delete-all
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
- Replace the App Icon with final production artwork in `App/MyDailyPhrase/MyDailyPhrase/Assets.xcassets/AppIcon.appiconset/` before uploading.
- Confirm the submission build does not expose unfinished legacy surfaces that would conflict with the local-only journal positioning.
