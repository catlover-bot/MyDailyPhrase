# Gacha All Import Folder

このフォルダには、全レアリティ共通でまとめて import したい PNG を置けます。

- `manifest.json` に書かれた `pngFilename` をそのまま使ってください
- 推奨サイズは正方形 `1024x1024` 以上です
- 日本語や空白を含むファイル名は避けてください
- `bash Scripts/import_gacha_artwork_assets.sh` を実行すると、見つかった PNG だけが Xcode asset catalog にコピーされます
- PNG がまだ無い item は skip され、fallback preview が使われ続けます
