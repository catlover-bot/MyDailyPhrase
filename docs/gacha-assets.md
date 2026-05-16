# Gacha Asset Guide

This build prepares `MyDailyPhrase` gacha rewards for optional PNG/PDF artwork.

No image files are required yet.
If an item has no matching asset, the app falls back to the existing SwiftUI-generated preview.

## Recommended asset path

Store future gacha artwork under:

`App/MyDailyPhrase/MyDailyPhrase/Assets.xcassets/GachaItems/`

Suggested structure:

- `Assets.xcassets/GachaItems/gacha_sunset_note.imageset`
- `Assets.xcassets/GachaItems/gacha_sunset_note_thumb.imageset`

## File recommendations

- PNG:
  `1024x1024`
- PDF:
  vector icons only

Use PNG for full decorative artwork and PDF only for simple icon-style assets that benefit from vector scaling.

## Naming convention

Use lowercase snake_case names.

Examples:

- `gacha_sunset_note`
- `gacha_sunset_note_thumb`
- `gacha_stardust_letter`
- `gacha_crown_page`

## Model fields

`DecorationItem` now supports:

- `assetName: String?`
- `thumbnailAssetName: String?`

Usage:

- `assetName`:
  full artwork for result/detail previews
- `thumbnailAssetName`:
  optional smaller artwork for collection tiles

If `thumbnailAssetName` is `nil`, the UI falls back to `assetName`.
If both are `nil` or the asset does not exist, the UI falls back to the existing generated preview.

## Current representative mappings

The current code adds placeholder asset names for representative items only.
These names do not require files to exist yet.

| Item ID | Display Name | assetName | thumbnailAssetName |
| --- | --- | --- | --- |
| `paper` | やわらか紙面 | `gacha_soft_paper` | `nil` |
| `sunset` | 夕焼けノート | `gacha_sunset_note` | `gacha_sunset_note_thumb` |
| `sakura` | 桜の日記帳 | `gacha_sakura_diary` | `gacha_sakura_diary_thumb` |
| `neon` | ネオンシティ | `gacha_neon_city_card` | `gacha_neon_city_card_thumb` |
| `moonlit` | 月夜のページ | `gacha_moonlit_page` | `nil` |
| `stardust` | 星屑レター | `gacha_stardust_letter` | `gacha_stardust_letter_thumb` |
| `ocean` | 深海メモ | `gacha_deep_sea_memo` | `nil` |
| `gold` | 王冠の紙面 | `gacha_crown_page` | `gacha_crown_page_thumb` |
| `royal` | 王室の記章 | `gacha_royal_crest` | `nil` |
| `phoenix` | 不死鳥の余韻 | `gacha_phoenix_afterglow` | `nil` |
| `season_gold_halo` | 光輪の印 | `gacha_season_gold_halo` | `nil` |

All other items currently keep `assetName == nil` until artwork is ready.

## UI behavior

If `assetName` exists, these surfaces attempt to render artwork:

- gacha result screen
- collection tiles
- gacha item detail preview

Safe fallback behavior:

1. Try `thumbnailAssetName` for collection tiles when available.
2. Otherwise try `assetName`.
3. If the asset is missing, show the current SwiftUI-generated preview.

Missing assets must never crash the app.

## Adding a new item asset later

1. Add the image set to `Assets.xcassets/GachaItems/`.
2. Use the final asset name in `CardDecorationCatalog+Items.swift`.
3. Optionally add a thumbnail asset and set `thumbnailAssetName`.
4. Run the Release build and package tests again.
