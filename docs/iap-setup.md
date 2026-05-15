# IAP Setup

## Scope

Build `1.0 (13)` carries forward StoreKit2 support for:

- paid gacha ticket packs
- Creator Pass entitlement

This build also reorganizes the in-app UX so:

- Gacha explains free usage and item value before purchase
- Odds are easy to reach before paid spending
- Creator Pass explains that participation is free and creation is premium
- purchase UI fails safely when products do not load
- ticket packs remain visible as disabled cards when products are unavailable
- Creator Pass keeps a locked creation preview visible even before entitlement
- Settings now includes a hidden purchase diagnostics section for TestFlight troubleshooting
- partial StoreKit product loading is surfaced safely instead of treating the whole shop as broken

Current App Store Connect status:

- `Gacha Tickets 10`
- `Gacha Tickets 50`
- `Gacha Tickets 120`
- `Creator Pass Lifetime`

have been added to the app version. StoreKit product propagation may still take time, so the app continues to show a safe fallback state until price data is actually returned on device.
Build `1.0 (13)` also requests only the currently launched Creator Pass SKU (`creatorpass.lifetime`) while keeping future monthly/yearly IDs reserved in code.

Free users should still be able to:

- use the core diary
- join preset communities
- answer community prompts
- use free gacha where available
- share cards

## Product IDs

### Consumable ticket packs

- `jp.catloverbot.MyDailyPhrase.gacha.tickets10`
  Product type: `Consumable`
- `jp.catloverbot.MyDailyPhrase.gacha.tickets50`
  Product type: `Consumable`
- `jp.catloverbot.MyDailyPhrase.gacha.tickets120`
  Product type: `Consumable`

### Creator Pass

- `jp.catloverbot.MyDailyPhrase.creatorpass.lifetime`
  Product type: `Non-Consumable`

Code is also prepared for these optional future IDs:

- `jp.catloverbot.MyDailyPhrase.creatorpass.monthly`
  Product type: `Auto-Renewable Subscription`
- `jp.catloverbot.MyDailyPhrase.creatorpass.yearly`
  Product type: `Auto-Renewable Subscription`

If you do not plan to launch subscription-based Creator Pass yet, do not create the monthly/yearly products in App Store Connect.

## Recommended display names

### Ticket packs

- `Gacha Tickets 10`
- `Gacha Tickets 50`
- `Gacha Tickets 120`

Japanese alternatives:

- `ガチャチケット 10枚`
- `ガチャチケット 50枚`
- `ガチャチケット 120枚`

### Creator Pass

- `Creator Pass Lifetime`

Japanese alternative:

- `Creator Pass 買い切り`

## Recommended descriptions

### Ticket packs

- `10枚分のガチャチケットです。装飾アイテムの抽選に使えます。`
- `50枚分のガチャチケットです。装飾アイテムの抽選に使えます。`
- `120枚分のガチャチケットです。装飾アイテムの抽選に使えます。`

Recommended notes:

- cosmetic rewards only
- no cash value
- not tradable
- odds are disclosed in app before spending paid tickets

### Creator Pass

- `コミュニティ作成とカスタムお題設定を解放する買い切り機能です。`

Recommended notes:

- community participation remains free
- unlocks creation only
- no public feed/comments are enabled by this purchase

## Recommended pricing notes

- Use regional App Store pricing rather than hard-coding yen expectations in the app.
- Keep the 50-pack and 120-pack visibly better value than the 10-pack.
- Avoid artificial urgency or fake scarcity.
- If you launch only the lifetime Creator Pass first, keep pricing simple and explain that it unlocks community creation only.

## App Store Connect setup steps

1. Open App Store Connect.
2. Select the `MyDailyPhrase` app.
3. Go to `Features > In-App Purchases`.
4. Create three consumables:
   - `jp.catloverbot.MyDailyPhrase.gacha.tickets10`
   - `jp.catloverbot.MyDailyPhrase.gacha.tickets50`
   - `jp.catloverbot.MyDailyPhrase.gacha.tickets120`
5. Create the Creator Pass product:
   - `jp.catloverbot.MyDailyPhrase.creatorpass.lifetime`
6. Confirm the product type matches code.
7. Add localized display names and descriptions.
8. Select price tiers.
9. Add review screenshots for each IAP if required by App Store Connect.
10. Save and submit the IAPs for review together with the app version if needed.
11. In Xcode, confirm the same product IDs are used in code and in the `.storekit` file.
12. Upload Build `1.0 (13)` to TestFlight.
13. Wait for processing, then test purchases on device.

## Sandbox / TestFlight monetization QA checklist

- [ ] Products load successfully on device
- [ ] If only some products load, the loaded products show prices and the missing ones remain disabled
- [ ] Ticket pack prices display from StoreKit
- [ ] Creator Pass price displays from StoreKit
- [ ] When products fail to load, purchase buttons are not tappable
- [ ] Unavailable state shows `準備中` or `購入できません`-style fallback, not a broken button
- [ ] Ticket pack cards stay visible even in unavailable state
- [ ] `商品情報を再読み込み` and `購入情報を復元` are reachable when products fail to load
- [ ] Hidden purchase diagnostics in Settings can show requested IDs / loaded IDs / missing IDs when troubleshooting
  Open it by tapping the app version badge 5 times.
- [ ] Gacha screen leads with free draw / collection value before purchase
- [ ] Odds are reachable without entering an actual purchase flow
- [ ] Buying `tickets10` grants `10`
- [ ] Buying `tickets50` grants `50`
- [ ] Buying `tickets120` grants `120`
- [ ] Verified purchase grants tickets exactly once
- [ ] Reopening the app does not duplicate ticket grants
- [ ] Cancelling purchase does not change ticket balance
- [ ] Pending purchase does not grant tickets until verified
- [ ] Failed purchase does not change ticket balance
- [ ] Creator Pass purchase unlocks community creation after verification
- [ ] Non-entitled user still sees creation locked
- [ ] Non-entitled user still sees the community creation preview form in locked mode
- [ ] Free user can still join preset communities

## Restore purchases checklist

Use for Creator Pass only.

- [ ] `App Storeと同期` or restore flow is reachable
- [ ] Restoring a valid Creator Pass entitlement re-enables creation
- [ ] Restore does not create duplicate ticket grants
- [ ] Restore does not unlock public community features
- [ ] Restore copy is clear and non-misleading

## Cancelled / pending / failed purchase checklist

- [ ] Cancelled purchase shows a clear user-facing message
- [ ] Pending purchase shows a pending/approval-needed message
- [ ] Failed purchase shows a clear error message
- [ ] No cancelled/pending/failed state grants tickets
- [ ] No failed purchase consumes existing tickets

## Odds disclosure verification checklist

- [ ] Odds are reachable from the Gacha screen before paid spending
- [ ] Rarity odds are visible
- [ ] Item-level odds are visible
- [ ] Duplicate handling is disclosed
- [ ] Disclosure states that items have no cash value
- [ ] Disclosure states rewards cannot be traded or sold
- [ ] Displayed odds match the same source used by draw logic
- [ ] Any pity-related note is accurate

## Review Notes draft

Use this as a starting point in App Store Connect review notes:

`MyDailyPhrase` offers cosmetic-only gacha rewards and a Creator Pass unlock for local community creation. Gacha rewards have no cash value and cannot be traded, sold, transferred, or cashed out. Odds are visible from the Gacha screen before paid draws. Duplicate rewards convert to local shards only. Creator Pass unlocks community creation, while community participation remains free. Public feed, comments, and ranking are disabled in this build. No external payment links are used.

Additional reviewer-facing UX note:

`Today` is the private diary tab, `Gacha` is for cosmetic rewards and odds disclosure, `みんな` is the free community-participation tab, and Creator Pass only affects community creation. The app is designed to make free participation and private-by-default writing clear without requiring purchase. If App Store product loading fails, the app still shows disabled purchase cards and retry / restore actions instead of broken purchase buttons.

## App Review reminders

- Paid gacha must remain cosmetic only.
- Do not imply real-world value for items.
- Do not enable trading, resale, gifting for value, or cash-out.
- Keep public community surfaces hidden until moderation/report/block/delete/privacy flows are ready.
- If only the lifetime Creator Pass is configured in App Store Connect, do not advertise monthly/yearly plans in user-facing copy.
