# Admin Access

## 目的

アプリオーナーや社内テスターが、一般ユーザー向けの課金状態を壊さずに以下を確認できるようにします。

- Creator 機能プレビュー
- コミュニティ作成テスト
- ガチャアート QA
- 購入診断
- 全アイテム確認
- ローカルデモデータのリセット

## allowlist

管理者権限は allowlist に一致したアカウントだけに付与されます。

- `AUTH_ADMIN_APPLE_USER_IDS`
- `AUTH_ADMIN_EMAILS`

どちらも `Info.plist` 経由で読み込みます。値はカンマ区切りまたは改行区切りで指定できます。

例:

```xcconfig
AUTH_ADMIN_APPLE_USER_IDS = 000123.abcd..., 000987.efgh...
AUTH_ADMIN_EMAILS = owner@example.com
```

`AUTH_ADMIN_MENU_ENABLED = YES` のときだけ allowlist 判定が有効です。
Release の既定値は `NO` で、認証を再有効化するまでは通常ユーザーに管理者導線を出しません。
また `APP_SAFE_MODE = YES` のときは管理者メニュー自体を起動経路から外し、通常シェルだけを優先して起動します。

## 管理者権限の内容

- `accessAllFeatures`
- `manageCommunities`
- `previewAllItems`
- `bypassCreatorPassForAdmin`
- `viewDiagnostics`
- `moderateUsers`
- `resetLocalDemoData`
- `grantLocalTicketsForTesting`

## Creator Pass との関係

- 一般ユーザーは StoreKit の Creator Pass が有効なときだけ作成系機能を使えます。
- 管理者は `bypassCreatorPassForAdmin` で作成系 UI を確認できます。
- ただしこれは **StoreKit entitlement を変更しません**。
- UI 上では `管理者権限で有効` と表示して区別します。

## 管理者メニュー

`設定` に管理者専用の `管理者メニュー` を表示します。

- 全アイテム確認
- ガチャアート確認
- Creator機能プレビュー
- コミュニティ作成テスト
- 購入診断
- ローカルデモデータリセット
- ローカルテストチケット付与

## 安全性

- 通常ユーザーを自動で管理者にはしません。
- public feed / comments / ranking は引き続き無効のままです。
- 外部決済リンクは追加していません。
- 管理者 bypass で課金状態や通貨表示は書き換えません。
- allowlist が空でもクラッシュせず、単に非管理者として扱います。
