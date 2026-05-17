# Gacha Artwork Backlog

Build 21 時点で既存画像を除く、今後追加したいガチャアート候補です。

## Full Artwork Import Workflow

1. `artwork-imports/` の該当フォルダに PNG を置く
2. `bash Scripts/import_gacha_artwork_assets.sh` を実行する
3. Release build と package test を流す
4. hidden `ガチャアート確認` で `prepared` が `existing` に変わることを確認する

## Usage Preview Rules

- busy artwork を本文の背後に置かない
- detailed artwork は badge / corner / accent で扱う
- 新しい item は assetName だけでなく usage preview plan も一緒に決める

## Priority 1

| item id | display name | rarity | item type | recommended assetName | suggested filename | visual concept | suggested prompt for image generation | suggested use surfaces | transparent background useful | PNG or vector PDF |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| gold | 王冠の紙面 | レジェンド | プロフィール称号 | gacha_gold | gacha_gold.png | プロフィール称号やプレートに映える高級感ある意匠 | Japanese mobile gacha reward artwork for 王冠の紙面, calm decorative style, no text, centered composition, プロフィール称号やプレートに映える高級感ある意匠 | プロフィールカード<br>共有カード<br>称号<br>バッジ<br>コレクション<br>ガチャ結果 | yes | PNG |
| royal | 王室の記章 | レジェンド | プロフィール称号 | gacha_royal | gacha_royal.png | プロフィール称号やプレートに映える高級感ある意匠 | Japanese mobile gacha reward artwork for 王室の記章, calm decorative style, no text, centered composition, プロフィール称号やプレートに映える高級感ある意匠 | プロフィールカード<br>共有カード<br>称号<br>バッジ<br>コレクション<br>ガチャ結果 | yes | PNG |
| phoenix | 不死鳥の余韻 | レジェンド | プロフィール称号 | gacha_phoenix | gacha_phoenix.png | プロフィール称号やプレートに映える高級感ある意匠 | Japanese mobile gacha reward artwork for 不死鳥の余韻, calm decorative style, no text, centered composition, プロフィール称号やプレートに映える高級感ある意匠 | プロフィールカード<br>共有カード<br>称号<br>バッジ<br>コレクション<br>ガチャ結果 | yes | PNG |
| eclipse | 蝕のプロフィール | レジェンド | 共有テンプレート | gacha_eclipse | gacha_eclipse.png | 共有カード全体の世界観を決めるメインビジュアル | Japanese mobile gacha reward artwork for 蝕のプロフィール, calm decorative style, no text, centered composition, 共有カード全体の世界観を決めるメインビジュアル | 共有カード<br>プロフィールカード<br>コミュニティカード<br>コレクション<br>ガチャ結果 | no | PNG |
| prism | プリズムの祝福 | レジェンド | プロフィール称号 | gacha_prism | gacha_prism.png | プロフィール称号やプレートに映える高級感ある意匠 | Japanese mobile gacha reward artwork for プリズムの祝福, calm decorative style, no text, centered composition, プロフィール称号やプレートに映える高級感ある意匠 | プロフィールカード<br>共有カード<br>称号<br>バッジ<br>コレクション<br>ガチャ結果 | yes | PNG |
| celestial | 天球のことば | レジェンド | 共有テンプレート | gacha_celestial | gacha_celestial.png | 共有カード全体の世界観を決めるメインビジュアル | Japanese mobile gacha reward artwork for 天球のことば, calm decorative style, no text, centered composition, 共有カード全体の世界観を決めるメインビジュアル | 共有カード<br>プロフィールカード<br>コミュニティカード<br>コレクション<br>ガチャ結果 | no | PNG |
| auric | 金彩の一枚 | レジェンド | プロフィール称号 | gacha_auric | gacha_auric.png | プロフィール称号やプレートに映える高級感ある意匠 | Japanese mobile gacha reward artwork for 金彩の一枚, calm decorative style, no text, centered composition, プロフィール称号やプレートに映える高級感ある意匠 | プロフィールカード<br>共有カード<br>称号<br>バッジ<br>コレクション<br>ガチャ結果 | yes | PNG |
| zenith | 天頂のカード | レジェンド | 共有テンプレート | gacha_zenith | gacha_zenith.png | 共有カード全体の世界観を決めるメインビジュアル | Japanese mobile gacha reward artwork for 天頂のカード, calm decorative style, no text, centered composition, 共有カード全体の世界観を決めるメインビジュアル | 共有カード<br>プロフィールカード<br>コミュニティカード<br>コレクション<br>ガチャ結果 | no | PNG |
| nova | 新星の光 | レジェンド | 共有テンプレート | gacha_nova | gacha_nova.png | 共有カード全体の世界観を決めるメインビジュアル | Japanese mobile gacha reward artwork for 新星の光, calm decorative style, no text, centered composition, 共有カード全体の世界観を決めるメインビジュアル | 共有カード<br>プロフィールカード<br>コミュニティカード<br>コレクション<br>ガチャ結果 | no | PNG |
| galaxy | 銀河プロムナード | レジェンド | 共有テンプレート | gacha_galaxy | gacha_galaxy.png | 共有カード全体の世界観を決めるメインビジュアル | Japanese mobile gacha reward artwork for 銀河プロムナード, calm decorative style, no text, centered composition, 共有カード全体の世界観を決めるメインビジュアル | 共有カード<br>プロフィールカード<br>コミュニティカード<br>コレクション<br>ガチャ結果 | no | PNG |
| singularity | 特異点レター | レジェンド | 共有テンプレート | gacha_singularity | gacha_singularity.png | 共有カード全体の世界観を決めるメインビジュアル | Japanese mobile gacha reward artwork for 特異点レター, calm decorative style, no text, centered composition, 共有カード全体の世界観を決めるメインビジュアル | 共有カード<br>プロフィールカード<br>コミュニティカード<br>コレクション<br>ガチャ結果 | no | PNG |

## Priority 2

| item id | display name | rarity | item type | recommended assetName | suggested filename | visual concept | suggested prompt for image generation | suggested use surfaces | transparent background useful | PNG or vector PDF |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| retro | レトロ日記帳 | ノーマル | お題パック | gacha_retro | gacha_retro.png | お題カードやコミュニティカード向けのテーマアート | Japanese mobile gacha reward artwork for レトロ日記帳, calm decorative style, no text, centered composition, お題カードやコミュニティカード向けのテーマアート | お題カード<br>日記カード<br>共有カード<br>コミュニティカード<br>コレクション<br>ガチャ結果 | no | PNG |
| aurora | オーロラログ | エピック | オーラ | gacha_aurora | gacha_aurora.png | カード周囲や背景アクセントで効く柔らかな光彩 | Japanese mobile gacha reward artwork for オーロラログ, calm decorative style, no text, centered composition, カード周囲や背景アクセントで効く柔らかな光彩 | プロフィールカード<br>共有カード<br>コミュニティカード<br>ガチャ結果<br>コレクション<br>オーラ枠<br>背景アクセント | yes | PNG |
| glitch | グリッチカード | エピック | 開封演出 | gacha_glitch | gacha_glitch.png | ガチャ開封時の発光・粒子・演出モチーフ | Japanese mobile gacha reward artwork for グリッチカード, calm decorative style, no text, centered composition, ガチャ開封時の発光・粒子・演出モチーフ | ガチャ演出<br>ガチャ結果<br>共有カード<br>コレクション | yes | PNG |
| hologram | ホログラム票 | エピック | 開封演出 | gacha_hologram | gacha_hologram.png | ガチャ開封時の発光・粒子・演出モチーフ | Japanese mobile gacha reward artwork for ホログラム票, calm decorative style, no text, centered composition, ガチャ開封時の発光・粒子・演出モチーフ | ガチャ演出<br>ガチャ結果<br>共有カード<br>コレクション | yes | PNG |
| crystal | クリスタル記録 | エピック | オーラ | gacha_crystal | gacha_crystal.png | カード周囲や背景アクセントで効く柔らかな光彩 | Japanese mobile gacha reward artwork for クリスタル記録, calm decorative style, no text, centered composition, カード周囲や背景アクセントで効く柔らかな光彩 | プロフィールカード<br>共有カード<br>コミュニティカード<br>ガチャ結果<br>コレクション<br>オーラ枠<br>背景アクセント | yes | PNG |
| stardust | 星屑レター | エピック | 共有テンプレート | gacha_stardust | gacha_stardust.png | 共有カード全体の世界観を決めるメインビジュアル | Japanese mobile gacha reward artwork for 星屑レター, calm decorative style, no text, centered composition, 共有カード全体の世界観を決めるメインビジュアル | 共有カード<br>プロフィールカード<br>コミュニティカード<br>コレクション<br>ガチャ結果 | no | PNG |
| matrix | マトリクス画面 | エピック | お題パック | gacha_matrix | gacha_matrix.png | お題カードやコミュニティカード向けのテーマアート | Japanese mobile gacha reward artwork for マトリクス画面, calm decorative style, no text, centered composition, お題カードやコミュニティカード向けのテーマアート | お題カード<br>日記カード<br>共有カード<br>コミュニティカード<br>コレクション<br>ガチャ結果 | no | PNG |
| volt | ボルトライン | エピック | 開封演出 | gacha_volt | gacha_volt.png | ガチャ開封時の発光・粒子・演出モチーフ | Japanese mobile gacha reward artwork for ボルトライン, calm decorative style, no text, centered composition, ガチャ開封時の発光・粒子・演出モチーフ | ガチャ演出<br>ガチャ結果<br>共有カード<br>コレクション | yes | PNG |
| nebula | 星雲ジャーナル | エピック | オーラ | gacha_nebula | gacha_nebula.png | カード周囲や背景アクセントで効く柔らかな光彩 | Japanese mobile gacha reward artwork for 星雲ジャーナル, calm decorative style, no text, centered composition, カード周囲や背景アクセントで効く柔らかな光彩 | プロフィールカード<br>共有カード<br>コミュニティカード<br>ガチャ結果<br>コレクション<br>オーラ枠<br>背景アクセント | yes | PNG |
| arcade | アーケード画面 | エピック | お題パック | gacha_arcade | gacha_arcade.png | お題カードやコミュニティカード向けのテーマアート | Japanese mobile gacha reward artwork for アーケード画面, calm decorative style, no text, centered composition, お題カードやコミュニティカード向けのテーマアート | お題カード<br>日記カード<br>共有カード<br>コミュニティカード<br>コレクション<br>ガチャ結果 | no | PNG |
| sonar | ソナーウェーブ | エピック | 開封演出 | gacha_sonar | gacha_sonar.png | ガチャ開封時の発光・粒子・演出モチーフ | Japanese mobile gacha reward artwork for ソナーウェーブ, calm decorative style, no text, centered composition, ガチャ開封時の発光・粒子・演出モチーフ | ガチャ演出<br>ガチャ結果<br>共有カード<br>コレクション | yes | PNG |
| comet | 彗星ポスト | エピック | 共有テンプレート | gacha_comet | gacha_comet.png | 共有カード全体の世界観を決めるメインビジュアル | Japanese mobile gacha reward artwork for 彗星ポスト, calm decorative style, no text, centered composition, 共有カード全体の世界観を決めるメインビジュアル | 共有カード<br>プロフィールカード<br>コミュニティカード<br>コレクション<br>ガチャ結果 | no | PNG |

## Priority 3

| item id | display name | rarity | item type | recommended assetName | suggested filename | visual concept | suggested prompt for image generation | suggested use surfaces | transparent background useful | PNG or vector PDF |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| classic | いつものカード | ノーマル | 紙面テーマ | - | - | 紙の質感や余白が主役の読みやすい紙面アート | Japanese mobile gacha reward artwork for いつものカード, calm decorative style, no text, centered composition, 紙の質感や余白が主役の読みやすい紙面アート | 日記カード<br>お題カード<br>コレクション<br>ガチャ結果 | no | PNG |
| paper | やわらか紙面 | ノーマル | 紙面テーマ | gacha_paper | gacha_paper.png | 紙の質感や余白が主役の読みやすい紙面アート | Japanese mobile gacha reward artwork for やわらか紙面, calm decorative style, no text, centered composition, 紙の質感や余白が主役の読みやすい紙面アート | 日記カード<br>お題カード<br>コレクション<br>ガチャ結果 | no | PNG |
| noir | 夜色ノート | ノーマル | カード枠 | gacha_noir | gacha_noir.png | 中央の文字を邪魔しない枠・縁取りアート | Japanese mobile gacha reward artwork for 夜色ノート, calm decorative style, no text, centered composition, 中央の文字を邪魔しない枠・縁取りアート | 日記カード<br>プロフィールカード<br>共有カード<br>コミュニティカード<br>ガチャ結果<br>コレクション | yes | PNG |
| linen | 麻布ページ | ノーマル | 紙面テーマ | gacha_linen | gacha_linen.png | 紙の質感や余白が主役の読みやすい紙面アート | Japanese mobile gacha reward artwork for 麻布ページ, calm decorative style, no text, centered composition, 紙の質感や余白が主役の読みやすい紙面アート | 日記カード<br>お題カード<br>コレクション<br>ガチャ結果 | no | PNG |
| graphite | 鉛筆グレー | ノーマル | カード枠 | gacha_graphite | gacha_graphite.png | 中央の文字を邪魔しない枠・縁取りアート | Japanese mobile gacha reward artwork for 鉛筆グレー, calm decorative style, no text, centered composition, 中央の文字を邪魔しない枠・縁取りアート | 日記カード<br>プロフィールカード<br>共有カード<br>コミュニティカード<br>ガチャ結果<br>コレクション | yes | PNG |
| mint | ミントメモ | ノーマル | オーラ | gacha_mint | gacha_mint.png | カード周囲や背景アクセントで効く柔らかな光彩 | Japanese mobile gacha reward artwork for ミントメモ, calm decorative style, no text, centered composition, カード周囲や背景アクセントで効く柔らかな光彩 | プロフィールカード<br>共有カード<br>コミュニティカード<br>ガチャ結果<br>コレクション<br>オーラ枠<br>背景アクセント | yes | PNG |
| cloud | 雲色ページ | ノーマル | 背景テーマ | gacha_cloud | gacha_cloud.png | 背景の空気感に使いやすい情景・色面アート | Japanese mobile gacha reward artwork for 雲色ページ, calm decorative style, no text, centered composition, 背景の空気感に使いやすい情景・色面アート | 背景アクセント<br>プロフィールカード<br>共有カード<br>コミュニティカード<br>コレクション | no | PNG |
| cotton | コットンカード | ノーマル | 紙面テーマ | gacha_cotton | gacha_cotton.png | 紙の質感や余白が主役の読みやすい紙面アート | Japanese mobile gacha reward artwork for コットンカード, calm decorative style, no text, centered composition, 紙の質感や余白が主役の読みやすい紙面アート | 日記カード<br>お題カード<br>コレクション<br>ガチャ結果 | no | PNG |
| denim | デニムノート | ノーマル | 紙面テーマ | gacha_denim | gacha_denim.png | 紙の質感や余白が主役の読みやすい紙面アート | Japanese mobile gacha reward artwork for デニムノート, calm decorative style, no text, centered composition, 紙の質感や余白が主役の読みやすい紙面アート | 日記カード<br>お題カード<br>コレクション<br>ガチャ結果 | no | PNG |
| pearl | パール余白 | ノーマル | オーラ | gacha_pearl | gacha_pearl.png | カード周囲や背景アクセントで効く柔らかな光彩 | Japanese mobile gacha reward artwork for パール余白, calm decorative style, no text, centered composition, カード周囲や背景アクセントで効く柔らかな光彩 | プロフィールカード<br>共有カード<br>コミュニティカード<br>ガチャ結果<br>コレクション<br>オーラ枠<br>背景アクセント | yes | PNG |
| sage | セージ便箋 | ノーマル | オーラ | gacha_sage | gacha_sage.png | カード周囲や背景アクセントで効く柔らかな光彩 | Japanese mobile gacha reward artwork for セージ便箋, calm decorative style, no text, centered composition, カード周囲や背景アクセントで効く柔らかな光彩 | プロフィールカード<br>共有カード<br>コミュニティカード<br>ガチャ結果<br>コレクション<br>オーラ枠<br>背景アクセント | yes | PNG |
| marine | マリンブルー | レア | 背景テーマ | gacha_marine | gacha_marine.png | 背景の空気感に使いやすい情景・色面アート | Japanese mobile gacha reward artwork for マリンブルー, calm decorative style, no text, centered composition, 背景の空気感に使いやすい情景・色面アート | 背景アクセント<br>プロフィールカード<br>共有カード<br>コミュニティカード<br>コレクション | no | PNG |
| amber | 琥珀メモ | レア | カード枠 | gacha_amber | gacha_amber.png | 中央の文字を邪魔しない枠・縁取りアート | Japanese mobile gacha reward artwork for 琥珀メモ, calm decorative style, no text, centered composition, 中央の文字を邪魔しない枠・縁取りアート | 日記カード<br>プロフィールカード<br>共有カード<br>コミュニティカード<br>ガチャ結果<br>コレクション | yes | PNG |
| plaid | チェック便箋 | レア | 紙面テーマ | gacha_plaid | gacha_plaid.png | 紙の質感や余白が主役の読みやすい紙面アート | Japanese mobile gacha reward artwork for チェック便箋, calm decorative style, no text, centered composition, 紙の質感や余白が主役の読みやすい紙面アート | 日記カード<br>お題カード<br>コレクション<br>ガチャ結果 | no | PNG |
| inkdrop | インクしずく | レア | カード枠 | gacha_inkdrop | gacha_inkdrop.png | 中央の文字を邪魔しない枠・縁取りアート | Japanese mobile gacha reward artwork for インクしずく, calm decorative style, no text, centered composition, 中央の文字を邪魔しない枠・縁取りアート | 日記カード<br>プロフィールカード<br>共有カード<br>コミュニティカード<br>ガチャ結果<br>コレクション | yes | PNG |
| moonlit | 月夜のページ | レア | 背景テーマ | gacha_moonlit | gacha_moonlit.png | 背景の空気感に使いやすい情景・色面アート | Japanese mobile gacha reward artwork for 月夜のページ, calm decorative style, no text, centered composition, 背景の空気感に使いやすい情景・色面アート | 背景アクセント<br>プロフィールカード<br>共有カード<br>コミュニティカード<br>コレクション | no | PNG |
| ruby | ルビーノート | レア | カード枠 | gacha_ruby | gacha_ruby.png | 中央の文字を邪魔しない枠・縁取りアート | Japanese mobile gacha reward artwork for ルビーノート, calm decorative style, no text, centered composition, 中央の文字を邪魔しない枠・縁取りアート | 日記カード<br>プロフィールカード<br>共有カード<br>コミュニティカード<br>ガチャ結果<br>コレクション | yes | PNG |
| teal | ティールレター | レア | オーラ | gacha_teal | gacha_teal.png | カード周囲や背景アクセントで効く柔らかな光彩 | Japanese mobile gacha reward artwork for ティールレター, calm decorative style, no text, centered composition, カード周囲や背景アクセントで効く柔らかな光彩 | プロフィールカード<br>共有カード<br>コミュニティカード<br>ガチャ結果<br>コレクション<br>オーラ枠<br>背景アクセント | yes | PNG |
| fog | 霧の余白 | レア | 背景テーマ | gacha_fog | gacha_fog.png | 背景の空気感に使いやすい情景・色面アート | Japanese mobile gacha reward artwork for 霧の余白, calm decorative style, no text, centered composition, 背景の空気感に使いやすい情景・色面アート | 背景アクセント<br>プロフィールカード<br>共有カード<br>コミュニティカード<br>コレクション | no | PNG |
| brick | レンガの縁 | レア | カード枠 | gacha_brick | gacha_brick.png | 中央の文字を邪魔しない枠・縁取りアート | Japanese mobile gacha reward artwork for レンガの縁, calm decorative style, no text, centered composition, 中央の文字を邪魔しない枠・縁取りアート | 日記カード<br>プロフィールカード<br>共有カード<br>コミュニティカード<br>ガチャ結果<br>コレクション | yes | PNG |
| season_bronze_sprout | 若葉のしるし | レア | バッジ | gacha_season_bronze_sprout | gacha_season_bronze_sprout.png | 小さく表示しても認識しやすい紋章・バッジ系アート | Japanese mobile gacha reward artwork for 若葉のしるし, calm decorative style, no text, centered composition, 小さく表示しても認識しやすい紋章・バッジ系アート | バッジ<br>プロフィールカード<br>共有カード<br>コミュニティカード<br>コレクション<br>ガチャ結果 | yes | vector PDF |
| season_bronze_ripple | さざ波のしるし | レア | バッジ | gacha_season_bronze_ripple | gacha_season_bronze_ripple.png | 小さく表示しても認識しやすい紋章・バッジ系アート | Japanese mobile gacha reward artwork for さざ波のしるし, calm decorative style, no text, centered composition, 小さく表示しても認識しやすい紋章・バッジ系アート | バッジ<br>プロフィールカード<br>共有カード<br>コミュニティカード<br>コレクション<br>ガチャ結果 | yes | vector PDF |
| season_bronze_ember | 残り火のしるし | レア | バッジ | gacha_season_bronze_ember | gacha_season_bronze_ember.png | 小さく表示しても認識しやすい紋章・バッジ系アート | Japanese mobile gacha reward artwork for 残り火のしるし, calm decorative style, no text, centered composition, 小さく表示しても認識しやすい紋章・バッジ系アート | バッジ<br>プロフィールカード<br>共有カード<br>コミュニティカード<br>コレクション<br>ガチャ結果 | yes | vector PDF |
| season_silver_comet | 彗星の紋章 | エピック | バッジ | gacha_season_silver_comet | gacha_season_silver_comet.png | 小さく表示しても認識しやすい紋章・バッジ系アート | Japanese mobile gacha reward artwork for 彗星の紋章, calm decorative style, no text, centered composition, 小さく表示しても認識しやすい紋章・バッジ系アート | バッジ<br>プロフィールカード<br>共有カード<br>コミュニティカード<br>コレクション<br>ガチャ結果 | yes | vector PDF |
| season_silver_mirror | 鏡面の紋章 | エピック | バッジ | gacha_season_silver_mirror | gacha_season_silver_mirror.png | 小さく表示しても認識しやすい紋章・バッジ系アート | Japanese mobile gacha reward artwork for 鏡面の紋章, calm decorative style, no text, centered composition, 小さく表示しても認識しやすい紋章・バッジ系アート | バッジ<br>プロフィールカード<br>共有カード<br>コミュニティカード<br>コレクション<br>ガチャ結果 | yes | vector PDF |
| season_silver_tidal | 潮騒の紋章 | エピック | バッジ | gacha_season_silver_tidal | gacha_season_silver_tidal.png | 小さく表示しても認識しやすい紋章・バッジ系アート | Japanese mobile gacha reward artwork for 潮騒の紋章, calm decorative style, no text, centered composition, 小さく表示しても認識しやすい紋章・バッジ系アート | バッジ<br>プロフィールカード<br>共有カード<br>コミュニティカード<br>コレクション<br>ガチャ結果 | yes | vector PDF |
| season_gold_crown | 王冠の印 | レジェンド | バッジ | gacha_season_gold_crown | gacha_season_gold_crown.png | 小さく表示しても認識しやすい紋章・バッジ系アート | Japanese mobile gacha reward artwork for 王冠の印, calm decorative style, no text, centered composition, 小さく表示しても認識しやすい紋章・バッジ系アート | バッジ<br>プロフィールカード<br>共有カード<br>コミュニティカード<br>コレクション<br>ガチャ結果 | yes | vector PDF |
| season_gold_eternal | 永遠の印 | レジェンド | バッジ | gacha_season_gold_eternal | gacha_season_gold_eternal.png | 小さく表示しても認識しやすい紋章・バッジ系アート | Japanese mobile gacha reward artwork for 永遠の印, calm decorative style, no text, centered composition, 小さく表示しても認識しやすい紋章・バッジ系アート | バッジ<br>プロフィールカード<br>共有カード<br>コミュニティカード<br>コレクション<br>ガチャ結果 | yes | vector PDF |
