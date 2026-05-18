# Auth

## 方針

- 認証は `Sign in with Apple` を最優先にします。
- Google ログインは OAuth 設定を安全に確認できたときだけ有効化します。
- ゲストモードはローカル確認用です。
- 日記の回答は自動で公開されません。
- 共有は明示的な操作をしたときだけ行います。
- DM は相互フォローの相手とのみ使えます。
- 装飾アイテムは見た目だけを変えるコスメティック要素です。

## 現在の実装

- `AuthRepository` を追加し、ローカルセッションで動く `LocalAuthRepository` を実装しています。
- Apple ログインは端末内のセッションとして保存され、既存の `UserProfile` と結びつきます。
- Google ログインはモデルと導線を先に準備し、設定がないビルドでは無効のままにします。
- ゲストモードでは日記・ガチャ・見た目確認を試せますが、管理者機能や DM 試作機能は使えません。

## 起動安定化フラグ

- `AUTH_ENABLED`
- `AUTH_SIGN_IN_WITH_APPLE_ENABLED`
- `AUTH_GOOGLE_SIGN_IN_ENABLED`
- `AUTH_GUEST_MODE_ENABLED`
- `AUTH_ADMIN_MENU_ENABLED`

Release では認証を安定化するまで `AUTH_ENABLED = NO` を既定にしています。
このときアプリはログイン必須にはならず、既存のローカル体験でそのまま起動します。

## 画面フロー

1. 起動時に `AuthGate` がセッションを確認
2. 未ログインなら Welcome / Login / Register を表示
3. Apple でログインできたら、表示名が未設定の場合のみアカウント設定へ進む
4. ログイン済みまたはゲストなら既存のアプリシェルを表示

## 注意

- OAuth secret や client secret はリポジトリに置いていません。
- Google の実運用ログインを有効にする場合は、開始 URL・callback scheme・サーバー検証の設定確認が必要です。
- 既存の StoreKit / Creator Pass 判定はそのまま維持し、認証だけでは課金状態を変更しません。
- 保存済み認証情報が壊れていた場合は安全に破棄し、クラッシュせずに signed out / ローカル起動へ戻します。
