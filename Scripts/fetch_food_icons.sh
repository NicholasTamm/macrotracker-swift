#!/usr/bin/env bash
# fetch_food_icons.sh — Download OpenMoji food artwork for the design system.
#
# Artwork: OpenMoji (https://openmoji.org), licensed CC BY-SA 4.0
# (https://creativecommons.org/licenses/by-sa/4.0/).
#
# ATTRIBUTION (required by the license — keep this credit in the app's
# About/Settings screen and in this file):
#   "Food icons by OpenMoji (https://openmoji.org) — CC BY-SA 4.0"
#
# Usage:
#   ./fetch_food_icons.sh [output-dir]
# Default output: app/Resources/Assets.xcassets/FoodIcons (raw SVGs land
# here; run app/Scripts/make_imagesets.sh afterwards to wrap them in
# .imageset folders with "Preserve Vector Data" enabled so the Xcode asset
# catalog picks them up as `openmoji-<HEX>` image sets).
# SVGs keep vector data — enable "Preserve Vector Data" in Xcode.
#
# ShareAlike note: modifications to the OpenMoji artwork itself must be
# redistributed under CC BY-SA 4.0. Bundling the unmodified icons alongside
# original app code does not relicense the app code.
set -euo pipefail

OUT_DIR="${1:-app/Resources/Assets.xcassets/FoodIcons}"
BASE="https://cdn.jsdelivr.net/gh/hfg-gmuend/openmoji/color/svg"

# Unicode hex codes used by MFFoodIconAsset (see MFPlateSheet.swift).
ICONS=(
  1F357  # poultry leg (chicken)
  1F955  # carrot
  1F35E  # bread
  1F954  # potato
  1FAD2  # olive
  1F9C8  # butter
  1F373  # cooking (fried egg)
  2615   # hot beverage (coffee)
  1F951  # avocado
  1F345  # tomato
  1FAD0  # blueberries
  1F353  # strawberry
)

mkdir -p "$OUT_DIR"
for hex in "${ICONS[@]}"; do
  dest="$OUT_DIR/openmoji-$hex.svg"
  if [ -f "$dest" ]; then
    echo "exists: $dest"
  else
    echo "fetch:  $dest"
    curl -fsSL --connect-timeout 15 --max-time 60 \
      -o "$dest" "$BASE/$hex.svg"
  fi
done

# Write the license notice next to the downloaded art.
cat > "$OUT_DIR/FOOD_ICONS_LICENSE.txt" <<'EOF'
Food icons: OpenMoji (https://openmoji.org), licensed CC BY-SA 4.0
(https://creativecommons.org/licenses/by-sa/4.0/).
Attribution: "Food icons by OpenMoji (https://openmoji.org) — CC BY-SA 4.0".
Source SVGs fetched from the official OpenMoji GitHub mirror via jsDelivr.
EOF
echo "done: $(ls "$OUT_DIR"/openmoji-*.svg | wc -l) icons + FOOD_ICONS_LICENSE.txt"
