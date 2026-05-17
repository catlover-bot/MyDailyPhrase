# Gacha Asset Guide

Build 18 時点のガチャアート参照ルールです。

現在のアプリは、画像がなくても必ず SwiftUI フォールバックで表示できます。
`assetName` は「画像があれば使う」ための任意設定で、画像未登録でもクラッシュしません。

## Recommended Asset Path

アートは次の配下に置きます。

`App/MyDailyPhrase/MyDailyPhrase/Assets.xcassets/GachaItems/`

推奨構成:

- `Assets.xcassets/GachaItems/gacha_sunset_note.imageset`
- `Assets.xcassets/GachaItems/gacha_sakura_diary.imageset`

## File Recommendations

- PNG: `1024x1024`
- PDF: ベクター向きのシンプルなアイコンのみ

基本は PNG を推奨します。
バッジや紋章のような単純図形だけ、必要に応じてベクター PDF を使います。

## Naming Convention

`lowercase snake_case`

例:

- `gacha_sunset_note`
- `gacha_pixel_frame`
- `gacha_rpg_tavern_skin`
- `gacha_crown_paper`

## Model Fields

`DecorationItem` では次を使えます。

- `assetName: String?`
- `thumbnailAssetName: String?`

使い分け:

- `assetName`: 結果画面や詳細画面向けの通常アート
- `thumbnailAssetName`: コレクションの小さめサムネイル用

現在は 8 件とも `thumbnailAssetName == nil` です。
将来サムネイルが必要になったら、別 imageset を追加できます。

## Current Exact Mappings

現時点でコードに明示登録されているアート参照は次の 8 件です。

| Item ID | Display Name | assetName | thumbnailAssetName | Status |
| --- | --- | --- | --- | --- |
| `sunset` | 夕焼けノート | `gacha_sunset_note` | `nil` | available |
| `sakura` | 桜の日記帳 | `gacha_sakura_diary` | `nil` | available |
| `ocean` | 深海メモ | `gacha_deepsea_memo` | `nil` | available |
| `neon` | ネオンシティ | `gacha_neon_city` | `nil` | available |
| `season_gold_halo` | 光輪の印 | `gacha_cat_paw_badge` | `nil` | available |
| `obsidian` | 黒曜石フレーム | `gacha_pixel_frame` | `nil` | available |
| `forest` | 森のカード | `gacha_rpg_tavern_skin` | `nil` | available |
| `starlight` | 星明かりカード | `gacha_starfall_effect` | `nil` | available |

それ以外のアイテムは、まだ `assetName == nil` のままです。
将来の候補名は [gacha-artwork-backlog.md](./gacha-artwork-backlog.md) に整理しています。

## Fallback Behavior

UI は次の順で表示を試みます。

1. コレクション系の小サイズ表示では `thumbnailAssetName`
2. なければ `assetName`
3. どちらも未設定、または画像が存在しなければ SwiftUI フォールバック

つまり、次のどちらでも安全です。

- `assetName == nil`
- `assetName` はあるが画像ファイルがまだ未追加

どちらの場合も、空白やクラッシュではなくフォールバック表示になります。

## Where Artwork Appears

アートがある場合、主に次の場所で使われます。

- ガチャ結果画面のヒーローカード
- コレクションタイル
- ガチャアイテム詳細
- 非公開の `ガチャアート確認` QA 画面

## Adding More Artwork Later

1. `Assets.xcassets/GachaItems/` に `.imageset` を追加
2. imageset 名を `assetName` と一致させる
3. 必要なら `thumbnailAssetName` も追加
4. Release build と package test を再実行
5. 非公開 `ガチャアート確認` 画面で表示確認
