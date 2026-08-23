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

printf 'PASS: manifest assets resolve within the package and SVG assets parse as XML\n'
