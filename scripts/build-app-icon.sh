#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOURCES_DIR="$PROJECT_DIR/Sources/Wink/Resources"
APP_ICON_SVG="$RESOURCES_DIR/AppIcon.svg"
APP_ICON_ICNS="$RESOURCES_DIR/AppIcon.icns"
MENU_BAR_TEMPLATE_SVG="$RESOURCES_DIR/MenuBarTemplate.svg"
MENU_BAR_TEMPLATE_PNG="$RESOURCES_DIR/MenuBarTemplate.png"
MENU_BAR_TEMPLATE_PNG_2X="$RESOURCES_DIR/MenuBarTemplate@2x.png"
MENU_BAR_IMAGESET_DIR="$RESOURCES_DIR/MenuBarAssets.xcassets/MenuBarTemplate.imageset"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required tool '$1' was not found in PATH." >&2
    exit 1
  fi
}

render_png() {
  local input="$1"
  local width="$2"
  local height="$3"
  local output="$4"
  rsvg-convert "$input" -w "$width" -h "$height" -o "$output"
}

resize_png() {
  local input="$1"
  local width="$2"
  local height="$3"
  local output="$4"
  sips -z "$height" "$width" "$input" --out "$output" >/dev/null
}

require_tool rsvg-convert
require_tool sips
require_tool iconutil

if [ ! -f "$APP_ICON_SVG" ]; then
  echo "Error: App icon SVG not found at $APP_ICON_SVG" >&2
  exit 1
fi

if [ ! -f "$MENU_BAR_TEMPLATE_SVG" ]; then
  echo "Error: Menu bar template SVG not found at $MENU_BAR_TEMPLATE_SVG" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

base_icon_png="$tmp_dir/AppIcon-1024.png"
iconset_dir="$tmp_dir/AppIcon.iconset"
mkdir -p "$iconset_dir" "$MENU_BAR_IMAGESET_DIR"

echo "==> Rendering AppIcon.svg"
render_png "$APP_ICON_SVG" 1024 1024 "$base_icon_png"

declare -a icon_specs=(
  "icon_16x16.png:16"
  "icon_16x16@2x.png:32"
  "icon_32x32.png:32"
  "icon_32x32@2x.png:64"
  "icon_128x128.png:128"
  "icon_128x128@2x.png:256"
  "icon_256x256.png:256"
  "icon_256x256@2x.png:512"
  "icon_512x512.png:512"
  "icon_512x512@2x.png:1024"
)

for spec in "${icon_specs[@]}"; do
  file_name="${spec%%:*}"
  pixel_size="${spec##*:}"
  resize_png "$base_icon_png" "$pixel_size" "$pixel_size" "$iconset_dir/$file_name"
done

echo "==> Building AppIcon.icns"
iconutil -c icns -o "$APP_ICON_ICNS" "$iconset_dir"

echo "==> Rendering MenuBarTemplate PNGs"
render_png "$MENU_BAR_TEMPLATE_SVG" 16 16 "$MENU_BAR_TEMPLATE_PNG"
render_png "$MENU_BAR_TEMPLATE_SVG" 32 32 "$MENU_BAR_TEMPLATE_PNG_2X"
cp "$MENU_BAR_TEMPLATE_PNG" "$MENU_BAR_IMAGESET_DIR/MenuBarTemplate.png"
cp "$MENU_BAR_TEMPLATE_PNG_2X" "$MENU_BAR_IMAGESET_DIR/MenuBarTemplate@2x.png"

echo "==> Done"
echo "    App icon: $APP_ICON_ICNS"
echo "    Menu bar assets: $MENU_BAR_IMAGESET_DIR"
