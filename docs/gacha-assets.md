# Gacha Asset Guide

Build 21 時点のガチャアート参照ルールです。

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
- `gacha_gold`

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

現時点で画像ファイルが存在する confirmed mapping は次の 8 件です。

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

それ以外の non-classic item にも、Build 21 で stable な planned `assetName` を割り当てています。
PNG がまだ無い item は hidden `ガチャアート確認` で `prepared` として表示されます。

Legendary の planned assetName は次の固定名です。

- `gold` -> `gacha_gold`
- `royal` -> `gacha_royal`
- `phoenix` -> `gacha_phoenix`
- `eclipse` -> `gacha_eclipse`
- `prism` -> `gacha_prism`
- `celestial` -> `gacha_celestial`
- `auric` -> `gacha_auric`
- `zenith` -> `gacha_zenith`
- `nova` -> `gacha_nova`
- `galaxy` -> `gacha_galaxy`
- `singularity` -> `gacha_singularity`

全 item の canonical plan は [gacha-artwork-asset-manifest.md](./gacha-artwork-asset-manifest.md) と `artwork-imports/gacha-all/manifest.json` にあります。

## Fallback Behavior

UI は次の順で表示を試みます。

1. コレクション系の小サイズ表示では `thumbnailAssetName`
2. なければ `assetName`
3. どちらも未設定、または画像が存在しなければ SwiftUI フォールバック

つまり、次のどちらでも安全です。

- `assetName == nil`
- `assetName` はあるが画像ファイルがまだ未追加

どちらの場合も、空白やクラッシュではなくフォールバック表示になります。

## Full Import Workflow

1. `artwork-imports/gacha-all/manifest.json` で `pngFilename` と `importDirectory` を確認する
2. 該当 PNG を `artwork-imports/` 配下のフォルダに置く
3. 次のコマンドを実行する

```bash
bash Scripts/import_gacha_artwork_assets.sh
```

4. 取り込み後、次で不足分を確認できます

```bash
bash Scripts/list_missing_gacha_artwork.sh
bash Scripts/list_existing_gacha_artwork.sh
```

5. Release build と package tests を再実行する
6. 非公開 `ガチャアート確認` で `prepared` が `existing` に変わることを確認する

## Import Directories

- `artwork-imports/gacha-all/`
- `artwork-imports/gacha-legendary/`
- `artwork-imports/gacha-epic/`
- `artwork-imports/gacha-rare/`
- `artwork-imports/gacha-common/`
- `artwork-imports/gacha-seasonal/`

Missing PNG は許容され、import script は見つかったものだけ `.imageset` を作ります。
存在しない PNG を参照する invalid `Contents.json` は生成しません。

## Where Artwork Appears

アートがある場合、主に次の場所で使われます。

- ガチャ結果画面のヒーローカード
- コレクションタイル
- ガチャアイテム詳細
- 非公開の `ガチャアート確認` QA 画面

## Artwork UI Rules

- 文字を読む領域には、忙しいアートを直接敷かない
- ヒーロー画像はヒーロー画像、メタ情報は別カードで見せる
- 日記 / プロフィール / 共有カードの本文は、必ず読みやすい面の上に置く
- 詳細なアートは、バッジ・コーナー・小さめプレビューとして使う
- 背景的に使う場合も、低不透明度の装飾にとどめる
- 下部アクションに本文やプレビューが隠れないよう、十分な余白を確保する

## Usage Preview Rules

- すべてのアイテム詳細には「このアイテムの使われ方」を用意する
- プレビューは `applicableSurfaces` に含まれる画面だけを見せる
- ガチャ結果では最も relevant な 2〜3 面を先に見せ、残りは追加表示にする
- コレクションではサムネイル、種類、レアリティ、使える場所の要約を優先する
- QA 画面では未所持でも全アイテムを詳細プレビューできるようにする

## Item-Type-Specific Preview Behavior

- `fullTheme`: 複数カード面に反映し、色・余白・小さな accent で見せる
- `background`: 背景の空気感に使うが、本文の背後に busy artwork を置かない
- `cardFrame`: 枠や縁取りの変化を優先して見せる
- `profileTitle`: 名前や称号プレート周辺の見え方を優先する
- `shareTemplate`: 共有カード全体の構図や見出しの見え方を優先する
- `auraStyle`: 外周の光や柔らかな背景アクセントとして見せる
- `journalPaper`: 日記 / お題カードの紙面と読みやすさを優先する
- `gachaRevealEffect`: ガチャ結果 / 開封演出の見え方を優先する
- `badge`: 小さな badge / icon として使い、全面背景にはしない
- `promptPack`: お題カードやコミュニティカードの雰囲気変化として見せる

## Adding More Artwork Later

1. `artwork-imports/` 配下に PNG を置く
2. `bash Scripts/import_gacha_artwork_assets.sh` を実行する
3. 必要なら `thumbnailAssetName` を別途設計する
4. Release build と package test を再実行する
5. 非公開 `ガチャアート確認` 画面で `existing / prepared / missing` を確認する
