#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST_PATH="$ROOT_DIR/artwork-imports/gacha-all/manifest.json"
DEST_ROOT="$ROOT_DIR/App/MyDailyPhrase/MyDailyPhrase/Assets.xcassets/GachaItems"

SOURCE_DIRS=(
  "$ROOT_DIR/artwork-imports/gacha-all"
  "$ROOT_DIR/artwork-imports/gacha-legendary"
  "$ROOT_DIR/artwork-imports/gacha-epic"
  "$ROOT_DIR/artwork-imports/gacha-rare"
  "$ROOT_DIR/artwork-imports/gacha-common"
  "$ROOT_DIR/artwork-imports/gacha-seasonal"
)

if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "manifest not found: $MANIFEST_PATH" >&2
  exit 1
fi

mkdir -p "$DEST_ROOT"
cat > "$DEST_ROOT/Contents.json" <<'JSON'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "provides-namespace" : false
  }
}
JSON

/usr/bin/ruby - "$MANIFEST_PATH" "$DEST_ROOT" "${SOURCE_DIRS[@]}" <<'RUBY'
require "fileutils"
require "json"

manifest_path = ARGV.shift
dest_root = ARGV.shift
source_dirs = ARGV

manifest = JSON.parse(File.read(manifest_path))
items = manifest.fetch("items")

items.each do |item|
  asset_name = item["plannedAssetName"]
  png_filename = item["pngFilename"]
  next if asset_name.nil? || asset_name.strip.empty? || png_filename.nil? || png_filename.strip.empty?

  source_path = source_dirs
    .map { |dir| File.join(dir, png_filename) }
    .find { |path| File.file?(path) }

  if source_path.nil?
    puts "missing: #{png_filename}"
    next
  end

  imageset_dir = File.join(dest_root, "#{asset_name}.imageset")
  FileUtils.mkdir_p(imageset_dir)
  target_png = File.join(imageset_dir, "#{asset_name}.png")
  FileUtils.cp(source_path, target_png)

  contents = {
    "images" => [
      {
        "filename" => "#{asset_name}.png",
        "idiom" => "universal",
        "scale" => "1x"
      }
    ],
    "info" => {
      "author" => "xcode",
      "version" => 1
    }
  }

  File.write(File.join(imageset_dir, "Contents.json"), JSON.pretty_generate(contents))
  puts "imported: #{asset_name}"
end
RUBY
