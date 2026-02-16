# MyDailyPhrase

MyDailyPhrase is an iOS SwiftUI app centered on short daily reflection. Users answer one prompt per day, keep a streak, and review their past entries in a local-first experience.

The repository keeps a layered architecture so persistence, domain logic, and UI state stay separated:

- `App/`
  The iOS application target and platform-specific wiring.
- `Packages/Domain/`
  Entities, repository protocols, and use cases.
- `Packages/Data/`
  Local persistence and prompt repository implementations.
- `Packages/Presentation/`
  View models and presentation-layer state management.

## Core Experience

- A stable daily prompt for the current calendar day
- Save or update today's answer
- Streak tracking and monthly answer counts
- History browsing with delete support
- Local reminder settings via `UNUserNotificationCenter`

## Storage and Privacy

Entries are stored locally using App Group-backed storage so the app can remain local-first and resilient offline. The current build does not add analytics, tracking, third-party SDKs, or network-backed user accounts.

## Requirements

- Xcode 16 or later
- iOS 17.0+

## How to Run

1. Open `App/MyDailyPhrase/MyDailyPhrase.xcodeproj` in Xcode.
2. Select the `MyDailyPhrase` scheme.
3. Build and run on an iOS 17+ simulator or device.

## Notes

- Privacy policy and support URLs live in `App/MyDailyPhrase/MyDailyPhrase/AppCore/AppLinks.swift`.
- App Store submission readiness notes live in `docs/app-store-readiness.md`.
