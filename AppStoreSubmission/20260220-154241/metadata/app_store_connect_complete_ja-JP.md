# App Store Connect 提出完全版 (ja-JP)

- 生成日時: 2026-02-20 15:42:41 +0900
- バンドルID: `jp.catloverbot.MyDailyPhrase`
- SKU推奨: `jp.catloverbot.MyDailyPhrase`
- 対象ロケール: ja-JP

## 1. App Information（入力値）

- Name: MyDailyPhrase
- Subtitle: 1分で続く、言葉のセルフケア
- Primary Category: ライフスタイル
- Secondary Category: ソーシャルネットワーキング
- Content Rights: 自社保有（第三者コンテンツ利用なし）

## 2. Version Information（入力値）

### Promotional Text
毎日1つのお題に短く答えるだけ。気分の変化を見える化し、ガチャ装飾とコミュニティで継続を楽しくします。

### Description
MyDailyPhrase は、毎日の気づきを短く記録して振り返るためのアプリです。

- 1日1問のお題で、考えを自然に言語化
- 回答から作品プレビューを生成し、共有しやすい形で保存
- ガチャで装飾を集めて、カードの見た目をカスタマイズ
- 週間ミッションとシーズン要素で継続をサポート
- コミュニティ機能で、他のユーザーの投稿にリアクション
- Profile の提出チェック/監査ログで、運用状態を可視化

初回はログインが必要です。ログイン後は継続して利用できます。

### Keywords
`journal,reflection,habit,selfcare,memo,community,gacha,writing,mood,mindset`

### What's New
- 初回ログイン導線を強化し、再起動時の状態復帰を安定化
- ガチャ演出と結果表示の体験を改善
- Profile の提出チェックと通知ダッシュボードを拡張
- 監査ログと運用設定の可視化を改善

## 3. URL設定（入力値）

- Support URL: https://github.com/catlover-bot/MyDailyPhrase/issues
- Marketing URL: https://github.com/catlover-bot/MyDailyPhrase
- Privacy Policy URL: https://github.com/catlover-bot/MyDailyPhrase/blob/main/LEGAL_PRIVACY_POLICY.md
- Terms of Service URL: https://github.com/catlover-bot/MyDailyPhrase/blob/main/LEGAL_TERMS.md

## 4. 認証・ログイン実装（審査説明用）

- ログイン必須: はい（初回ログインゲートあり）
- 対応: Sign in with Apple
- OAuthコールバックスキーム: `mydailyphrase`
- 外部OAuth設定: Releaseでは外部OAuthは無効化（Sign in with Appleのみ表示）
- Google OAuth Start URL: (未設定)
- X OAuth Start URL: (未設定)
- Auth Verify Endpoint: (未設定)

## 5. App内課金（IAP）

| Product ID | 種別 | 備考 |
| --- | --- | --- |
| `mydailyphrase.creatorpass.monthly` | 自動更新サブスクリプション | Creator Pass（月額） |
| `mydailyphrase.creatorpass.yearly` | 自動更新サブスクリプション | Creator Pass（年額） |
| `mydailyphrase.gacha.ticket10` | 消耗型 | ガチャチケットパック |
| `mydailyphrase.gacha.ticket120` | 消耗型 | ガチャチケットパック |
| `mydailyphrase.gacha.ticket300` | 消耗型 | ガチャチケットパック |
| `mydailyphrase.gacha.ticket50` | 消耗型 | ガチャチケットパック |

- 課金導線: Profile / Gacha / コミュニティ急上昇詳細
- サブスクリプション: Creator Pass（月額・年額）
- 消耗型: ガチャチケットパック

## 6. App Privacy（App Store Connect入力ガイド）

- Tracking: いいえ
- Data Used to Track You: なし
- Data Linked to You（実装ベース）
- 識別子: ユーザーID、外部認証連携ID（provider/subject）
- ユーザーコンテンツ: 投稿文、タグ、リアクション、コメント
- 購入情報: Creator Pass状態、チケット購入反映
- 診断: セキュリティ監査ログ（連携/解除/失効/エラー）
- 収集目的: アプリ機能提供、不正利用防止、運用監査、サポート対応

## 7. App Review Information（貼り付け用）

### Review Notes
# App Review Notes (ja-JP)

## テスト時の導線
- アプリ起動後、ログイン画面が表示されます。
- `Sign in with Apple` を利用できます。
- ログイン後は自動でメイン画面へ遷移します。

## 主要機能
1. 今日タブ: お題に回答し、作品プレビューを表示
2. ガチャタブ: チケット消費で抽選、装飾変更、提供割合表示
3. つながりタブ: 投稿一覧、リアクション、招待導線
4. Profileタブ: 提出チェック、通知設定、課金導線、監査ログ

## 課金要素
- Creator Pass (自動更新サブスクリプション)
- チケットパック (消耗型)
- 課金しなくても基本機能は利用可能です。

## ランダム要素の表示
- ガチャ画面に提供割合を表示しています。
- アイテム別の提供割合（目安）も表示しています。

## 法務ページ
- 利用規約: https://github.com/catlover-bot/MyDailyPhrase/blob/main/LEGAL_TERMS.md
- プライバシーポリシー: https://github.com/catlover-bot/MyDailyPhrase/blob/main/LEGAL_PRIVACY_POLICY.md

## 連絡先
- support: support@mydailyphrase.app

### 連絡先
- support: support@mydailyphrase.app

## 8. 提出前の実行結果（最新）

- Preflight Report: /Users/hirotaka-m/MyDailyPhrase/AppStoreReadinessReports/20260220-153023/report.md
- Summary: Pass=14 / Warning=0 / Fail=0
- Metadata Validation: `./Scripts/validate_app_store_metadata.sh` を必ずPASS
- Endpoint Reachability: `./Scripts/check_production_endpoints.sh` を実ネットワーク環境で実行

## 9. 最終提出チェックリスト

- [ ] App Store Connect の Name / Subtitle / Description / Keywords を本シート値で入力
- [ ] Privacy Policy / Terms URL を本シート値で入力
- [ ] IAP商品IDが「Ready to Submit」以上で有効
- [ ] Age Rating 質問票を最新機能に合わせて入力
- [ ] App Privacy 質問票を本シート「6. App Privacy」に沿って入力
- [ ] 最新Build（Release）をVersionに紐付け
- [ ] Review Notes を貼り付け
- [ ] 外部URL疎通確認（check_production_endpoints）を実ネットワークでPASS
- [ ] `AppStoreSubmission/<timestamp>/` の提出バンドルを最終保存

