# Gacha Item Previews

Build 24 時点の、ガチャ装飾アイテム preview 方針メモです。

## Goal

- アイテム詳細を見たときに「何が変わるのか」をすぐ理解できること
- busy artwork を大きく見せるより、読みやすさを優先すること
- result / detail / collection / hidden QA で同じ説明ルールを使うこと

## Core Rule

- primary text を busy artwork の上に直接置かない
- artwork は独立した hero または bounded thumbnail として見せる
- metadata は clean panel 上に置く
- 実際のカード preview では、装飾は accent / frame / badge / aura として控えめに反映する

## Section Structure

各アイテム詳細では、次の順で preview します。

1. `画像プレビュー`
2. item summary
3. `装備できる場所`
4. `このアイテムの使われ方`

## Usage Preview Rules

- `日記カードでの見え方`
  - journalPaper は紙面や余白に反映
  - cardFrame は枠や縁取りに反映
  - background は背景アクセントに反映
- `お題カードでの見え方`
  - promptPack はお題スタイルを優先
  - journalPaper はお題カードの紙面トーンとして反映
- `プロフィールでの見え方`
  - badge は小さな印として表示
  - profileTitle は名前まわりの称号プレートとして表示
  - auraStyle はカード外周の光や縁取りとして表示
- `共有カードでの見え方`
  - shareTemplate は構成や空気感の違いを優先
  - detailed artwork は小さな accent として使い、本文の readability を優先
- `コミュニティカードでの見え方`
  - background / promptPack / auraStyle を中心に preview
- `ガチャ結果での見え方`
  - gachaRevealEffect は結果 preview と開封演出を優先
- `コレクションでの見え方`
  - thumbnail / rarity / type / usage summary / ownership state を優先

## Item-Type-Specific Preview Behavior

- `journalPaper`
  - diary / prompt card の紙面 preview を先頭に出す
- `cardFrame`
  - border / frame を先頭に見せる
- `background`
  - calm gradient や soft background accent を使い、本文の readability を優先
- `badge`
  - full background にはせず、小さな badge icon として見せる
- `profileTitle`
  - title plate / name area を先頭に見せる
- `shareTemplate`
  - share card の構図差分を先頭に見せる
- `promptPack`
  - prompt / community card を先頭に見せる
- `auraStyle`
  - outer glow / edge treatment を先頭に見せる
- `gachaRevealEffect`
  - gacha result / reveal preview を先頭に見せる
- `fullTheme`
  - journal / profile / share の複数 surface を読みやすくまとめて preview する

## Result Screen Policy

- result screen は `fullScreenCover` のまま使う
- 最初は最も relevant な preview を 1 件だけ見せる
- 追加 preview は `ほかの見え方を見る` に入れる
- bottom action bar で preview が隠れないように scroll bottom padding を確保する

## Collection Policy

- collection tile は次を必ず表示する
  - image
  - display name
  - rarity
  - type
  - one-line usage summary
  - owned / locked / equipped state
- 未所持 item も preview は見せるが、ownership は明確に locked とする

## Hidden QA Policy

- hidden `ガチャアート確認` は ownership に関係なく全 item を preview できる
- id / name / assetName / png filename / surface / rarity / type で確認できる
- missing artwork は fallback preview になる前提で確認する

