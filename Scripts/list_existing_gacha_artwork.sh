#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST_PATH="$ROOT_DIR/artwork-imports/gacha-all/manifest.json"
DEST_ROOT="$ROOT_DIR/App/MyDailyPhrase/MyDailyPhrase/Assets.xcassets/GachaItems"

if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "manifest not found: $MANIFEST_PATH" >&2
  exit 1
fi

/usr/bin/ruby - "$MANIFEST_PATH" "$DEST_ROOT" <<'RUBY'
require "json"

manifest_path = ARGV[0]
dest_root = ARGV[1]
manifest = JSON.parse(File.read(manifest_path))

manifest.fetch("items").each do |item|
  next unless item["pngFilename"]

  asset_name = item["plannedAssetName"]
  png_path = File.join(dest_root, "#{asset_name}.imageset", "#{asset_name}.png")
  next unless File.file?(png_path)

  puts "#{asset_name} -> #{item["pngFilename"]}"
end
RUBY
