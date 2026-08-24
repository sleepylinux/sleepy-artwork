#!/usr/bin/env bash
set -euo pipefail

# This test fails if a packaged asset is missing, escapes the package source,
# or stops being well-formed XML. It catches bad installed-asset mappings.
package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
manifest="$package_root/branding/manifest.json"

if [[ ! -f "$manifest" ]]; then
  printf 'FAIL: manifest is missing: %s\n' "$manifest" >&2
  exit 1
fi

if ! jq -e 'type == "object" and (.assets | type == "object") and (.assets | length > 0)' "$manifest" >/dev/null; then
  printf 'FAIL: manifest must contain a non-empty assets object\n' >&2
  exit 1
fi

if ! jq -e '.assets["branding.primaryMark"] | type == "string" and length > 0' "$manifest" >/dev/null; then
  printf 'FAIL: manifest must define branding.primaryMark\n' >&2
  exit 1
fi

control_center_icons=(
  control-center
  network
  bluetooth
  volume
  microphone
  brightness
  night-light
  focus
  battery
  power-profile
  media-play
  media-pause
  media-next
  media-previous
  lock
  logout
  power
  preset
  keybinding
)

missing_icons=()
for icon_name in "${control_center_icons[@]}"; do
  logical_name="icons.$icon_name"
  expected_path="icons/$icon_name.svg"
  if ! jq -e --arg name "$logical_name" --arg path "$expected_path" \
    '.assets[$name] == $path' "$manifest" >/dev/null; then
    missing_icons+=("$logical_name -> $expected_path")
  fi
done

if (( ${#missing_icons[@]} > 0 )); then
  printf 'FAIL: missing Control Center icon entries:\n' >&2
  printf '  %s\n' "${missing_icons[@]}" >&2
  exit 1
fi

while IFS= read -r asset; do
  logical_name="${asset%%$'\t'*}"
  relative_path="${asset#*$'\t'}"

  if [[ "$relative_path" = /* || "$relative_path" == ~* || "$relative_path" == *".."* ]]; then
    printf 'FAIL: %s must use a package-relative path: %s\n' "$logical_name" "$relative_path" >&2
    exit 1
  fi

  asset_path="$package_root/$relative_path"
  if [[ ! -f "$asset_path" ]]; then
    printf 'FAIL: %s points to a missing file: %s\n' "$logical_name" "$relative_path" >&2
    exit 1
  fi

  resolved_path="$(cd "$(dirname "$asset_path")" && pwd -P)/$(basename "$asset_path")"
  case "$resolved_path" in
    "$package_root"/*) ;;
    *)
      printf 'FAIL: %s escapes the package source: %s\n' "$logical_name" "$relative_path" >&2
      exit 1
      ;;
  esac

  case "$asset_path" in
    *.svg)
      if ! xmllint --noout "$asset_path"; then
        printf 'FAIL: %s is not well-formed SVG XML: %s\n' "$logical_name" "$relative_path" >&2
        exit 1
      fi
      ;;
  esac
done < <(jq -r '.assets | to_entries[] | "\(.key)\t\(.value)"' "$manifest")

for icon_name in "${control_center_icons[@]}"; do
  icon_path="$package_root/icons/$icon_name.svg"

  if ! xmllint --xpath \
    'boolean(/*[local-name()="svg" and @viewBox="0 0 24 24" and @fill="none" and @stroke="currentColor" and @stroke-width="2" and @stroke-linecap="round" and @stroke-linejoin="round"])' \
    "$icon_path" 2>/dev/null | rg -qx 'true'; then
    printf 'FAIL: icons.%s must use the shared 24x24 currentColor rounded two-pixel stroke style\n' "$icon_name" >&2
    exit 1
  fi

  if LC_ALL=C rg -n '[^\x00-\x7F]' "$icon_path" >/dev/null; then
    printf 'FAIL: icons.%s must contain ASCII markup only, with no Unicode text\n' "$icon_name" >&2
    exit 1
  fi

  if xmllint --xpath \
    'boolean(//*[local-name()="script" or local-name()="text" or local-name()="image" or local-name()="foreignObject" or local-name()="use" or local-name()="style"])' \
    "$icon_path" 2>/dev/null | rg -qx 'true'; then
    printf 'FAIL: icons.%s contains forbidden executable, text, embedded, referenced, or style content\n' "$icon_name" >&2
    exit 1
  fi

  if sed 's#http://www.w3.org/2000/svg##g' "$icon_path" | \
    rg -n -i '(https?://|data:|javascript:|url\s*\(|href\s*=|<!DOCTYPE|<!ENTITY)' >/dev/null; then
    printf 'FAIL: icons.%s contains an external, embedded, or entity reference\n' "$icon_name" >&2
    exit 1
  fi
done

printf 'PASS: manifest assets resolve and Control Center SVGs are safe and coherent\n'
