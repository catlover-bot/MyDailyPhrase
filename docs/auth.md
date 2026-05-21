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
- Release では root `AuthGate` を強制せず、Profile / Settings / みんな のアカウント導線から手動で Apple ログインを確認できます。
- プロフィールには表示名、ひとこと、アイコン、興味タグをローカル保存できます。
- Build 35 以降では Supabase が構成されている場合に限り、Apple ログイン済みプロフィールの表示名・自己紹介・アイコン・興味タグを `profiles` テーブルへ同期します。失敗時もローカル保存は維持します。
- Build 36 では TestFlight確認用に Supabase project URL と publishable key を構成しています。`SUPABASE_ANON_KEY` という設定名ですが、値は `sb_publishable` で始まるpublishable keyを使います。
- Build 38 では手動の Apple ログイン完了後、Apple `identityToken` を Supabase Auth に渡して Supabase セッションを作成します。local Apple session だけでは `auth.uid()` が作られないため、RLS付きの `users` / `profiles` 書き込みには Supabase Auth session が必要です。
- Build 39 では follow / block / report の同期にも Supabase Auth user id を使います。Apple `providerUserId` は管理者allowlistやApple本人確認用に残し、Supabaseの `follows` / `blocks` / `reports` には書き込みません。

## 起動安定化フラグ

- `AUTH_ENABLED`
- `AUTH_SIGN_IN_WITH_APPLE_ENABLED`
- `AUTH_GOOGLE_SIGN_IN_ENABLED`
- `AUTH_GUEST_MODE_ENABLED`
- `AUTH_ADMIN_MENU_ENABLED`
- `APP_SAFE_MODE`
- `SUPABASE_AUTH_ENABLED`
- `SUPABASE_APPLE_AUTH_ENABLED`

Release では認証を安定化するまで `AUTH_ENABLED = NO` を既定にしています。
このときアプリはログイン必須にはならず、既存のローカル体験でそのまま起動します。
さらに `APP_SAFE_MODE = YES` のときは、起動時に auth gate や管理者導線、社交試作導線を組み立てず、既存のメインシェルだけを安全に起動します。

## 画面フロー

1. Release safe mode では起動時に `AuthGate` を表示せず、既存のメインタブを表示
2. Profile / Settings / みんな の導線から `ログイン / 新規登録` を開く
3. Apple でログインできたら、表示名が未設定の場合のみアカウント設定へ進む
4. ログイン済み状態はローカルプロフィールに結びつき、フォローや相互フォローDMの導線を使いやすくする

Profile には初回ログイン後のセットアップカードを表示し、表示名、自己紹介、アイコン、興味タグ、プライバシー説明を短く案内します。生の内部IDは通常カードには出さず、診断用の開閉エリアに留めます。

## Supabase Social Identity

Supabase-backed social sync uses this identity split:

- Apple `providerUserId`: stable Apple account identifier, used for admin allowlist and diagnostics.
- Local `AuthUser.id`: local app identity used by existing local diary/gacha/social fallback data.
- Supabase Auth user id: remote actor id used for `users.id`, `profiles.user_id`, `follows.follower_user_id`, `blocks.blocker_user_id`, and `reports.reporter_user_id`.

If there is no Supabase Auth session, follow/block/report actions stay local and admin diagnostics record the fallback state. The app does not force login at launch and does not upload diary answers as part of social sync.

## 注意

- OAuth secret や client secret はリポジトリに置いていません。
- Supabase の service role key や DB password もリポジトリに置きません。backend config が空なら safe に disabled となり、local fallback で起動します。
- `service_role` は絶対にiOSアプリへ入れません。Backend診断もキー全文を表示せず、key present / key type / safe prefix のみを表示します。
- Supabase Auth の access token / refresh token は診断コピーへ出しません。診断には token present の yes/no、期限、Supabase user id だけを表示します。
- Social sync diagnostics also avoid tokens. They may show sync status, counts, last error, and last sync time, but not access tokens, refresh tokens, Apple identity tokens, or full Supabase keys.
- SupabaseでApple Providerを設定する場合は、Apple側のBundle ID/Service ID、redirect/callback、nonce検証設定を確認してください。401/403/42501 が出る場合は `auth.uid()` と `profiles.user_id` の一致も確認します。
- Google の実運用ログインを有効にする場合は、開始 URL・callback scheme・サーバー検証の設定確認が必要です。
- 既存の StoreKit / Creator Pass 判定はそのまま維持し、認証だけでは課金状態を変更しません。
- 保存済み認証情報が壊れていた場合は安全に破棄し、クラッシュせずに signed out / ローカル起動へ戻します。
- `AUTH_ENABLED = NO` または `APP_SAFE_MODE = YES` のときは、`AppAuthViewModel` と `LocalAuthRepository` を Release 起動経路で必須にしません。
- Google ログインは引き続き準備中です。設定がないビルドでは無効表示にします。
