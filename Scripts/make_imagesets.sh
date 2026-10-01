#!/usr/bin/env bash
# make_imagesets.sh — Wrap the raw OpenMoji SVGs downloaded by
# fetch_food_icons.sh into Xcode .imageset folders with
# "Preserve Vector Data" enabled, so the asset catalog exposes them as
# `openmoji-<HEX>` image sets (matching MFFoodIconAsset).
#
# Usage:
#   ./make_imagesets.sh [food-icons-dir]
# Default: app/Resources/Assets.xcassets/FoodIcons
set -euo pipefail

ICONS_DIR="${1:-app/Resources/Assets.xcassets/FoodIcons}"

if [ ! -d "$ICONS_DIR" ]; then
  echo "missing dir: $ICONS_DIR (run fetch_food_icons.sh first)" >&2
  exit 1
fi

count=0
for svg in "$ICONS_DIR"/openmoji-*.svg; do
  base="$(basename "$svg" .svg)"          # openmoji-1F357
  imageset="$ICONS_DIR/$base.imageset"
  mkdir -p "$imageset"
  mv "$svg" "$imageset/$(basename "$svg")"
  cat > "$imageset/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "$(basename "$svg")",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true
  }
}
EOF
  count=$((count + 1))
  echo "imageset: $base"
done

echo "done: $count imagesets in $ICONS_DIR"
