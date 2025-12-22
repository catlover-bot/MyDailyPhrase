# MyDailyPhrase

# MyDailyPhrase

MyDailyPhrase は「今日のお題（ワンフレーズ）」に対して短い回答を記録し、連続日数（streak）を可視化する iOS アプリです。  
データは App Group を利用して永続化し、将来的に Widget などの拡張と同じデータを参照できる構成を採用しています。

## Features

- 今日のお題（Prompt）の表示
- 回答の保存／更新
- 連続日数（streak）の表示
- App Group 永続化（WidgetExtension とデータ共有可能）

## Architecture

本プロジェクトはシンプルなレイヤードアーキテクチャを採用しています。

- **Presentation**: SwiftUI + ViewModel（画面状態、入力、UX）
- **Domain**: UseCase / Entity（ビジネスロジック）
- **Data**: Repository（App Group / Local データ管理）

依存関係は `App -> Presentation -> Domain -> Data` の方向で組み立てています。

## Project Structure (high level)

- `App/`
  - iOS アプリ本体（SwiftUI）
- `Packages/`
  - `Domain/` UseCase・Entity
  - `Data/` Repository 実装（App Group など）
  - `Presentation/` ViewModel 等
- `WidgetExtension/`
  - Widget（App Group を通じてアプリとデータ共有）
- `Tests/`
  - テスト

## Requirements

- Xcode (recommended: latest stable)
- iOS Simulator / iOS device

## How to Run

1. Xcode で `App/MyDailyPhrase/MyDailyPhrase.xcodeproj` を開きます
2. Run ターゲットを iOS Simulator（または実機）に設定します
3. `MyDailyPhrase` を Run します

## Notes

- App Group ID は `MyDailyPhraseApp.swift` 内で定義しています。
- WidgetExtension を有効にする場合は、App / WidgetExtension の両方で同じ App Group を設定してください。

## License

TBD
