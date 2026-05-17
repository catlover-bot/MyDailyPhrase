# Gacha Artwork Imports

このフォルダは、ガチャアイテム用 PNG を後から安全に取り込むための staging area です。

- 各サブフォルダに PNG を置いてください
- ファイル名は `artwork-imports/gacha-all/manifest.json` にある `pngFilename` と完全一致させてください
- 推奨サイズは正方形 `1024x1024` 以上です
- 日本語や空白を含むファイル名は使わず、`lowercase snake_case` を使ってください
- 取り込みは `bash Scripts/import_gacha_artwork_assets.sh` で行います
- PNG が無い item はそのまま skip されます
- PNG が無い間も、アプリは SwiftUI の fallback preview で安全に動作します
